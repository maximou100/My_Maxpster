//
//  PlaceDetail.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

struct PlaceDetail: View {
    @Bindable var place: Place
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var editing = false
    @State private var confirmDelete = false
    @State private var showCollectionsPicker = false
    @State private var showTagsPicker = false
    @State private var showYelpEnrichment = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                metaSection
                Divider()
                visitStatusSection
                Divider()
                ratingSection
                if !place.notes.isEmpty {
                    Divider()
                    notesSection
                }
                Divider()
                tagsSection
                Divider()
                collectionsSection
                if !place.photos.isEmpty {
                    Divider()
                    photosSection
                }
                Divider()
                deleteButton
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            PlaceForm(mode: .edit(place: place))
        }
        .sheet(isPresented: $showTagsPicker) {
            TagsPicker(place: place)
        }
        .sheet(isPresented: $showYelpEnrichment) {
            YelpEnrichmentSheet(place: place)
        }
        .sheet(isPresented: $showCollectionsPicker) {
            CollectionsPicker(place: place)
        }
        .alert("Delete this place?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(place)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(place.category.emoji)
                .font(.system(size: 44))
                .frame(width: 64, height: 64)
                .background(place.category.color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.title2.bold())
                Text(place.category.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                RatingStars(rating: place.rating, size: 14)
            }
            Spacer(minLength: 0)
        }
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            openInMapsMenu

            if !place.country.isEmpty {
                Label(place.country, systemImage: "globe")
                    .foregroundStyle(.secondary)
            }
            if !place.website.isEmpty, let url = makeURL(from: place.website) {
                Button { openURL(url) } label: {
                    Label(place.website, systemImage: "link")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
            }
            if !place.phone.isEmpty, let phoneURL = phoneURL(for: place.phone) {
                Button { openURL(phoneURL) } label: {
                    Label(place.phone, systemImage: "phone")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
            }
            if YelpService.hasAPIKey {
                Button {
                    showYelpEnrichment = true
                } label: {
                    Label("Enrich from Yelp", systemImage: "sparkles.rectangle.stack")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
            }
        }
        .font(.subheadline)
    }

    private var visitStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visit Status").font(.headline)
            Picker("Visit Status", selection: Binding(
                get: { place.visitStatus },
                set: {
                    place.visitStatus = $0
                    place.updatedAt = Date()
                })
            ) {
                Text("Visited").tag(VisitStatus.visited)
                Text("Want to Go").tag(VisitStatus.wantToGo)
                Text("None").tag(VisitStatus.none)
            }
            .pickerStyle(.segmented)
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating").font(.headline)
            InteractiveRatingStars(rating: Binding(
                get: { place.rating },
                set: {
                    place.rating = $0
                    place.updatedAt = Date()
                }
            ))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            Text(place.notes)
                .font(.body)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags").font(.headline)
                Spacer()
                Button {
                    showTagsPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appAccent)
                }
            }
            let tagList = place.tags ?? []
            if tagList.isEmpty {
                Text("No tags").font(.caption).foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tagList) { tag in
                        TagBadge(tag: tag)
                    }
                }
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Collections").font(.headline)
                Spacer()
                Button {
                    showCollectionsPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appAccent)
                }
            }
            let collectionList = place.collections ?? []
            if collectionList.isEmpty {
                Text("Not in any collection").font(.caption).foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(collectionList) { c in
                        Text(c.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.appAccent.opacity(0.15))
                            .foregroundStyle(Color.appAccent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(place.photos, id: \.self) { id in
                        if let img = PhotoStore.load(id) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label("Delete Place", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    @ViewBuilder
    private var openInMapsMenu: some View {
        let addressText = place.address.isEmpty
            ? "Open in Maps"
            : place.address

        Menu {
            Button {
                MapsLauncher.openInAppleMaps(place: place)
            } label: {
                Label("Apple Maps", systemImage: "applelogo")
            }
            Button {
                MapsLauncher.openInGoogleMaps(place: place)
            } label: {
                if MapsLauncher.isGoogleMapsAvailable {
                    Label("Google Maps", systemImage: "g.circle")
                } else {
                    // Honest about the fallback: this will open a web search.
                    Label("Search on Google Maps (web)", systemImage: "g.circle")
                }
            }
        } label: {
            Label(addressText, systemImage: "mappin.and.ellipse")
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func makeURL(from string: String) -> URL? {
        var raw = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            raw = "https://" + raw
        }
        return URL(string: raw)
    }

    private func phoneURL(for raw: String) -> URL? {
        let digits = raw.filter { "+0123456789".contains($0) }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}
