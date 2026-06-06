//
//  PlaceCollection.swift
//  My_Maxpster
//
//  Named PlaceCollection to avoid clashing with Swift's Collection protocol.
//

import Foundation
import SwiftData

@Model
final class PlaceCollection {
    var id: UUID = UUID()
    var name: String = ""
    var descriptionText: String = ""
    var sortOrder: [UUID] = []
    var places: [Place]? = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        descriptionText: String = "",
        sortOrder: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Returns the places in this collection ordered by `sortOrder`.
    /// Any place not present in `sortOrder` is appended at the end.
    var orderedPlaces: [Place] {
        let placeList = places ?? []
        let lookup = Dictionary(uniqueKeysWithValues: placeList.map { ($0.id, $0) })
        var ordered: [Place] = sortOrder.compactMap { lookup[$0] }
        let known = Set(sortOrder)
        for p in placeList where !known.contains(p.id) {
            ordered.append(p)
        }
        return ordered
    }
}
