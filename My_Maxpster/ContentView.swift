//
//  ContentView.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var filterState = FilterState()
    @State private var seedProgress = SeedProgress()

    var body: some View {
        ZStack {
            TabView {
                MapTab()
                    .tabItem { Label("Map", systemImage: "map") }

                PlacesTab()
                    .tabItem { Label("Places", systemImage: "list.bullet") }

                CollectionsTab()
                    .tabItem { Label("Collections", systemImage: "folder") }

                DashboardTab()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            }
            // Bottom bar on iPhone; sidebar on iPad and Mac. Single line, no per-idiom branching.
            .tabViewStyle(.sidebarAdaptable)
            .tint(.appAccent)
            .environment(filterState)

            if seedProgress.isSeeding {
                seedOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: seedProgress.isSeeding)
        .task {
            await SeedService.seedIfNeeded(modelContext: modelContext, progress: seedProgress)
        }
    }

    private var seedOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.appAccent)

            VStack(spacing: 6) {
                Text("Setting up your library")
                    .font(.headline)
                Text(seedProgress.message.isEmpty
                     ? "This only happens once."
                     : seedProgress.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Determinate progress when we know the total; indeterminate during parse/sync stages.
            if seedProgress.total > 0 {
                ProgressView(value: seedProgress.fraction)
                    .tint(.appAccent)
                    .frame(width: 220)
            } else {
                ProgressView()
                    .tint(.appAccent)
            }

            Text("iCloud sync continues in the background after this.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Place.self, Tag.self, PlaceCollection.self], inMemory: true)
}
