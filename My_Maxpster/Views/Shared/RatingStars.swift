//
//  RatingStars.swift
//  My_Maxpster
//

import SwiftUI

struct RatingStars: View {
    let rating: Int?
    var size: CGFloat = 14
    var color: Color = .appAccent

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= (rating ?? 0) ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= (rating ?? 0) ? color : Color.secondary.opacity(0.4))
            }
        }
    }
}

struct InteractiveRatingStars: View {
    @Binding var rating: Int?
    var size: CGFloat = 28
    var color: Color = .appAccent

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    if rating == i {
                        rating = nil
                    } else {
                        rating = i
                    }
                } label: {
                    Image(systemName: i <= (rating ?? 0) ? "star.fill" : "star")
                        .font(.system(size: size))
                        .foregroundStyle(i <= (rating ?? 0) ? color : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
