//
//  ImportService.swift
//  My_Maxpster
//

import Foundation
import SwiftData
import CoreLocation

enum MergeStrategy: String, CaseIterable, Identifiable {
    case skipDuplicates = "Skip duplicates"
    case replace = "Replace existing"
    case appendAll = "Append all"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .skipDuplicates: return "Match on name + location (50m). Skip if already exists."
        case .replace: return "Match on name + location (50m). Overwrite the existing entry."
        case .appendAll: return "Insert everything. Allow duplicates."
        }
    }
}

struct ImportSummary {
    var inserted: Int = 0
    var replaced: Int = 0
    var skipped: Int = 0
    var tagsCreated: Int = 0
    var totalParsed: Int = 0
}

struct ParsedTag: Hashable {
    var name: String
    var color: String?
}

/// Place data parsed from an import source, not yet inserted.
struct ParsedPlace {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var category: PlaceCategory
    var rating: Int?
    var notes: String
    var visitStatus: VisitStatus
    var country: String
    var website: String
    var phone: String
    var tags: [ParsedTag]
}

@MainActor
final class ImportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }


    // MARK: - Public

    func importMapstr(geojson: String?, csv: String?, strategy: MergeStrategy) throws -> ImportSummary {
        var parsed: [ParsedPlace] = []
        if let geojson, !geojson.isEmpty {
            parsed.append(contentsOf: Self.parseGeoJSON(geojson))
        }
        if let csv, !csv.isEmpty {
            parsed.append(contentsOf: Self.parseMapstrCSV(csv))
        }
        return try insert(parsed: parsed, strategy: strategy)
    }

    func importCSV(_ text: String, strategy: MergeStrategy) throws -> ImportSummary {
        try insert(parsed: Self.parseMapstrCSV(text), strategy: strategy)
    }

    func importGeoJSON(_ text: String, strategy: MergeStrategy) throws -> ImportSummary {
        try insert(parsed: Self.parseGeoJSON(text), strategy: strategy)
    }

    /// Like `insert(parsed:strategy:)` but commits every 50 records so CloudKit
    /// sees reasonable transaction sizes during a bulk seed import.
    @discardableResult
    func insertBatched(parsed: [ParsedPlace], strategy: MergeStrategy, batchSize: Int = 50) throws -> ImportSummary {
        var summary = ImportSummary()
        summary.totalParsed = parsed.count

        let existing = try modelContext.fetch(FetchDescriptor<Place>())
        var existingTags = try modelContext.fetch(FetchDescriptor<Tag>())
        var sinceLastSave = 0

        for p in parsed {
            let duplicate = findDuplicate(for: p, in: existing)
            switch strategy {
            case .skipDuplicates:
                if duplicate != nil { summary.skipped += 1; continue }
                let place = newPlace(from: p)
                attachTags(p.tags, to: place, existingTags: &existingTags, summary: &summary)
                modelContext.insert(place)
                summary.inserted += 1
            case .replace:
                if let dup = duplicate {
                    apply(p, to: dup)
                    dup.tags = []
                    attachTags(p.tags, to: dup, existingTags: &existingTags, summary: &summary)
                    summary.replaced += 1
                } else {
                    let place = newPlace(from: p)
                    attachTags(p.tags, to: place, existingTags: &existingTags, summary: &summary)
                    modelContext.insert(place)
                    summary.inserted += 1
                }
            case .appendAll:
                let place = newPlace(from: p)
                attachTags(p.tags, to: place, existingTags: &existingTags, summary: &summary)
                modelContext.insert(place)
                summary.inserted += 1
            }

            sinceLastSave += 1
            if sinceLastSave >= batchSize {
                try? modelContext.save()
                sinceLastSave = 0
            }
        }
        try? modelContext.save()
        return summary
    }

    // MARK: - Parsing

    nonisolated static func parseMapstrCSV(_ text: String) -> [ParsedPlace] {
        let rows = CSVParser.parse(text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        func idx(_ candidates: [String]) -> Int? {
            for c in candidates {
                if let i = header.firstIndex(of: c.lowercased()) { return i }
            }
            return nil
        }

        let iName = idx(["name", "nom"])
        let iAddr = idx(["address", "adresse"])
        let iLat = idx(["latitude", "lat"])
        let iLon = idx(["longitude", "lon", "lng"])
        let iCat = idx(["category", "categorie", "icon"])
        let iLists = idx(["lists", "tags", "listes"])
        let iNote = idx(["note", "notes", "usercomment", "comment"])
        let iVisited = idx(["visited", "visite", "visité"])
        let iRating = idx(["rating", "note_etoile"])
        let iWeb = idx(["website", "site"])
        let iPhone = idx(["phone", "telephone", "téléphone"])

        var out: [ParsedPlace] = []
        for row in rows.dropFirst() {
            func at(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }
            // Mapstr's CSV has no lat/lng — skip those rows when coordinates are missing,
            // since we can't place them on the map.
            let lat = Double(at(iLat).replacingOccurrences(of: ",", with: ".")) ?? .nan
            let lon = Double(at(iLon).replacingOccurrences(of: ",", with: ".")) ?? .nan
            guard !lat.isNaN, !lon.isNaN, !at(iName).isEmpty else { continue }

            let tagsRaw = at(iLists)
            let parsedTags: [ParsedTag] = tagsRaw
                .split(whereSeparator: { $0 == "#" || $0 == ";" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { ParsedTag(name: $0, color: nil) }

            let visitedRaw = at(iVisited).lowercased()
            let visit: VisitStatus = {
                if iVisited != nil {
                    switch visitedRaw {
                    case "oui", "yes", "true", "1", "visited": return .visited
                    case "maybe", "peut-etre", "peut-être", "want", "want_to_go", "wanttogo": return .wantToGo
                    case "non", "no", "false", "0": return .wantToGo
                    default: break
                    }
                }
                return Self.deriveVisitStatus(tags: parsedTags, rating: Int(at(iRating)))
            }()

            let cat = PlaceCategory.fromMapstrIcon(at(iCat))
            let rating = Int(at(iRating))
            let address = at(iAddr)

            out.append(ParsedPlace(
                name: at(iName),
                address: address,
                latitude: lat,
                longitude: lon,
                category: cat,
                rating: rating.flatMap { (1...5).contains($0) ? $0 : nil },
                notes: at(iNote),
                visitStatus: visit,
                country: CountryDetector.country(in: address),
                website: at(iWeb),
                phone: at(iPhone),
                tags: parsedTags
            ))
        }
        return out
    }

    /// Mapstr doesn't export an explicit visit status. Their convention is:
    /// the tag "Already tried" marks visited places. A non-nil rating is also a
    /// strong signal that the user has been there. Everything else is "want to go".
    nonisolated static func deriveVisitStatus(tags: [ParsedTag], rating: Int?) -> VisitStatus {
        let names = tags.map { $0.name.lowercased() }
        if names.contains("already tried") || names.contains("déjà essayé") || names.contains("deja essaye") {
            return .visited
        }
        if let r = rating, r > 0 { return .visited }
        return .wantToGo
    }

    nonisolated static func parseGeoJSON(_ text: String) -> [ParsedPlace] {
        guard let data = text.data(using: .utf8) else { return [] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else { return [] }

        var out: [ParsedPlace] = []
        for f in features {
            guard let geometry = f["geometry"] as? [String: Any],
                  (geometry["type"] as? String) == "Point",
                  let coords = geometry["coordinates"] as? [Double],
                  coords.count >= 2 else { continue }
            let lon = coords[0]
            let lat = coords[1]
            let props = (f["properties"] as? [String: Any]) ?? [:]
            let name = (props["name"] as? String) ?? ""
            guard !name.isEmpty else { continue }

            // Mapstr exports tags as objects: [{"name":"Pizza","color":"#334eff"}].
            // Also accept the simpler [String] / "a#b" forms for hand-written inputs.
            let parsedTags: [ParsedTag] = {
                if let arr = props["tags"] as? [[String: Any]] {
                    return arr.compactMap { dict in
                        guard let n = dict["name"] as? String, !n.isEmpty else { return nil }
                        return ParsedTag(name: n, color: dict["color"] as? String)
                    }
                }
                if let arr = props["tags"] as? [String] {
                    return arr.map { ParsedTag(name: $0, color: nil) }
                }
                if let s = props["tags"] as? String {
                    return s.split(whereSeparator: { $0 == "#" || $0 == "," || $0 == ";" })
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .map { ParsedTag(name: $0, color: nil) }
                }
                return []
            }()

            // Mapstr puts the category in `icon`; fall back to `category` for other sources.
            let iconRaw = (props["icon"] as? String) ?? (props["category"] as? String) ?? ""
            let cat = PlaceCategory.fromMapstrIcon(iconRaw)
            let rating = props["rating"] as? Int

            // Mapstr stores user notes in `userComment`.
            let notes = (props["userComment"] as? String)
                ?? (props["note"] as? String)
                ?? (props["notes"] as? String)
                ?? ""

            // Mapstr doesn't export an explicit `visited` field — derive it from tags + rating.
            let visit: VisitStatus = {
                if let b = props["visited"] as? Bool { return b ? .visited : .wantToGo }
                if let s = props["visited"] as? String {
                    switch s.lowercased() {
                    case "oui", "yes", "true", "1", "visited": return .visited
                    case "maybe", "want", "want_to_go": return .wantToGo
                    case "non", "no", "false", "0": return .wantToGo
                    default: break
                    }
                }
                return Self.deriveVisitStatus(tags: parsedTags, rating: rating)
            }()

            let address = (props["address"] as? String) ?? ""
            let countryFromProps = (props["country"] as? String) ?? ""
            let country = countryFromProps.isEmpty ? CountryDetector.country(in: address) : countryFromProps

            out.append(ParsedPlace(
                name: name,
                address: address,
                latitude: lat,
                longitude: lon,
                category: cat,
                rating: rating.flatMap { (1...5).contains($0) ? $0 : nil },
                notes: notes,
                visitStatus: visit,
                country: country,
                website: (props["website"] as? String) ?? "",
                phone: (props["phone"] as? String) ?? "",
                tags: parsedTags
            ))
        }
        return out
    }

    // MARK: - Insertion

    private func insert(parsed: [ParsedPlace], strategy: MergeStrategy) throws -> ImportSummary {
        var summary = ImportSummary()
        summary.totalParsed = parsed.count

        let existing = try modelContext.fetch(FetchDescriptor<Place>())
        var existingTags = try modelContext.fetch(FetchDescriptor<Tag>())

        for p in parsed {
            let duplicate = findDuplicate(for: p, in: existing)

            switch strategy {
            case .skipDuplicates:
                if duplicate != nil {
                    summary.skipped += 1
                    continue
                }
                let place = newPlace(from: p)
                attachTags(p.tags, to: place, existingTags: &existingTags, summary: &summary)
                modelContext.insert(place)
                summary.inserted += 1

            case .replace:
                if let dup = duplicate {
                    apply(p, to: dup)
                    dup.tags = []
                    attachTags(p.tags, to: dup, existingTags: &existingTags, summary: &summary)
                    summary.replaced += 1
                } else {
                    let place = newPlace(from: p)
                    attachTags(p.tags, to: place, existingTags: &existingTags, summary: &summary)
                    modelContext.insert(place)
                    summary.inserted += 1
                }

            case .appendAll:
                let place = newPlace(from: p)
                attachTags(p.tags, to: place, existingTags: &existingTags, summary: &summary)
                modelContext.insert(place)
                summary.inserted += 1
            }
        }
        return summary
    }

    private func findDuplicate(for p: ParsedPlace, in existing: [Place]) -> Place? {
        let target = CLLocation(latitude: p.latitude, longitude: p.longitude)
        return existing.first { other in
            guard other.name.caseInsensitiveCompare(p.name) == .orderedSame else { return false }
            let here = CLLocation(latitude: other.latitude, longitude: other.longitude)
            return here.distance(from: target) < 50
        }
    }

    private func newPlace(from p: ParsedPlace) -> Place {
        Place(
            name: p.name,
            address: p.address,
            latitude: p.latitude,
            longitude: p.longitude,
            category: p.category,
            rating: p.rating,
            notes: p.notes,
            visitStatus: p.visitStatus,
            country: p.country,
            website: p.website,
            phone: p.phone,
            importedFrom: "mapstr"
        )
    }

    private func apply(_ p: ParsedPlace, to place: Place) {
        place.name = p.name
        place.address = p.address
        place.latitude = p.latitude
        place.longitude = p.longitude
        place.category = p.category
        place.rating = p.rating
        place.notes = p.notes
        place.visitStatus = p.visitStatus
        if !p.country.isEmpty { place.country = p.country }
        place.website = p.website
        place.phone = p.phone
        place.updatedAt = Date()
    }

    private func attachTags(_ tags: [ParsedTag], to place: Place, existingTags: inout [Tag], summary: inout ImportSummary) {
        for parsed in tags {
            let trimmed = parsed.name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let existing = existingTags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                // Backfill a missing color the first time we see one in the source data.
                if let color = parsed.color, !color.isEmpty,
                   existing.color.isEmpty || existing.color == "#F59E0B" {
                    existing.color = color
                }
                var current = place.tags ?? []
                if !current.contains(where: { $0.id == existing.id }) {
                    current.append(existing)
                    place.tags = current
                }
            } else {
                let tag = Tag(name: trimmed, color: parsed.color ?? "#F59E0B")
                modelContext.insert(tag)
                existingTags.append(tag)
                var current = place.tags ?? []
                current.append(tag)
                place.tags = current
                summary.tagsCreated += 1
            }
        }
    }
}
