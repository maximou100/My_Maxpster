//
//  My_MaxpsterApp.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

@main
struct My_MaxpsterApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Place.self,
            Tag.self,
            PlaceCollection.self,
        ])
        // CloudKit sync. SwiftData picks the iCloud container declared in the
        // app's CloudKit entitlement; works on-device + simulator with an
        // iCloud-signed-in account.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
