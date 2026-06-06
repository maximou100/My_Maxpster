//
//  Category.swift
//  My_Maxpster
//

import SwiftUI

enum PlaceCategory: String, CaseIterable, Identifiable, Codable {
    case restaurant
    case bar
    case cafe
    case beer
    case beach
    case museum
    case nightclub
    case lodging
    case supermarket
    case shopping
    case wine
    case fastFood = "fast_food"
    case nature
    case music
    case business
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .restaurant: return "Restaurant"
        case .bar: return "Bar"
        case .cafe: return "Café"
        case .beer: return "Beer"
        case .beach: return "Beach"
        case .museum: return "Museum"
        case .nightclub: return "Nightclub"
        case .lodging: return "Lodging"
        case .supermarket: return "Supermarket"
        case .shopping: return "Shopping"
        case .wine: return "Wine"
        case .fastFood: return "Fast Food"
        case .nature: return "Nature/Forest"
        case .music: return "Music"
        case .business: return "Business"
        case .other: return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .restaurant: return "🍽️"
        case .bar: return "🍸"
        case .cafe: return "☕"
        case .beer: return "🍺"
        case .beach: return "🏖️"
        case .museum: return "🏛️"
        case .nightclub: return "🎶"
        case .lodging: return "🏨"
        case .supermarket: return "🛒"
        case .shopping: return "🛍️"
        case .wine: return "🍷"
        case .fastFood: return "🍔"
        case .nature: return "🌲"
        case .music: return "🎵"
        case .business: return "💼"
        case .other: return "📍"
        }
    }

    var hexColor: String {
        switch self {
        case .restaurant: return "#FF5733"
        case .bar: return "#C70039"
        case .cafe: return "#6F4E37"
        case .beer: return "#F4A460"
        case .beach: return "#00CED1"
        case .museum: return "#8B4513"
        case .nightclub: return "#9B59B6"
        case .lodging: return "#3498DB"
        case .supermarket: return "#27AE60"
        case .shopping: return "#E91E63"
        case .wine: return "#722F37"
        case .fastFood: return "#FF8C00"
        case .nature: return "#228B22"
        case .music: return "#FF1493"
        case .business: return "#34495E"
        case .other: return "#95A5A6"
        }
    }

    var color: Color { Color(hex: hexColor) }

    nonisolated static func from(_ raw: String) -> PlaceCategory {
        PlaceCategory(rawValue: raw) ?? .other
    }

    /// Maps Mapstr's `icon` field (which uses some different keys) into a PlaceCategory.
    nonisolated static func fromMapstrIcon(_ raw: String) -> PlaceCategory {
        let key = raw.lowercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "fastfood": return .fastFood
        case "forest", "nature": return .nature
        case "generic", "": return .other
        default:
            return PlaceCategory(rawValue: key) ?? .other
        }
    }
}
