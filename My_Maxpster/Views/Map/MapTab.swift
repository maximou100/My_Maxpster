//
//  MapTab.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard, hybrid, satellite
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid: return "Hybrid"
        case .satellite: return "Satellite"
        }
    }
    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .hybrid: return .hybrid
        case .satellite: return .imagery
        }
    }
}

struct MapTab: View {
    @Environment(FilterState.self) private var filter
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [Place]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlaceID: UUID?
    @State private var styleChoice: MapStyleChoice = .standard
    @State private var showingFilters = false
    @State private var showingAddSheet = false
    @State private var pendingPrefill: PlaceFormPrefill?
    @State private var didInitialFit = false
    @State private var searchService = LocationSearchService()
    @State private var previewItem: MapItemWrapper?
    @State private var isResolvingCompletion = false
    @State private var searchFocused: Bool = false
    @FocusState private var searchFieldFocused: Bool

    private var filteredPlaces: [Place] {
        filter.apply(to: places)
    }

    /// Local matches against the current search query (independent of other filters,
    /// so the user can find a place even if it's been filtered out of the map).
    private var localMatches: [Place] {
        let q = filter.searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return places.filter {
            $0.name.localizedCaseInsensitiveContains(q)
            || $0.address.localizedCaseInsensitiveContains(q)
            || $0.notes.localizedCaseInsensitiveContains(q)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var showingSearchResults: Bool {
        searchFieldFocused && !filter.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return places.first(where: { $0.id == id })
    }

    var body: some View {
        @Bindable var filter = filter

        NavigationStack {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $position, selection: $selectedPlaceID) {
                        ForEach(filteredPlaces) { place in
                            Annotation(place.name, coordinate: place.coordinate) {
                                PlacePin(category: place.category,
                                         isSelected: selectedPlaceID == place.id)
                            }
                            .tag(place.id)
                        }
                        UserAnnotation()
                    }
                    .mapStyle(styleChoice.mapStyle)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .onTapGesture(count: 1) {
                        // No-op tap; selection is handled via Annotation tags.
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onEnded { value in
                                if case .second(true, let drag?) = value {
                                    if let coord = proxy.convert(drag.location, from: .local) {
                                        Task { await beginAddPlace(at: coord) }
                                    }
                                }
                            }
                    )
                }

                searchOverlay
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationBarHidden(true)
            .onChange(of: filter.searchQuery) { _, newValue in
                searchService.query = newValue
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                searchService.region = context.region
            }
            .sheet(isPresented: Binding(
                get: { selectedPlace != nil },
                set: { presented in if !presented { selectedPlaceID = nil } }
            )) {
                if let place = selectedPlace {
                    NavigationStack {
                        PlaceDetail(place: place)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet()
            }
            .sheet(isPresented: $showingAddSheet) {
                PlaceForm(mode: .create(prefill: pendingPrefill))
            }
            .sheet(item: $previewItem) { wrapper in
                OnlinePlacePreview(mapItem: wrapper.item) { prefill in
                    pendingPrefill = prefill
                    showingAddSheet = true
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: selectedPlaceID) { _, newValue in
                if let id = newValue, let place = places.first(where: { $0.id == id }) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        position = .region(
                            MKCoordinateRegion(
                                center: place.coordinate,
                                latitudinalMeters: 800,
                                longitudinalMeters: 800
                            )
                        )
                    }
                }
            }
            .onAppear {
                if !didInitialFit, !places.isEmpty {
                    didInitialFit = true
                    fitToPlaces(places)
                }
            }
        }
    }

    private var searchOverlay: some View {
        @Bindable var filter = filter

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search places", text: $filter.searchQuery)
                        .focused($searchFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !filter.searchQuery.isEmpty {
                        Button {
                            filter.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if searchFieldFocused {
                        Button("Cancel") {
                            searchFieldFocused = false
                            filter.searchQuery = ""
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if !searchFieldFocused {
                    Button {
                        showingFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.appAccent)
                                .padding(8)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                            if filter.activeFilterCount > 0 {
                                Text("\(filter.activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }

                    Button {
                        recenterOnUserLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                            .padding(8)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                    }

                    Menu {
                        Picker("Map Style", selection: $styleChoice) {
                            ForEach(MapStyleChoice.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                            .padding(8)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if showingSearchResults {
                searchResultsList
                    .padding(.horizontal)
            }
        }
    }

    private var searchResultsList: some View {
        let local = localMatches
        let online = searchService.suggestions

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if !local.isEmpty {
                        sectionHeader("In your places", count: local.count)
                        ForEach(local) { place in
                            Button {
                                searchFieldFocused = false
                                selectedPlaceID = place.id
                            } label: {
                                localRow(place)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 56)
                        }
                    }

                    sectionHeader("Search Apple Maps", count: online.count, loading: searchService.isLoading)

                    if online.isEmpty && !searchService.isLoading && local.isEmpty {
                        Text("No matches.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(Array(online.enumerated()), id: \.offset) { _, completion in
                            Button {
                                Task { await resolveAndPreview(completion) }
                            } label: {
                                onlineRow(completion)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 56)
                        }
                        if isResolvingCompletion {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Looking up place…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 420)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func sectionHeader(_ title: String, count: Int, loading: Bool = false) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Spacer()
            if loading {
                ProgressView().controlSize(.mini)
            } else if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func localRow(_ place: Place) -> some View {
        HStack(spacing: 12) {
            Text(place.category.emoji)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(place.category.color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.subheadline.weight(.medium))
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func onlineRow(_ completion: MKLocalSearchCompletion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title).font(.subheadline.weight(.medium))
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func resolveAndPreview(_ completion: MKLocalSearchCompletion) async {
        isResolvingCompletion = true
        defer { isResolvingCompletion = false }
        if let item = await searchService.resolve(completion) {
            searchFieldFocused = false
            previewItem = MapItemWrapper(item: item)
        }
    }

    private func fitToPlaces(_ places: [Place]) {
        guard !places.isEmpty else { return }
        var minLat = places[0].latitude
        var maxLat = places[0].latitude
        var minLon = places[0].longitude
        var maxLon = places[0].longitude
        for p in places {
            minLat = min(minLat, p.latitude)
            maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude)
            maxLon = max(maxLon, p.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.02, (maxLon - minLon) * 1.4)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }

    /// Requests location permission if needed, then animates the camera to follow the user.
    /// Falls back to keeping the current camera if location services are unavailable.
    private func recenterOnUserLocation() {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Permission prompt is async; ask the camera to follow once granted.
            withAnimation(.easeInOut(duration: 0.4)) {
                position = .userLocation(fallback: position)
            }
        case .denied, .restricted:
            // Without permission, the system can't share a location — leave the camera where it is.
            // (Optional follow-up: surface a small alert here that nudges the user to Settings.)
            break
        case .authorizedAlways, .authorizedWhenInUse:
            withAnimation(.easeInOut(duration: 0.4)) {
                position = .userLocation(fallback: .automatic)
            }
        @unknown default:
            withAnimation(.easeInOut(duration: 0.4)) {
                position = .userLocation(fallback: .automatic)
            }
        }
    }

    private func beginAddPlace(at coordinate: CLLocationCoordinate2D) async {
        var prefill = PlaceFormPrefill(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let request = MKReverseGeocodingRequest(location: loc),
           let item = try? await request.mapItems.first {
            if let single = item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true) {
                prefill.address = single
            } else if let full = item.address?.fullAddress {
                prefill.address = full
            }
            prefill.country = item.addressRepresentations?.regionName ?? ""
        }
        pendingPrefill = prefill
        showingAddSheet = true
    }
}

/// Wraps `MKMapItem` so it can drive a SwiftUI `.sheet(item:)`.
struct MapItemWrapper: Identifiable {
    let id = UUID()
    let item: MKMapItem
}
