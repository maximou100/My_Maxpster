//
//  PlaceCard.swift
//  My_Maxpster
//

import SwiftUI

struct PlaceCard: View {
    let place: Place

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(place.category.emoji)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(place.category.color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .lineLimit(1)

                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if place.rating != nil {
                        RatingStars(rating: place.rating, size: 12)
                    }
                    VisitStatusBadge(status: place.visitStatus)
                }

                let tagList = place.tags ?? []
                if !tagList.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tagList.prefix(3)) { tag in
                            TagBadge(tag: tag)
                        }
                        if tagList.count > 3 {
                            Text("+\(tagList.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
