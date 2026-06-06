//
//  FlowLayout.swift
//  My_Maxpster
//

import SwiftUI

/// A simple flow / wrap layout that places subviews left-to-right, wrapping when out of room.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { partial, row in
            partial + row.height + (partial == 0 ? 0 : lineSpacing)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : rows.map(\.width).max() ?? 0,
                      height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (i, sub) in subviews.enumerated() {
            let s = sub.sizeThatFits(.unspecified)
            let nextWidth = current.width + (current.indices.isEmpty ? 0 : spacing) + s.width
            if nextWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            if !current.indices.isEmpty {
                current.width += spacing
            }
            current.indices.append(i)
            current.width += s.width
            current.height = max(current.height, s.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
