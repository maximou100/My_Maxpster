//
//  PlaceForm.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import PhotosUI

struct PlaceFormPrefill {
    var name: String = ""
    var latitude: Double
    var longitude: Double
    var address: String = ""
    var country: String = ""
    var category: PlaceCategory? = nil
    var website: String = ""
    var phone: String = ""
}

enum PlaceFormMode {
    case create(prefill: PlaceFormPrefill?)
    case edit(place: Place)
}

struct PlaceForm: View {
    let mode: PlaceFormMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var country: String = ""
    @State private var category: PlaceCategory = .restaurant
    @State private var rating: Int? = nil
    @State private var visitStatus: VisitStatus = .none
    @State private var website: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""
    @State private var photos: [String] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isGeocoding = false
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingPlace: Place? {
        if case let .edit(place) = mode { return place }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(PlaceCategory.allCases) { c in
                            Text("\(c.emoji)  \(c.label)").tag(c)
                        }
                    }
                }

                Section("Location") {
                    TextField("Address", text: $address)
                    HStack {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    TextField("Country", text: $country)
                    Button {
                        Task { await geocodeAddress() }
                    } label: {
                        Label(isGeocoding ? "Looking up…" : "Look up coordinates from address",
                              systemImage: "location.magnifyingglass")
                    }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isGeocoding)
                }

                Section("Visit") {
                    Picker("Status", selection: $visitStatus) {
                        Text("None").tag(VisitStatus.none)
                        Text("Visited").tag(VisitStatus.visited)
                        Text("Want to Go").tag(VisitStatus.wantToGo)
                    }
                    HStack {
                        Text("Rating")
                        Spacer()
                        InteractiveRatingStars(rating: $rating, size: 24)
                    }
                }

                Section("Contact") {
                    TextField("Website", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Photos") {
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: 6,
                        matching: .images
                    ) {
                        Label("Add photos", systemImage: "photo.on.rectangle.angled")
                    }
                    if !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos, id: \.self) { id in
                                    if let uiImage = PhotoStore.load(id) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    photos.removeAll { $0 == id }
                                                    PhotoStore.delete(id)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.white, .black.opacity(0.6))
                                                }
                                                .padding(2)
                                            }
                                    }
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Place" : "New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!isValid)
                        .bold()
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: photoPickerItems) { _, items in
                Task { await loadPickedPhotos(items) }
            }
        }
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let filename = PhotoStore.save(image) {
                photos.append(filename)
            }
        }
        photoPickerItems = []
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && Double(latitude) != nil
        && Double(longitude) != nil
    }

    private func prefill() {
        switch mode {
        case let .create(prefill):
            if let p = prefill {
                if !p.name.isEmpty { name = p.name }
                latitude = String(p.latitude)
                longitude = String(p.longitude)
                address = p.address
                country = p.country
                if let c = p.category { category = c }
                if !p.website.isEmpty { website = p.website }
                if !p.phone.isEmpty { phone = p.phone }
            }
        case let .edit(place):
            name = place.name
            address = place.address
            latitude = String(place.latitude)
            longitude = String(place.longitude)
            country = place.country
            category = place.category
            rating = place.rating
            visitStatus = place.visitStatus
            website = place.website
            phone = place.phone
            notes = place.notes
            photos = place.photos
        }
    }

    private func save() {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            errorMessage = "Latitude and longitude must be valid numbers."
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name is required."
            return
        }

        if let place = existingPlace {
            let removed = Set(place.photos).subtracting(photos)
            for id in removed { PhotoStore.delete(id) }
            place.name = trimmedName
            place.address = address
            place.latitude = lat
            place.longitude = lon
            place.country = country
            place.category = category
            place.rating = rating
            place.visitStatus = visitStatus
            place.website = website
            place.phone = phone
            place.notes = notes
            place.photos = photos
            place.updatedAt = Date()
        } else {
            let place = Place(
                name: trimmedName,
                address: address,
                latitude: lat,
                longitude: lon,
                category: category,
                rating: rating,
                notes: notes,
                visitStatus: visitStatus,
                photos: photos,
                country: country,
                website: website,
                phone: phone
            )
            modelContext.insert(place)
        }
        dismiss()
    }

    private func geocodeAddress() async {
        isGeocoding = true
        defer { isGeocoding = false }
        guard let request = MKGeocodingRequest(addressString: address) else {
            errorMessage = "Couldn't build a geocoding request for that address."
            return
        }
        do {
            let mapItems = try await request.mapItems
            guard let item = mapItems.first else {
                errorMessage = "Couldn't find that address."
                return
            }
            let coord = item.location.coordinate
            latitude = String(coord.latitude)
            longitude = String(coord.longitude)
            if country.isEmpty, let region = item.addressRepresentations?.regionName {
                country = region
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
