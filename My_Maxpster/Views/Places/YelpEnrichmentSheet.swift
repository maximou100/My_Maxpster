//
//  YelpEnrichmentSheet.swift
//  My_Maxpster
//
//  Looks up the place on Yelp and lets the user merge selected fields back into
//  their Place entity. Includes the required "Powered by Yelp" attribution.
//

import SwiftUI

struct YelpEnrichmentSheet: View {
    @Bindable var place: Place
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var state: LoadState = .loading
    @State private var candidates: [YelpBusiness] = []
    @State private var selected: YelpBusiness?

    @State private var applyRating: Bool = true
    @State private var applyPhone: Bool = true
    @State private var applyWebsite: Bool = true
    @State private var applyPrice: Bool = true

    enum LoadState {
        case loading
        case ready
        case empty
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    loadingView
                case .ready:
                    matchView
                case .empty:
                    ContentUnavailableView("Not on Yelp",
                                            systemImage: "magnifyingglass",
                                            description: Text("No Yelp business matched “\(place.name)” near these coordinates."))
                case .error(let message):
                    ContentUnavailableView("Yelp error",
                                            systemImage: "exclamationmark.triangle.fill",
                                            description: Text(message))
                }
            }
            .navigationTitle("Enrich from Yelp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if case .ready = state, selected != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") { apply() }
                            .bold()
                    }
                }
            }
            .task { await search() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching Yelp near \(place.name)…")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var matchView: some View {
        Form {
            if candidates.count > 1 {
                Section("Candidates") {
                    ForEach(candidates) { business in
                        Button {
                            selected = business
                        } label: {
                            candidateRow(business)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let business = selected {
                Section("Best match") {
                    matchHeader(business)
                }

                Section("Apply") {
                    if let r = roundedRating(from: business.rating) {
                        Toggle(isOn: $applyRating) {
                            Label("Rating: \(r)★ (Yelp \(business.rating ?? 0, format: .number.precision(.fractionLength(1))))",
                                  systemImage: "star.fill")
                        }
                    }
                    if let p = business.price, !p.isEmpty {
                        Toggle(isOn: $applyPrice) {
                            Label("Price tier: \(p) (added to notes)", systemImage: "dollarsign.circle")
                        }
                    }
                    if let phone = business.displayPhone, !phone.isEmpty {
                        Toggle(isOn: $applyPhone) {
                            Label("Phone: \(phone)", systemImage: "phone")
                        }
                        .disabled(!place.phone.isEmpty)
                        if !place.phone.isEmpty {
                            Text("Place already has a phone; toggle off to keep it.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $applyWebsite) {
                        Label("Yelp page URL as website", systemImage: "link")
                    }
                    .disabled(!place.website.isEmpty)
                    if !place.website.isEmpty {
                        Text("Place already has a website; toggle off to keep it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: business.url) { openURL(url) }
                    } label: {
                        Label("View on Yelp", systemImage: "safari")
                    }
                } footer: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Powered by Yelp")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func matchHeader(_ b: YelpBusiness) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(b.name).font(.headline)
            if let loc = b.location {
                Text(loc.displayAddressJoined)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if let r = b.rating {
                    Label(String(format: "%.1f", r), systemImage: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
                if let p = b.price {
                    Text(p).font(.subheadline).foregroundStyle(.secondary)
                }
                if let n = b.reviewCount {
                    Text("\(n) reviews")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let d = b.distance {
                    Text("\(Int(d)) m away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let cats = b.categories, !cats.isEmpty {
                Text(cats.map(\.title).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func candidateRow(_ b: YelpBusiness) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(b.name).font(.subheadline.weight(.medium))
                if let loc = b.location {
                    Text(loc.displayAddressJoined)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if selected?.id == b.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.appAccent)
            } else if let d = b.distance {
                Text("\(Int(d))m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Logic

    private func search() async {
        do {
            let results = try await YelpService.search(
                term: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                limit: 5
            )
            candidates = results
            selected = results.first
            state = .ready
        } catch let e as YelpError {
            if case .noResults = e {
                state = .empty
            } else {
                state = .error(e.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func apply() {
        guard let b = selected else { return }
        if applyRating, let r = roundedRating(from: b.rating) {
            place.rating = r
        }
        if applyPrice, let p = b.price, !p.isEmpty {
            let marker = "Price tier: \(p)"
            if !place.notes.contains(marker) {
                if place.notes.isEmpty {
                    place.notes = marker
                } else {
                    place.notes += "\n\n" + marker
                }
            }
        }
        if applyPhone, place.phone.isEmpty, let phone = b.displayPhone, !phone.isEmpty {
            place.phone = phone
        }
        if applyWebsite, place.website.isEmpty {
            place.website = b.url
        }
        place.updatedAt = Date()
        dismiss()
    }

    private func roundedRating(from raw: Double?) -> Int? {
        guard let raw else { return nil }
        let r = Int(raw.rounded())
        return (1...5).contains(r) ? r : nil
    }
}
