//
//  MapsLauncher.swift
//  My_Maxpster
//
//  Centralizes "Open this place in <Apple|Google> Maps" behavior.
//
//  Note: `isGoogleMapsAvailable` only returns true if `comgooglemaps` is listed
//  in the app's `LSApplicationQueriesSchemes`. Without that allow-list entry,
//  iOS forces `canOpenURL` to return false even when Google Maps is installed.
//  In that case the user still gets a working result via the web fallback.
//

import Foundation
import UIKit
import MapKit
import CoreLocation

enum MapsLauncher {
    // MARK: - Apple Maps

    static func openInAppleMaps(place: Place) {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = place.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: NSNumber(value: MKMapType.standard.rawValue)
        ])
    }

    // MARK: - Google Maps

    /// True if the Google Maps iOS app appears to be installed.
    /// Requires `comgooglemaps` in `LSApplicationQueriesSchemes` to detect reliably.
    static var isGoogleMapsAvailable: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Opens the place in the Google Maps app when installed (with coordinates + name pin),
    /// otherwise opens the Google Maps website with a name-based search.
    static func openInGoogleMaps(place: Place) {
        let lat = place.latitude
        let lon = place.longitude
        let encodedName = place.name
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if isGoogleMapsAvailable {
            // Deep link with a label at the place's coordinates.
            // "comgooglemaps://?q=label@lat,lon" → pin labelled with the name.
            let deepLink = "comgooglemaps://?q=\(encodedName)&center=\(lat),\(lon)&zoom=17"
            if let url = URL(string: deepLink) {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback: web Google Maps with a name-based search.
        // This also routes to the Google Maps app when installed (universal link),
        // and otherwise opens in Safari.
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: place.name)
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}
