//
//  PlacePin.swift
//  My_Maxpster
//

import SwiftUI

struct PlacePin: View {
    let category: PlaceCategory
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(category.color)
            .frame(width: isSelected ? 22 : 14, height: isSelected ? 22 : 14)
            .overlay(
                Circle()
                    .stroke(Color(uiColor: .systemBackground).opacity(0.9), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .animation(.spring(duration: 0.2), value: isSelected)
    }
}
