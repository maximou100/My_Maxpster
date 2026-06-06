//
//  SeedService.swift
//  My_Maxpster
//

import Foundation
import SwiftData
import Observation

/// Lightweight observable progress so the UI can show a loading overlay.
@Observable
@MainActor
final class SeedProgress {
    var isSeeding: Bool = false
    var message: String = ""
}

@MainActor
enum SeedService {
    /// Seeds the store from bundled `mapstr.geojson` / `mapstr.csv` if both exist and the store is empty.
    ///
    /// Parses files on a background priority Task to keep the UI thread responsive,
    /// then commits inserts to the model context. CloudKit will continue mirroring
    /// in the background after this returns; the UI is unblocked as soon as the
    /// inserts complete.
    static func seedIfNeeded(modelContext: ModelContext, progress: SeedProgress) async {
        let descriptor = FetchDescriptor<Place>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let geojsonText = bundleText(forResource: "mapstr", withExtension: "geojson")
        let csvText = bundleText(forResource: "mapstr", withExtension: "csv")
        guard geojsonText != nil || csvText != nil else { return }

        progress.isSeeding = true
        progress.message = "Loading sample places…"
        defer { progress.isSeeding = false }

        // Parse off the main actor (CPU-bound JSON/CSV work). Parsers are nonisolated statics.
        let parsed: [ParsedPlace] = await Task.detached(priority: .userInitiated) {
            var combined: [ParsedPlace] = []
            if let geojsonText { combined.append(contentsOf: ImportService.parseGeoJSON(geojsonText)) }
            if let csvText     { combined.append(contentsOf: ImportService.parseMapstrCSV(csvText)) }
            return combined
        }.value

        progress.message = "Adding \(parsed.count) places…"
        let svc = ImportService(modelContext: modelContext)
        _ = try? svc.insertBatched(parsed: parsed, strategy: .skipDuplicates)
    }

    private static func bundleText(forResource name: String, withExtension ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
