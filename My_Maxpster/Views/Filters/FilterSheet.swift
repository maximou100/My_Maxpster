//
//  FilterSheet.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

struct FilterSheet: View {
    @Environment(FilterState.self) private var filter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \PlaceCollection.name) private var allCollections: [PlaceCollection]
    @Query private var allPlaces: [Place]

    var body: some View {
        @Bindable var filter = filter

        NavigationStack {
            Form {
                Section("Categories") {
                    FlowLayout(spacing: 6) {
                        ForEach(PlaceCategory.allCases) { c in
                            Button {
                                if filter.selectedCategories.contains(c) {
                                    filter.selectedCategories.remove(c)
                                } else {
                                    filter.selectedCategories.insert(c)
                                }
                            } label: {
                                CategoryChip(category: c,
                                             selected: filter.selectedCategories.contains(c))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Visit Status") {
                    Picker("Visit Status", selection: Binding(
                        get: { filter.visitStatus },
                        set: { filter.visitStatus = $0 }
                    )) {
                        Text("All").tag(VisitStatus?.none)
                        Text("Visited").tag(Optional(VisitStatus.visited))
                        Text("Want to Go").tag(Optional(VisitStatus.wantToGo))
                        Text("Not Set").tag(Optional(VisitStatus.none))
                    }
                    .pickerStyle(.segmented)
                }

                Section("Minimum Rating") {
                    HStack {
                        InteractiveRatingStars(rating: $filter.minimumRating, size: 24)
                        Spacer()
                        if filter.minimumRating != nil {
                            Button("Clear") { filter.minimumRating = nil }
                                .font(.caption)
                        }
                    }
                }

                if !allTags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 6) {
                            ForEach(allTags) { tag in
                                Button {
                                    if filter.selectedTagIDs.contains(tag.id) {
                                        filter.selectedTagIDs.remove(tag.id)
                                    } else {
                                        filter.selectedTagIDs.insert(tag.id)
                                    }
                                } label: {
                                    let isSel = filter.selectedTagIDs.contains(tag.id)
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isSel ? Color(hex: tag.color).opacity(0.3) : Color.secondary.opacity(0.12))
                                        .overlay(
                                            Capsule().stroke(isSel ? Color(hex: tag.color) : .clear, lineWidth: 1.5)
                                        )
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                let countries = Array(Set(allPlaces.map(\.country))).filter { !$0.isEmpty }.sorted()
                if !countries.isEmpty {
                    Section("Country") {
                        Picker("Country", selection: Binding(
                            get: { filter.country },
                            set: { filter.country = $0 }
                        )) {
                            Text("All").tag(String?.none)
                            ForEach(countries, id: \.self) { c in
                                Text(c).tag(Optional(c))
                            }
                        }
                    }
                }

                if !allCollections.isEmpty {
                    Section("Collection") {
                        Picker("Collection", selection: Binding(
                            get: { filter.selectedCollectionID },
                            set: { filter.selectedCollectionID = $0 }
                        )) {
                            Text("All").tag(UUID?.none)
                            ForEach(allCollections) { c in
                                Text(c.name).tag(Optional(c.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { filter.reset() }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}
