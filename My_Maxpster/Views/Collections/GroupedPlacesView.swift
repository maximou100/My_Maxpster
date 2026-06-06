//
//  GroupedPlacesView.swift
//  My_Maxpster
//
//  Generic list of places filtered by a derived grouping (category / tag / country).
//

import SwiftUI
import SwiftData

struct GroupedPlacesView: View {
    let title: String
    let subtitle: String?
    let accent: Color
    let places: [Place]

    init(title: String, subtitle: String? = nil, accent: Color = .appAccent, places: [Place]) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.places = places.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if places.isEmpty {
                ContentUnavailableView("No places",
                                       systemImage: "mappin.slash",
                                       description: Text("Nothing here yet."))
            } else {
                List {
                    if let subtitle, !subtitle.isEmpty {
                        Section {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("\(places.count) place\(places.count == 1 ? "" : "s")") {
                        ForEach(places) { place in
                            NavigationLink {
                                PlaceDetail(place: place)
                            } label: {
                                PlaceCard(place: place)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
