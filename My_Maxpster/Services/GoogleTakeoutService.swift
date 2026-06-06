//
//  GoogleTakeoutService.swift
//  My_Maxpster
//
//  Imports Google Maps "Saved" lists exported via Google Takeout.
//  Each Takeout CSV has columns: Title, Note, URL, Comment.
//  Coordinates are sometimes embedded in the URL as "@lat,lon" — when absent,
//  the title is geocoded via CLGeocoder.
//

import Foundation
import SwiftData
import CoreLocation
import MapKit

struct TakeoutFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let text: String
    /// The list name derived from the filename, e.g. "Want to go".
    let listName: String
    /// Rows parsed from the file before geocoding.
    let rows: [TakeoutRow]
}

struct TakeoutRow: Hashable {
    var title: String
    var note: String
    var urlString: String
    var comment: String
    /// Coordinates parsed from the URL when present.
    var coordinate: CLLocationCoordinate2D?
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

struct TakeoutImportSummary {
    var inserted: Int = 0
    var replaced: Int = 0
    var skippedDuplicates: Int = 0
    var skippedNoCoordinates: Int = 0
    var geocoded: Int = 0
    var tagsCreated: Int = 0
    var totalParsed: Int = 0
}

@MainActor
final class GoogleTakeoutService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Parsing

    static func parse(_ text: String, filename: String) -> TakeoutFile {
        let listName = filename
            .replacingOccurrences(of: ".csv", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        let url = URL(fileURLWithPath: filename)
        let rows = parseRows(text)
        return TakeoutFile(url: url, text: text, listName: listName, rows: rows)
    }

    static func parseRows(_ text: String) -> [TakeoutRow] {
        let grid = CSVParser.parse(text)
        guard grid.count > 1 else { return [] }
        let header = grid[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        func idx(_ candidates: [String]) -> Int? {
            for c in candidates {
                if let i = header.firstIndex(of: c.lowercased()) { return i }
            }
            return nil
        }
        let iTitle = idx(["title", "name"])
        let iNote = idx(["note"])
        let iURL = idx(["url"])
        let iComment = idx(["comment"])

        var out: [TakeoutRow] = []
        for row in grid.dropFirst() {
            func at(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }
            let title = at(iTitle)
            guard !title.isEmpty else { continue }
            let urlString = at(iURL)
            out.append(TakeoutRow(
                title: title,
                note: at(iNote),
                urlString: urlString,
                comment: at(iComment),
                coordinate: extractCoordinate(from: urlString)
            ))
        }
        return out
    }

    /// Extracts `@lat,lon` (and a few variants like `?q=lat,lon` or `ll=lat,lon`) from a Google Maps URL.
    static func extractCoordinate(from urlString: String) -> CLLocationCoordinate2D? {
        guard !urlString.isEmpty else { return nil }

        // 1) "@lat,lon" path style — the most common form.
        let atPattern = #"@(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)"#
        if let coord = firstMatch(urlString, pattern: atPattern) {
            return coord
        }

        // 2) "ll=lat,lon" query parameter (older style).
        if let coord = queryCoordinate(in: urlString, key: "ll") {
            return coord
        }

        // 3) "q=lat,lon" or "query=lat,lon" — only valid when value is a literal pair.
        if let coord = queryCoordinate(in: urlString, key: "q") {
            return coord
        }
        if let coord = queryCoordinate(in: urlString, key: "query") {
            return coord
        }

        // 4) "!3dLAT!4dLON" data-segment style (some place URLs).
        let dataPattern = #"!3d(-?\d{1,3}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)"#
        if let coord = firstMatch(urlString, pattern: dataPattern) {
            return coord
        }

        return nil
    }

    private static func firstMatch(_ source: String, pattern: String) -> CLLocationCoordinate2D? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(source.startIndex..., in: source)
        guard let match = regex.firstMatch(in: source, range: range),
              match.numberOfRanges >= 3,
              let r1 = Range(match.range(at: 1), in: source),
              let r2 = Range(match.range(at: 2), in: source),
              let lat = Double(source[r1]),
              let lon = Double(source[r2]),
              (-90...90).contains(lat),
              (-180...180).contains(lon)
        else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func queryCoordinate(in urlString: String, key: String) -> CLLocationCoordinate2D? {
        guard let comps = URLComponents(string: urlString),
              let items = comps.queryItems,
              let raw = items.first(where: { $0.name == key })?.value else { return nil }
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]),
              (-90...90).contains(lat),
              (-180...180).contains(lon)
        else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Import

    /// Imports the given Takeout files into SwiftData.
    /// - Parameters:
    ///   - files: parsed files (each list).
    ///   - strategy: how to handle duplicates already in the store.
    ///   - geocodeMissing: when true, rows without coordinates are geocoded via CLGeocoder (throttled).
    ///   - progress: optional progress callback ("geocoding 12/40").
    func importFiles(
        _ files: [TakeoutFile],
        strategy: MergeStrategy,
        geocodeMissing: Bool,
        progress: ((Int, Int) -> Void)? = nil
    ) async -> TakeoutImportSummary {
        var summary = TakeoutImportSummary()
        let totalRows = files.reduce(0) { $0 + $1.rows.count }
        summary.totalParsed = totalRows

        // Build / reuse the per-list tag.
        var existingTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        var existingPlaces = (try? modelContext.fetch(FetchDescriptor<Place>())) ?? []

        // Used to dedupe rows *within* the imported batch (e.g. same place in multiple lists).
        var batchSeen: [(name: String, coord: CLLocationCoordinate2D, place: Place)] = []

        var processed = 0
        for file in files {
            let listTag = ensureTag(named: file.listName,
                                    color: tagColor(for: file.listName),
                                    existingTags: &existingTags,
                                    summary: &summary)

            for row in file.rows {
                processed += 1
                progress?(processed, totalRows)

                // Resolve coordinates: URL first, geocoding fallback.
                var coord = row.coordinate
                if coord == nil, geocodeMissing {
                    coord = await geocode(title: row.title, hint: row.note)
                    if coord != nil { summary.geocoded += 1 }
                }
                guard let coordinate = coord else {
                    summary.skippedNoCoordinates += 1
                    continue
                }

                // Deduplicate against existing store.
                if let existing = findExisting(name: row.title, coord: coordinate, in: existingPlaces) {
                    switch strategy {
                    case .skipDuplicates:
                        // Still attach this list's tag so cross-list overlap surfaces.
                        attach(tag: listTag, to: existing)
                        summary.skippedDuplicates += 1
                        continue
                    case .replace:
                        apply(row: row, file: file, to: existing)
                        existing.tags = []
                        attach(tag: listTag, to: existing)
                        summary.replaced += 1
                        continue
                    case .appendAll:
                        break // fall through to insertion
                    }
                }

                // Deduplicate within this import batch (same place across multiple list files).
                if let dup = batchSeen.first(where: {
                    $0.name.caseInsensitiveCompare(row.title) == .orderedSame
                    && CLLocation(latitude: $0.coord.latitude, longitude: $0.coord.longitude)
                        .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) < 50
                }) {
                    attach(tag: listTag, to: dup.place)
                    summary.skippedDuplicates += 1
                    continue
                }

                // Insert new place.
                let place = newPlace(from: row, file: file, coordinate: coordinate)
                modelContext.insert(place)
                attach(tag: listTag, to: place)
                existingPlaces.append(place)
                batchSeen.append((row.title, coordinate, place))
                summary.inserted += 1
            }
        }

        return summary
    }

    // MARK: - Helpers

    private func newPlace(from row: TakeoutRow, file: TakeoutFile, coordinate: CLLocationCoordinate2D) -> Place {
        let note = [row.note, row.comment].filter { !$0.isEmpty }.joined(separator: "\n")
        let visit = GoogleTakeoutService.visitStatus(for: file.listName)
        return Place(
            name: row.title,
            address: "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: .other,
            rating: nil,
            notes: note,
            visitStatus: visit,
            country: "",
            website: row.urlString,
            phone: "",
            importedFrom: "google_takeout:\(file.listName)"
        )
    }

    private func apply(row: TakeoutRow, file: TakeoutFile, to place: Place) {
        place.name = row.title
        if !row.urlString.isEmpty { place.website = row.urlString }
        let note = [row.note, row.comment].filter { !$0.isEmpty }.joined(separator: "\n")
        if !note.isEmpty { place.notes = note }
        place.visitStatus = GoogleTakeoutService.visitStatus(for: file.listName)
        place.updatedAt = Date()
    }

    private func findExisting(name: String, coord: CLLocationCoordinate2D, in existing: [Place]) -> Place? {
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return existing.first { other in
            guard other.name.caseInsensitiveCompare(name) == .orderedSame else { return false }
            let here = CLLocation(latitude: other.latitude, longitude: other.longitude)
            return here.distance(from: target) < 50
        }
    }

    private func ensureTag(named rawName: String, color: String, existingTags: inout [Tag], summary: inout TakeoutImportSummary) -> Tag {
        let name = rawName.isEmpty ? "Google Maps" : rawName
        if let existing = existingTags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let tag = Tag(name: name, color: color)
        modelContext.insert(tag)
        existingTags.append(tag)
        summary.tagsCreated += 1
        return tag
    }

    private func attach(tag: Tag, to place: Place) {
        var current = place.tags ?? []
        if !current.contains(where: { $0.id == tag.id }) {
            current.append(tag)
            place.tags = current
        }
    }

    static func visitStatus(for listName: String) -> VisitStatus {
        let key = listName.lowercased()
        if key.contains("want") { return .wantToGo }
        if key.contains("starred") || key.contains("favorite") || key.contains("favourite") {
            return .visited
        }
        return .wantToGo
    }

    private func tagColor(for listName: String) -> String {
        let key = listName.lowercased()
        if key.contains("want")     { return "#3498DB" }
        if key.contains("favorite") || key.contains("favourite") { return "#F59E0B" }
        if key.contains("starred")  { return "#F1C40F" }
        return "#9B59B6"
    }

    // Geocoder is rate-limited (~50/min). Throttle with a small sleep between calls.
    private func geocode(title: String, hint: String) async -> CLLocationCoordinate2D? {
        let query = hint.isEmpty ? title : "\(title), \(hint)"
        guard let request = MKGeocodingRequest(addressString: query) else { return nil }
        let coordinate = try? await request.mapItems.first?.location.coordinate
        try? await Task.sleep(for: .milliseconds(120))
        return coordinate
    }
}
