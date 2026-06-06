//
//  LocationSearchService.swift
//  My_Maxpster
//
//  Uses Apple Maps via MKLocalSearchCompleter for as-you-type online suggestions
//  and MKLocalSearch to resolve a chosen suggestion into a full MKMapItem.
//  Google Maps isn't accessible directly without their Places SDK + paid API key.
//

import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    var query: String = "" {
        didSet { applyQuery() }
    }
    var region: MKCoordinateRegion? {
        didSet {
            if let r = region { completer.region = r }
        }
    }

    /// Online suggestions from Apple Maps.
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var isLoading: Bool = false

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    private func applyQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            suggestions = []
            isLoading = false
            completer.queryFragment = ""
            return
        }
        isLoading = true
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let newResults = completer.results
        Task { @MainActor in
            self.suggestions = newResults
            self.isLoading = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isLoading = false
        }
    }

    /// Resolves a completion to a concrete `MKMapItem` with full address and coordinates.
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        if let region { request.region = region }
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
}

extension MKMapItem {
    /// Best-effort mapping of an MKMapItem's POI category into our PlaceCategory enum.
    var inferredPlaceCategory: PlaceCategory {
        guard let poi = pointOfInterestCategory else { return .other }
        switch poi {
        case .restaurant, .foodMarket: return .restaurant
        case .cafe, .bakery: return .cafe
        case .nightlife, .brewery, .winery: return .bar
        case .hotel, .campground: return .lodging
        case .museum, .library, .theater, .musicVenue: return .museum
        case .beach, .marina: return .beach
        case .park, .nationalPark, .nationalMonument, .hiking, .stadium: return .nature
        case .store: return .shopping
        case .school, .university: return .business
        default:
            return .other
        }
    }

    /// A formatted single-line postal address suitable for our `address` field.
    var oneLineAddress: String {
        if let single = addressRepresentations?.fullAddress(includingRegion: true, singleLine: true),
           !single.isEmpty {
            return single
        }
        return address?.fullAddress ?? ""
    }

    var countryName: String {
        addressRepresentations?.regionName ?? ""
    }
}
