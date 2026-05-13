//
//  Item.swift
//  My_Maxpster
//
//  Created by Maxime LECLERCQ on 5/12/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
