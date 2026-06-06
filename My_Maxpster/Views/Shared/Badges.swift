//
//  Badges.swift
//  My_Maxpster
//

import SwiftUI

struct VisitStatusBadge: View {
    let status: VisitStatus

    var body: some View {
        switch status {
        case .visited:
            label(text: "Visited", system: "checkmark.circle.fill", color: .green)
        case .wantToGo:
            label(text: "Want to Go", system: "bookmark.fill", color: .appAccent)
        case .none:
            EmptyView()
        }
    }

    private func label(text: String, system: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(color)
    }
}

struct TagBadge: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: tag.color).opacity(0.18))
            .foregroundStyle(Color(hex: tag.color))
            .clipShape(Capsule())
    }
}

struct CategoryChip: View {
    let category: PlaceCategory
    var selected: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(category.emoji)
            if !compact {
                Text(category.label)
                    .font(.caption)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, 6)
        .background(
            (selected ? category.color : Color.secondary.opacity(0.12))
                .opacity(selected ? 0.25 : 1)
        )
        .overlay(
            Capsule()
                .stroke(selected ? category.color : .clear, lineWidth: 1.5)
        )
        .clipShape(Capsule())
    }
}
