//
//  OnlinePlacePreview.swift
//  My_Maxpster
//
//  Preview sheet shown after the user taps an online (Apple Maps) search result.
//  Lets them inspect the place and add it to their library with the form pre-filled.
//

import SwiftUI
import MapKit

struct OnlinePlacePreview: View {
    let mapItem: MKMapItem
    var onAdd: (PlaceFormPrefill) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var position: MapCameraPosition

    init(mapItem: MKMapItem, onAdd: @escaping (PlaceFormPrefill) -> Void) {
        self.mapItem = mapItem
        self.onAdd = onAdd
        let coord = mapItem.location.coordinate
        _position = State(initialValue: .region(
            MKCoordinateRegion(center: coord, latitudinalMeters: 600, longitudinalMeters: 600)
        ))
    }

    private var category: PlaceCategory { mapItem.inferredPlaceCategory }
    private var name: String { mapItem.name ?? "Unknown place" }
    private var coordinate: CLLocationCoordinate2D { mapItem.location.coordinate }
    private var address: String { mapItem.oneLineAddress }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Map(position: $position, interactionModes: []) {
                        Annotation(name, coordinate: coordinate) {
                            PlacePin(category: category, isSelected: true)
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)

                    HStack(alignment: .top, spacing: 12) {
                        Text(category.emoji)
                            .font(.system(size: 38))
                            .frame(width: 56, height: 56)
                            .background(category.color.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name).font(.title3.bold())
                            Text(category.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("From Apple Maps")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    if !address.isEmpty {
                        infoRow(systemImage: "mappin.and.ellipse", text: address)
                    }
                    if let phone = mapItem.phoneNumber, !phone.isEmpty {
                        Button {
                            if let url = URL(string: "tel://\(phone.filter { "+0123456789".contains($0) })") {
                                openURL(url)
                            }
                        } label: {
                            infoRow(systemImage: "phone", text: phone)
                        }
                        .buttonStyle(.plain)
                    }
                    if let url = mapItem.url {
                        Button {
                            openURL(url)
                        } label: {
                            infoRow(systemImage: "link", text: url.host ?? url.absoluteString)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Button {
                            mapItem.openInMaps()
                        } label: {
                            Label("Open in Maps", systemImage: "arrow.up.forward.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            onAdd(prefill())
                            dismiss()
                        } label: {
                            Label("Add to my places", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 6)
                }
                .padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func infoRow(systemImage: String, text: String) -> some View {
        Label {
            Text(text).foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Color.appAccent)
        }
        .font(.subheadline)
    }

    private func prefill() -> PlaceFormPrefill {
        PlaceFormPrefill(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            country: mapItem.countryName,
            category: category,
            website: mapItem.url?.absoluteString ?? "",
            phone: mapItem.phoneNumber ?? ""
        )
    }
}
