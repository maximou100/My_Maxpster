//
//  PlacePin.swift
//  My_Maxpster
//
//  Drawn 200+ times simultaneously on the map — keep it cheap.
//  No shadow (CPU blur is the most expensive modifier here),
//  no spring animation (would compile a separate transaction per pin),
//  and use a Rectangle-replacement stroke trick instead of overlay where possible.
//

import SwiftUI

struct PlacePin: View {
    let category: PlaceCategory
    let isSelected: Bool

    var body: some View {
        let size: CGFloat = isSelected ? 22 : 12
        Circle()
            .strokeBorder(.background.opacity(0.9), lineWidth: 1.5)
            .background(Circle().fill(category.color))
            .frame(width: size, height: size)
    }
}
