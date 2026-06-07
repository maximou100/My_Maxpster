//
//  SettingsSheet.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [Place]

    @State private var showingImporter = false
    @State private var importPreview: ImportPreviewData?
    @State private var importError: String?
    @State private var confirmReseed = false

    @State private var showingTakeoutImporter = false
    @State private var takeoutPreview: TakeoutPreviewData?
    @State private var takeoutProgress: TakeoutProgress?
    @State private var takeoutSummary: TakeoutImportSummary?
    @State private var showingTakeoutInfo = false

    @State private var showingYelpSetup = false
    @State private var yelpConfigured: Bool = YelpService.hasAPIKey

    @State private var showingMapstrInfo = false

    @State private var csvExportURL: URL?
    @State private var geojsonExportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import (CSV / GeoJSON)", systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(
                        isPresented: $showingImporter,
                        allowedContentTypes: [.commaSeparatedText, .json, UTType(filenameExtension: "geojson") ?? .json],
                        allowsMultipleSelection: false
                    ) { result in
                        handleFilePicked(result: result)
                    }
                    Button {
                        showingMapstrInfo = true
                    } label: {
                        Label("How to export from Mapstr", systemImage: "info.circle")
                    }

                    if let url = csvExportURL {
                        ShareLink(
                            item: url,
                            preview: SharePreview("My_Maxpster.csv")
                        ) {
                            Label("Export as CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(places.isEmpty)
                    }
                    if let url = geojsonExportURL {
                        ShareLink(
                            item: url,
                            preview: SharePreview("My_Maxpster.geojson")
                        ) {
                            Label("Export as GeoJSON", systemImage: "square.and.arrow.up")
                        }
                        .disabled(places.isEmpty)
                    }

                    Button(role: .destructive) {
                        confirmReseed = true
                    } label: {
                        Label("Reset & Re-import bundled data", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    Button {
                        showingTakeoutImporter = true
                    } label: {
                        Label("Import from Google Takeout", systemImage: "g.circle")
                    }
                    .fileImporter(
                        isPresented: $showingTakeoutImporter,
                        allowedContentTypes: [.commaSeparatedText],
                        allowsMultipleSelection: true
                    ) { result in
                        handleTakeoutFilesPicked(result: result)
                    }
                    Button {
                        showingTakeoutInfo = true
                    } label: {
                        Label("How to export from Google Maps", systemImage: "info.circle")
                    }
                } header: {
                    Text("Synchronization")
                } footer: {
                    Text("Google doesn't expose an API for Saved lists, so sync is done via Takeout. Each list's name becomes a tag on the imported places. Duplicates (same name within 50m) are merged.")
                }

                Section {
                    Button {
                        showingYelpSetup = true
                    } label: {
                        HStack {
                            Label("Yelp", systemImage: "fork.knife.circle")
                            Spacer()
                            Text(yelpConfigured ? "Connected" : "Not configured")
                                .font(.caption)
                                .foregroundStyle(yelpConfigured ? .green : .secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("External services")
                } footer: {
                    Text("When Yelp is connected, the place detail screen offers an “Enrich from Yelp” action to merge in ratings, prices and phone numbers. Yelp's coverage is strongest in the US/Canada.")
                }

                Section("About") {
                    LabeledContent("Places", value: "\(places.count)")
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .sheet(item: $importPreview) { preview in
                ImportPreviewSheet(preview: preview) { strategy in
                    runImport(preview: preview, strategy: strategy)
                }
            }
            .alert("Import failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .alert("Reset all data?", isPresented: $confirmReseed) {
                Button("Reset & Re-import", role: .destructive) { resetAndReseed() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes every place, tag and collection on this device, then re-imports the bundled mapstr files. Cannot be undone.")
            }
            .sheet(item: $takeoutPreview) { preview in
                TakeoutPreviewSheet(preview: preview) { strategy, geocode in
                    runTakeoutImport(preview: preview, strategy: strategy, geocodeMissing: geocode)
                }
            }
            .sheet(item: $takeoutProgress) { progress in
                TakeoutProgressSheet(progress: progress)
            }
            .sheet(isPresented: Binding(
                get: { takeoutSummary != nil },
                set: { if !$0 { takeoutSummary = nil } }
            )) {
                if let s = takeoutSummary {
                    TakeoutSummarySheet(summary: s) {
                        takeoutSummary = nil
                    }
                }
            }
            .sheet(isPresented: $showingTakeoutInfo) {
                TakeoutInstructionsSheet()
            }
            .sheet(isPresented: $showingMapstrInfo) {
                MapstrInstructionsSheet()
            }
            .sheet(isPresented: $showingYelpSetup, onDismiss: {
                yelpConfigured = YelpService.hasAPIKey
            }) {
                YelpSetupSheet()
            }
            .task(id: places.count) {
                regenerateExports()
            }
        }
    }

    /// Writes both export formats to a temp directory so ShareLink rows can hand them off.
    /// Re-runs whenever the place count changes (so a fresh import or delete is reflected).
    private func regenerateExports() {
        guard !places.isEmpty else {
            csvExportURL = nil
            geojsonExportURL = nil
            return
        }
        csvExportURL = try? ExportService.writeToTemp(places: places, format: .csv)
        geojsonExportURL = try? ExportService.writeToTemp(places: places, format: .geojson)
    }

    private func handleFilePicked(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                importError = "Could not decode file as UTF-8."
                return
            }
            let format: ImportPreviewData.Format =
                url.pathExtension.lowercased() == "csv" ? .csv : .geojson
            let parsed: [ParsedPlace] = format == .csv
                ? ImportService.parseMapstrCSV(text)
                : ImportService.parseGeoJSON(text)
            let uniqueTags = Set(parsed.flatMap { $0.tags.map(\.name) }).count
            importPreview = ImportPreviewData(
                text: text,
                format: format,
                placeCount: parsed.count,
                tagCount: uniqueTags,
                filename: url.lastPathComponent
            )
        } catch {
            importError = error.localizedDescription
        }
    }

    private func runImport(preview: ImportPreviewData, strategy: MergeStrategy) {
        let svc = ImportService(modelContext: modelContext)
        do {
            let summary: ImportSummary
            switch preview.format {
            case .csv: summary = try svc.importCSV(preview.text, strategy: strategy)
            case .geojson: summary = try svc.importGeoJSON(preview.text, strategy: strategy)
            }
            importPreview = nil
            importError = "Imported \(summary.inserted), replaced \(summary.replaced), skipped \(summary.skipped). New tags: \(summary.tagsCreated)."
        } catch {
            importError = error.localizedDescription
        }
    }

    private func resetAndReseed() {
        do {
            try modelContext.delete(model: Place.self)
            try modelContext.delete(model: Tag.self)
            try modelContext.delete(model: PlaceCollection.self)
            try modelContext.save()
        } catch {
            importError = "Reset failed: \(error.localizedDescription)"
            return
        }
        Task {
            await SeedService.seedIfNeeded(
                modelContext: modelContext,
                progress: SeedProgress() // local — sheet is dismissing anyway
            )
        }
        dismiss()
    }

    // MARK: - Google Takeout

    private func handleTakeoutFilesPicked(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }
            var parsed: [TakeoutFile] = []
            for url in urls {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    importError = "Could not decode \(url.lastPathComponent) as UTF-8."
                    return
                }
                parsed.append(GoogleTakeoutService.parse(text, filename: url.lastPathComponent))
            }
            takeoutPreview = TakeoutPreviewData(files: parsed)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func runTakeoutImport(preview: TakeoutPreviewData, strategy: MergeStrategy, geocodeMissing: Bool) {
        takeoutPreview = nil
        let progress = TakeoutProgress()
        takeoutProgress = progress
        let svc = GoogleTakeoutService(modelContext: modelContext)
        Task {
            let summary = await svc.importFiles(
                preview.files,
                strategy: strategy,
                geocodeMissing: geocodeMissing,
                progress: { done, total in
                    progress.done = done
                    progress.total = total
                }
            )
            takeoutProgress = nil
            takeoutSummary = summary
        }
    }
}

struct ImportPreviewData: Identifiable {
    enum Format { case csv, geojson }
    let id = UUID()
    let text: String
    let format: Format
    let placeCount: Int
    let tagCount: Int
    let filename: String
}

struct ImportPreviewSheet: View {
    let preview: ImportPreviewData
    let onConfirm: (MergeStrategy) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var strategy: MergeStrategy = .skipDuplicates

    var body: some View {
        NavigationStack {
            Form {
                Section("File") {
                    LabeledContent("Name", value: preview.filename)
                    LabeledContent("Format", value: preview.format == .csv ? "CSV" : "GeoJSON")
                }
                Section("Preview") {
                    LabeledContent("Places", value: "\(preview.placeCount)")
                    LabeledContent("Unique tags", value: "\(preview.tagCount)")
                }
                Section("Merge strategy") {
                    Picker("Strategy", selection: $strategy) {
                        ForEach(MergeStrategy.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text(strategy.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") { onConfirm(strategy) }
                        .bold()
                        .disabled(preview.placeCount == 0)
                }
            }
        }
    }
}

private extension Bundle {
    var appVersion: String {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        return "\(version) (\(build))"
    }
}

// MARK: - Google Takeout views

struct TakeoutPreviewData: Identifiable {
    let id = UUID()
    let files: [TakeoutFile]
}

@Observable
final class TakeoutProgress: Identifiable {
    let id = UUID()
    var done: Int = 0
    var total: Int = 0
}

struct TakeoutPreviewSheet: View {
    let preview: TakeoutPreviewData
    let onConfirm: (MergeStrategy, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var strategy: MergeStrategy = .skipDuplicates
    @State private var geocodeMissing: Bool = true

    private var totalRows: Int { preview.files.reduce(0) { $0 + $1.rows.count } }
    private var withCoords: Int {
        preview.files.reduce(0) { acc, f in acc + f.rows.filter { $0.coordinate != nil }.count }
    }
    private var withoutCoords: Int { totalRows - withCoords }

    var body: some View {
        NavigationStack {
            Form {
                Section("Files") {
                    ForEach(preview.files) { file in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(file.listName).font(.headline)
                                Text("Will become tag “\(file.listName)”")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(file.rows.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.appAccent)
                                .clipShape(Capsule())
                        }
                    }
                }

                Section("Coordinates") {
                    LabeledContent("Rows", value: "\(totalRows)")
                    LabeledContent("With coordinates", value: "\(withCoords)")
                    LabeledContent("Need geocoding", value: "\(withoutCoords)")
                    Toggle("Look up missing coordinates", isOn: $geocodeMissing)
                        .disabled(withoutCoords == 0)
                    if geocodeMissing, withoutCoords > 0 {
                        Text("Geocoding \(withoutCoords) places may take ~\(estimatedSeconds)s and uses Apple's geocoder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Duplicates") {
                    Picker("Strategy", selection: $strategy) {
                        ForEach(MergeStrategy.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text(strategy.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Takeout Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") { onConfirm(strategy, geocodeMissing) }
                        .bold()
                        .disabled(totalRows == 0)
                }
            }
        }
    }

    private var estimatedSeconds: Int {
        max(1, Int((Double(withoutCoords) * 0.25).rounded()))
    }
}

struct TakeoutProgressSheet: View {
    @Bindable var progress: TakeoutProgress

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0)
                .progressViewStyle(.linear)
            Text("Importing \(progress.done) / \(progress.total)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Geocoding missing coordinates can take a while…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .presentationDetents([.height(220)])
        .interactiveDismissDisabled(true)
    }
}

struct TakeoutSummarySheet: View {
    let summary: TakeoutImportSummary
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Result") {
                    LabeledContent("Inserted", value: "\(summary.inserted)")
                    LabeledContent("Replaced", value: "\(summary.replaced)")
                    LabeledContent("Skipped (duplicates)", value: "\(summary.skippedDuplicates)")
                    LabeledContent("Skipped (no coordinates)", value: "\(summary.skippedNoCoordinates)")
                    LabeledContent("Geocoded", value: "\(summary.geocoded)")
                    LabeledContent("New tags", value: "\(summary.tagsCreated)")
                }
                if summary.skippedNoCoordinates > 0 {
                    Section {
                        Text("\(summary.skippedNoCoordinates) entries had no usable URL coordinates and couldn't be geocoded. You can add them manually from the map.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone).bold()
                }
            }
        }
    }
}

struct TakeoutInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Google doesn't offer a public API for personal Saved lists, so we sync via Google Takeout (manual export).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Group {
                        step(1, "Open takeout.google.com on a computer (signed into your Google account).")
                        step(2, "Click “Deselect all”, then re-enable only “Saved” (or “Maps (your places)”).")
                        step(3, "Scroll to the bottom and click “Next step”.")
                        step(4, "Choose “Send download link via email” → “Create export”.")
                        step(5, "Open the email, download and unzip the archive on your device.")
                        step(6, "Come back here, tap “Import from Google Takeout”, and select all the .csv files inside the unzipped “Saved” folder.")
                    }

                    Button {
                        if let url = URL(string: "https://takeout.google.com/") {
                            openURL(url)
                        }
                    } label: {
                        Label("Open takeout.google.com", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)

                    Text("Each list's filename (e.g. “Want to go.csv”) becomes a tag on the imported places. Places already in your library are matched on name within 50 meters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .padding()
            }
            .navigationTitle("Google Takeout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.appAccent)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}

struct MapstrInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Mapstr lets you export everything you've saved as a backup. We accept the two files it produces — `mapstr.csv` and `mapstr.geojson` — directly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    sectionHeader("Export from Mapstr")
                    Group {
                        step(1, "Open the Mapstr app on your iPhone and sign in to your account.")
                        step(2, "Tap your profile icon (top-right on the map screen).")
                        step(3, "Open “Settings” → “My Data” (or “Account → Export my data”, depending on Mapstr's current version).")
                        step(4, "Tap “Export” or “Send my backup”. Mapstr emails you a download link, or hands you a `.zip` archive via the share sheet.")
                        step(5, "Open the email / zip. Inside you'll find `mapstr.csv` (places + tags + notes) and `mapstr.geojson` (places + coordinates).")
                        step(6, "Save both files to the Files app (iCloud Drive, On My iPhone — either works).")
                    }

                    sectionHeader("Import into My_Maxpster")
                    Group {
                        step(1, "Back in this Settings screen, tap “Import (CSV / GeoJSON)”.")
                        step(2, "Pick the `mapstr.geojson` first — it has the coordinates, so this is the one that creates your places.")
                        step(3, "Choose a merge strategy in the preview sheet:\n• Skip duplicates — safest if you already have data\n• Replace — overwrites matching places\n• Append all — inserts everything, even duplicates")
                        step(4, "Tap Import. After it finishes, repeat with `mapstr.csv` if you want the tag colors and any extra notes Mapstr stored only in the CSV.")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("What gets imported", systemImage: "checkmark.seal")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Name, address, coordinates, category (mapped from Mapstr's icons), tags with their original colors, notes, and visit status (places tagged “Already tried” become “Visited”; everything else defaults to “Want to Go”). Country is auto-detected from the address.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Heads-up", systemImage: "info.circle")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Mapstr periodically renames their export option in app updates. If you can't find it, search the Mapstr Help Center for “export my data” or contact their support — the file format we accept hasn't changed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                .padding()
            }
            .navigationTitle("Import from Mapstr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(Color.appAccent)
            .padding(.top, 6)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.appAccent)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
