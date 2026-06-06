//
//  ExportService.swift
//  My_Maxpster
//

import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case geojson = "GeoJSON"
    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .geojson: return "geojson"
        }
    }
}

enum ExportService {
    static func csv(for places: [Place]) -> String {
        let header = [
            "Name", "Address", "Latitude", "Longitude", "Category",
            "Lists", "Note", "Visited", "Rating", "Website", "Phone",
            "Country", "Collections", "CreatedAt", "UpdatedAt"
        ]
        var lines: [String] = [header.map(CSVParser.escape).joined(separator: ",")]
        let iso = ISO8601DateFormatter()
        for p in places {
            let visited: String = {
                switch p.visitStatus {
                case .visited: return "oui"
                case .wantToGo: return "maybe"
                case .none: return "non"
                }
            }()
            let tagsString = (p.tags ?? []).map(\.name).joined(separator: "#")
            let collectionsString = (p.collections ?? []).map(\.name).joined(separator: ",")
            let cells = [
                p.name,
                p.address,
                String(p.latitude),
                String(p.longitude),
                p.categoryRaw,
                tagsString,
                p.notes,
                visited,
                p.rating.map(String.init) ?? "",
                p.website,
                p.phone,
                p.country,
                collectionsString,
                iso.string(from: p.createdAt),
                iso.string(from: p.updatedAt)
            ]
            lines.append(cells.map(CSVParser.escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func geoJSON(for places: [Place]) throws -> Data {
        let iso = ISO8601DateFormatter()
        let features: [[String: Any]] = places.map { p in
            let visited: String = {
                switch p.visitStatus {
                case .visited: return "visited"
                case .wantToGo: return "want_to_go"
                case .none: return "none"
                }
            }()
            var properties: [String: Any] = [
                "name": p.name,
                "address": p.address,
                "category": p.categoryRaw,
                "note": p.notes,
                "visited": visited,
                "tags": (p.tags ?? []).map(\.name),
                "collections": (p.collections ?? []).map(\.name),
                "website": p.website,
                "phone": p.phone,
                "country": p.country,
                "createdAt": iso.string(from: p.createdAt),
                "updatedAt": iso.string(from: p.updatedAt)
            ]
            if let rating = p.rating { properties["rating"] = rating }
            return [
                "type": "Feature",
                "geometry": [
                    "type": "Point",
                    "coordinates": [p.longitude, p.latitude]
                ],
                "properties": properties
            ]
        }
        let root: [String: Any] = [
            "type": "FeatureCollection",
            "features": features
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    /// Writes the export to a temporary file and returns its URL (for share sheets).
    static func writeToTemp(places: [Place], format: ExportFormat) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("my_maxpster_export")
            .appendingPathExtension(format.fileExtension)
        switch format {
        case .csv:
            try csv(for: places).data(using: .utf8)?.write(to: url)
        case .geojson:
            try geoJSON(for: places).write(to: url)
        }
        return url
    }
}
