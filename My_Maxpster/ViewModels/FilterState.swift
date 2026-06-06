//
//  FilterState.swift
//  My_Maxpster
//

import Foundation
import Observation

@Observable
final class FilterState {
    var searchQuery: String = ""
    var selectedCategories: Set<PlaceCategory> = []
    var selectedTagIDs: Set<UUID> = []
    var selectedCollectionID: UUID? = nil
    var minimumRating: Int? = nil
    var visitStatus: VisitStatus? = nil
    var country: String? = nil

    var isActive: Bool {
        !searchQuery.isEmpty || !selectedCategories.isEmpty ||
        !selectedTagIDs.isEmpty || selectedCollectionID != nil ||
        minimumRating != nil || visitStatus != nil || country != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchQuery.isEmpty { count += 1 }
        if !selectedCategories.isEmpty { count += 1 }
        if !selectedTagIDs.isEmpty { count += 1 }
        if selectedCollectionID != nil { count += 1 }
        if minimumRating != nil { count += 1 }
        if visitStatus != nil { count += 1 }
        if country != nil { count += 1 }
        return count
    }

    func reset() {
        searchQuery = ""
        selectedCategories = []
        selectedTagIDs = []
        selectedCollectionID = nil
        minimumRating = nil
        visitStatus = nil
        country = nil
    }

    func apply(to places: [Place]) -> [Place] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = places.filter { place in
            if !selectedCategories.isEmpty, !selectedCategories.contains(place.category) {
                return false
            }
            if let visit = visitStatus, place.visitStatus != visit {
                return false
            }
            if let minR = minimumRating, (place.rating ?? 0) < minR {
                return false
            }
            if let c = country, !c.isEmpty, place.country != c {
                return false
            }
            if !selectedTagIDs.isEmpty {
                let placeTagIDs = Set((place.tags ?? []).map(\.id))
                if placeTagIDs.intersection(selectedTagIDs).isEmpty { return false }
            }
            if let cid = selectedCollectionID {
                if !(place.collections ?? []).contains(where: { $0.id == cid }) { return false }
            }
            if !q.isEmpty {
                let inName = place.name.localizedCaseInsensitiveContains(q)
                let inAddr = place.address.localizedCaseInsensitiveContains(q)
                let inNotes = place.notes.localizedCaseInsensitiveContains(q)
                if !(inName || inAddr || inNotes) { return false }
            }
            return true
        }

        if !q.isEmpty {
            return filtered.sorted { lhs, rhs in
                let lhsName = lhs.name.localizedCaseInsensitiveContains(q)
                let rhsName = rhs.name.localizedCaseInsensitiveContains(q)
                if lhsName != rhsName { return lhsName }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
        return filtered
    }
}
