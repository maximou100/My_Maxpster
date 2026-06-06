//
//  YelpService.swift
//  My_Maxpster
//
//  Minimal client for the Yelp Fusion API.
//  Uses the user-provided API key stored in Keychain.
//
//  Endpoints used:
//    GET /v3/businesses/search?term=…&latitude=…&longitude=…&limit=…&sort_by=distance
//
//  Yelp ToS requires "Powered by Yelp" attribution wherever Yelp content is shown.
//

import Foundation

// MARK: - Models

struct YelpBusiness: Identifiable, Decodable {
    let id: String
    let alias: String?
    let name: String
    let rating: Double?
    let price: String?
    let phone: String?
    let displayPhone: String?
    let url: String
    let imageUrl: String?
    let reviewCount: Int?
    let categories: [YelpCategoryTag]?
    let location: YelpLocation?
    let coordinates: YelpCoords
    let distance: Double?
}

struct YelpCategoryTag: Decodable, Hashable {
    let alias: String
    let title: String
}

struct YelpLocation: Decodable {
    let address1: String?
    let city: String?
    let state: String?
    let country: String?
    let zipCode: String?
    let displayAddress: [String]?

    var displayAddressJoined: String {
        (displayAddress ?? []).joined(separator: ", ")
    }
}

struct YelpCoords: Decodable {
    let latitude: Double
    let longitude: Double
}

struct YelpSearchResponse: Decodable {
    let businesses: [YelpBusiness]
    let total: Int?
}

// MARK: - Errors

enum YelpError: LocalizedError {
    case missingKey
    case invalidKey
    case quotaExceeded
    case noResults
    case network(Error)
    case decode(Error)
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .missingKey:     return "No Yelp API key configured. Add one in Settings."
        case .invalidKey:     return "Yelp rejected the API key. Double-check it in Settings."
        case .quotaExceeded:  return "Yelp daily quota exceeded (free tier is 500 calls / day)."
        case .noResults:      return "No match on Yelp for this place."
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .decode(let e):  return "Couldn't read Yelp's response: \(e.localizedDescription)"
        case .server(let s, let body):
            return "Yelp returned HTTP \(s)\(body.flatMap { ": \($0)" } ?? "")."
        }
    }
}

// MARK: - Service

enum YelpService {
    /// Account name used by KeychainStore for the Fusion API key.
    static let keychainAccount = "yelp.fusion.api_key"
    private static let baseURL = URL(string: "https://api.yelp.com/v3")!

    static var hasAPIKey: Bool {
        guard let key = KeychainStore.read(keychainAccount) else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func saveAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return KeychainStore.save(trimmed, for: keychainAccount)
    }

    static func deleteAPIKey() {
        KeychainStore.delete(keychainAccount)
    }

    private static func storedKey() throws -> String {
        guard let key = KeychainStore.read(keychainAccount),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw YelpError.missingKey }
        return key
    }

    // MARK: Endpoints

    /// Searches Yelp for businesses matching `term` near a coordinate. Sorted by distance.
    static func search(term: String, latitude: Double, longitude: Double, limit: Int = 5) async throws -> [YelpBusiness] {
        var components = URLComponents(url: baseURL.appendingPathComponent("businesses/search"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "limit", value: String(min(max(1, limit), 20))),
            URLQueryItem(name: "sort_by", value: "distance")
        ]
        guard let url = components.url else { throw YelpError.server(0, nil) }

        let response: YelpSearchResponse = try await request(url: url)
        if response.businesses.isEmpty { throw YelpError.noResults }
        return response.businesses
    }

    /// Lightweight call that just verifies the API key returns a 200 from a known query.
    static func verifyCurrentKey() async -> Result<Void, YelpError> {
        // San Francisco, a coordinate guaranteed to have results, with limit=1.
        do {
            _ = try await search(term: "coffee", latitude: 37.7749, longitude: -122.4194, limit: 1)
            return .success(())
        } catch YelpError.noResults {
            return .success(()) // Key works; just no results — fine for verification.
        } catch let e as YelpError {
            return .failure(e)
        } catch {
            return .failure(.network(error))
        }
    }

    // MARK: - Low-level

    private static func request<T: Decodable>(url: URL) async throws -> T {
        let key = try storedKey()
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw YelpError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw YelpError.server(0, nil)
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw YelpError.invalidKey
        case 429:
            throw YelpError.quotaExceeded
        default:
            let body = String(data: data, encoding: .utf8)?.prefix(160).description
            throw YelpError.server(http.statusCode, body)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YelpError.decode(error)
        }
    }
}
