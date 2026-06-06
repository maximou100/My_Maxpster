//
//  DashboardTab.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData
import Charts

struct DashboardTab: View {
    @Query private var places: [Place]
    @Query private var tags: [Tag]
    @State private var showingSettings = false

    private var totalPlaces: Int { places.count }
    private var totalCountries: Int { Set(places.map(\.country).filter { !$0.isEmpty }).count }
    private var visitedCount: Int { places.filter { $0.visitStatus == .visited }.count }
    private var wantToGoCount: Int { places.filter { $0.visitStatus == .wantToGo }.count }

    private var categoryCounts: [(category: PlaceCategory, count: Int)] {
        let grouped = Dictionary(grouping: places, by: \.category)
        return PlaceCategory.allCases
            .map { ($0, grouped[$0]?.count ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.count > $1.count }
    }

    private var ratingCounts: [(rating: Int, count: Int)] {
        (1...5).map { r in
            (r, places.filter { $0.rating == r }.count)
        }
    }

    private var countryCounts: [(country: String, count: Int)] {
        let grouped = Dictionary(grouping: places, by: \.country)
            .filter { !$0.key.isEmpty }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
        return grouped.map { ($0.0, $0.1) }
    }

    private var topTags: [(tag: Tag, count: Int)] {
        tags.map { ($0, ($0.places ?? []).count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(20)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    statGrid
                    if !categoryCounts.isEmpty { categoryChart }
                    if places.contains(where: { $0.rating != nil }) { ratingChart }
                    if !topTags.isEmpty { tagSection }
                    if !countryCounts.isEmpty { countrySection }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
        }
    }

    private var statGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(value: totalPlaces, label: "Places", systemImage: "mappin.and.ellipse")
            StatCard(value: totalCountries, label: "Countries", systemImage: "globe")
            StatCard(value: visitedCount, label: "Visited", systemImage: "checkmark.seal")
            StatCard(value: wantToGoCount, label: "Want to Go", systemImage: "bookmark")
        }
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category Breakdown").font(.headline)
            Chart(categoryCounts, id: \.category) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Category", item.category.label)
                )
                .foregroundStyle(item.category.color)
                .annotation(position: .trailing) {
                    Text("\(item.count)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(categoryCounts.count) * 32 + 24)
            .chartXAxis(.hidden)
        }
    }

    private var ratingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating Distribution").font(.headline)
            Chart(ratingCounts, id: \.rating) { item in
                BarMark(
                    x: .value("Rating", "\(item.rating)★"),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.appAccent)
            }
            .frame(height: 180)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Tags").font(.headline)
            FlowLayout(spacing: 6) {
                ForEach(topTags, id: \.tag.id) { item in
                    HStack(spacing: 4) {
                        Text(item.tag.name)
                        Text("\(item.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(hex: item.tag.color).opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: item.tag.color).opacity(0.15))
                    .foregroundStyle(Color(hex: item.tag.color))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Countries").font(.headline)
            VStack(spacing: 6) {
                ForEach(Array(countryCounts.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.country)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    Divider()
                }
            }
        }
    }
}

struct StatCard: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.appAccent)
            Text("\(value)")
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
