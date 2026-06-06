//
//  Place.swift
//  My_Maxpster
//

import Foundation
import SwiftData
import CoreLocation

enum VisitStatus: String, Codable, CaseIterable, Identifiable {
    case visited
    case wantToGo = "want_to_go"
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .visited: return "Visited"
        case .wantToGo: return "Want to Go"
        case .none: return "Not Set"
        }
    }

    var symbol: String {
        switch self {
        case .visited: return "checkmark.circle.fill"
        case .wantToGo: return "bookmark.fill"
        case .none: return "circle"
        }
    }
}

// CloudKit + SwiftData rules enforced here:
//  - No @Attribute(.unique) (CloudKit can't enforce uniqueness across devices).
//  - Every non-optional value-type property has an inline default so SwiftData
//    can construct records from partial CloudKit data on incoming sync.
//  - To-many relationships default to [].
@Model
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var categoryRaw: String = PlaceCategory.other.rawValue
    var rating: Int?
    var notes: String = ""
    var visitStatusRaw: String = VisitStatus.none.rawValue
    var photos: [String] = []
    var country: String = ""
    var website: String = ""
    var phone: String = ""
    var importedFrom: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // CloudKit requires the relationship array itself to be optional, not just its contents.
    @Relationship(inverse: \Tag.places) var tags: [Tag]? = []
    @Relationship(inverse: \PlaceCollection.places) var collections: [PlaceCollection]? = []

    init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        latitude: Double,
        longitude: Double,
        category: PlaceCategory = .other,
        rating: Int? = nil,
        notes: String = "",
        visitStatus: VisitStatus = .none,
        photos: [String] = [],
        country: String = "",
        website: String = "",
        phone: String = "",
        importedFrom: String? = nil,
        tags: [Tag] = [],
        collections: [PlaceCollection] = []
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.categoryRaw = category.rawValue
        self.rating = rating
        self.notes = notes
        self.visitStatusRaw = visitStatus.rawValue
        self.photos = photos
        self.country = country
        self.website = website
        self.phone = phone
        self.importedFrom = importedFrom
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
        self.collections = collections
    }

    var category: PlaceCategory {
        get { PlaceCategory.from(categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var visitStatus: VisitStatus {
        get { VisitStatus(rawValue: visitStatusRaw) ?? .none }
        set { visitStatusRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
