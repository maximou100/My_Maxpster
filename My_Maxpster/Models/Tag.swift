//
//  Tag.swift
//  My_Maxpster
//

import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#F59E0B"
    var places: [Place]? = []

    init(id: UUID = UUID(), name: String, color: String = "#F59E0B") {
        self.id = id
        self.name = name
        self.color = color
    }
}
