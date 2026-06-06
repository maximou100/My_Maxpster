//
//  PlacesTab.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

enum PlaceSort: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A–Z)"
    case ratingDesc = "Rating (high→low)"
    case recent = "Recently added"
    case category = "Category"

    var id: String { rawValue }
}

struct PlacesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FilterState.self) private var filter
    @Query(sort: \Place.createdAt, order: .reverse) private var places: [Place]

    @State private var sort: PlaceSort = .recent
    @State private var showingForm = false
    @State private var showingFilters = false

    private var filtered: [Place] {
        let base = filter.apply(to: places)
        switch sort {
        case .nameAsc:
            return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .ratingDesc:
            return base.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .recent:
            return base.sorted { $0.createdAt > $1.createdAt }
        case .category:
            return base.sorted { $0.category.label < $1.category.label }
        }
    }

    var body: some View {
        @Bindable var filter = filter

        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        places.isEmpty ? "No Places Yet" : "No Matches",
                        systemImage: "mappin.slash",
                        description: Text(places.isEmpty
                                          ? "Tap + to add your first place."
                                          : "Try clearing some filters.")
                    )
                } else {
                    List {
                        ForEach(filtered) { place in
                            NavigationLink {
                                PlaceDetail(place: place)
                            } label: {
                                PlaceCard(place: place)
                            }
                        }
                        .onDelete(perform: deletePlaces)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Places")
            .searchable(text: $filter.searchQuery, prompt: "Search places")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(PlaceSort.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if filter.activeFilterCount > 0 {
                                Text("\(filter.activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(Color.appAccent)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                PlaceForm(mode: .create(prefill: nil))
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet()
            }
        }
    }

    private func deletePlaces(offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(filtered[idx])
        }
    }
}
