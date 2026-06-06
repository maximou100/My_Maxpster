# My Maxpster

A personal place-management iOS app. Save restaurants, bars, cafés, museums and other locations you've been to or want to visit. View them on Apple Maps, filter and tag them, group them into collections, and see analytics in a dashboard.

iOS 17+ · SwiftUI · SwiftData · CloudKit sync · Apple Maps · MapKit search

## Features

- **4-tab navigation** — Map, Places, Collections, Dashboard
- **Map tab** — Apple Maps with category-colored pins, long-press to add a place, fly-to on selection, online search via Apple Maps suggesting nearby places to add
- **Places list** — searchable, sortable, swipeable
- **Filters** — categories, visit status, minimum rating, tags, country, collection (shared between Map and List)
- **Collections hub** — browse places by category, tag, country, or user-created collection
- **Dashboard** — totals, category breakdown, rating distribution, top tags, countries (Swift Charts)
- **iCloud sync** — `ModelConfiguration(cloudKitDatabase: .automatic)` mirrors your library across all your iOS devices
- **Import** — Mapstr (`.csv` + `.geojson`) and Google Takeout (`.csv` saved-list exports), with three merge strategies and tag-preserved colors
- **Export** — CSV and GeoJSON via the standard iOS share sheet
- **Yelp enrichment** — opt-in: paste a Yelp Fusion API key in Settings → on a place's detail screen, tap *Enrich from Yelp* to pull rating, price tier, phone, and Yelp page URL
- **Open in Apple or Google Maps** — from any place's detail screen

## Project structure

```
My_Maxpster/
├── Models/             SwiftData @Model classes + enums
├── Services/           ImportService, ExportService, YelpService, etc.
├── Utilities/          Color+Hex, CSVParser, CountryDetector, KeychainStore
├── ViewModels/         FilterState (@Observable)
├── Views/              Map/, Places/, Collections/, Dashboard/, Filters/, Settings/, Shared/
├── ContentView.swift   TabView root + seed progress overlay
├── My_MaxpsterApp.swift @main, ModelContainer setup
└── mapstr.{csv,geojson} First-launch seed (private — your personal data)
```

## Build & run

1. Open `My_Maxpster.xcodeproj` in Xcode 26+.
2. Set the deployment target's signing team in *Signing & Capabilities*.
3. Select an iOS 26+ simulator or device and run.

On first launch, the app seeds itself from the bundled `mapstr.*` files (if present) and begins mirroring to CloudKit.

## CloudKit setup

- **Container:** `iCloud.com.maxleclercq.My-Maxpster`
- **Entitlements:** iCloud + CloudKit, Background Modes → Remote notifications
- **Development → Production schema deploy** is required before App Store submission. Use CloudKit Console (icloud.developer.apple.com → your container → *Deploy Schema Changes*).

## Yelp API setup (optional)

The *Enrich from Yelp* button on a place detail uses Yelp Fusion. To enable:

1. Get a free API key at `developer.yelp.com`.
2. In the app: *Dashboard → ⚙ → External services → Yelp* → paste the key → *Verify & Save*.
3. The key is stored in iOS Keychain on the device only — it is never bundled in source.

## Privacy

- All place data is stored locally and synced through your own iCloud account.
- Location, camera and photo-library permissions are requested in-context, when you use the features that need them.
- The Yelp API key is stored in Keychain. The only network call to Yelp is `api.yelp.com/v3/businesses/search` for the place you choose to enrich.
- Map tiles come from Apple Maps; no Google Maps SDK is bundled. The "Open in Google Maps" action uses a deep link / web fallback only.

## Tech stack

| Concern | Library |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| Sync | CloudKit (via SwiftData's automatic mirror) |
| Maps + search | MapKit (`Map`, `MKLocalSearchCompleter`, `MKGeocodingRequest`, `MKReverseGeocodingRequest`) |
| Charts | Swift Charts |
| Photo picker | PhotosUI |
| Secrets | iOS Keychain |
| Networking | URLSession |

## License

Personal project. Not currently licensed for redistribution.
