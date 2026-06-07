//
//  SeedService.swift
//  My_Maxpster
//

import Foundation
import SwiftData
import Observation

/// Lightweight observable progress so the UI can show a loading overlay
/// with a determinate progress bar.
@Observable
@MainActor
final class SeedProgress {
    var isSeeding: Bool = false
    var message: String = ""
    var current: Int = 0
    var total: Int = 0

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(current) / Double(total))
    }
}

@MainActor
enum SeedService {
    /// Seeds the store from bundled `mapstr.geojson` / `mapstr.csv` if both exist and the store is empty.
    ///
    /// Parses files on a detached background task to keep the UI thread responsive,
    /// then commits inserts in small batches that yield to the runloop between each
    /// batch so the progress overlay stays animated. CloudKit continues mirroring
    /// in the background after this returns.
    static func seedIfNeeded(modelContext: ModelContext, progress: SeedProgress) async {
        let descriptor = FetchDescriptor<Place>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let geojsonText = bundleText(forResource: "mapstr", withExtension: "geojson")
        let csvText = bundleText(forResource: "mapstr", withExtension: "csv")
        guard geojsonText != nil || csvText != nil else { return }

        progress.isSeeding = true
        progress.message = "Reading sample places…"
        progress.current = 0
        progress.total = 0
        defer { progress.isSeeding = false }

        // 1. Parse off the main actor (CPU-bound JSON/CSV work).
        let parsed: [ParsedPlace] = await Task.detached(priority: .userInitiated) {
            var combined: [ParsedPlace] = []
            if let geojsonText { combined.append(contentsOf: ImportService.parseGeoJSON(geojsonText)) }
            if let csvText     { combined.append(contentsOf: ImportService.parseMapstrCSV(csvText)) }
            return combined
        }.value

        // 2. Insert with batch yields + progress reporting.
        progress.total = parsed.count
        progress.message = "Adding places…"
        let svc = ImportService(modelContext: modelContext)
        _ = try? await svc.insertBatchedAsync(
            parsed: parsed,
            strategy: .skipDuplicates,
            onBatchSaved: { done in
                progress.current = done
                progress.message = "Adding places… (\(done)/\(parsed.count))"
            }
        )

        // 3. Brief "Syncing to iCloud" state so the user sees something visible while
        //    CloudKit catches up with the initial batch upload.
        progress.message = "Syncing to iCloud…"
        progress.current = parsed.count
        try? await Task.sleep(for: .milliseconds(900))
    }

    private static func bundleText(forResource name: String, withExtension ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
