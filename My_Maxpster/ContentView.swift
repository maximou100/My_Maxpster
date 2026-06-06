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
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(seedProgress.message.isEmpty ? "Setting up your library…" : seedProgress.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("This only happens once. iCloud sync continues in the background.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
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
