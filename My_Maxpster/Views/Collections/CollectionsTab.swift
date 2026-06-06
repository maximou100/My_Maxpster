//
//  CollectionsTab.swift
//  My_Maxpster
//
//  Hub view: browse places grouped by Category, Tag, Country, or by user-created
//  manual Collections.
//

import SwiftUI
import SwiftData

struct CollectionsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceCollection.name) private var collections: [PlaceCollection]
    @Query private var places: [Place]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var creating = false
    @State private var newName: String = ""
    @State private var newDesc: String = ""

    // MARK: - Derived groupings

    private var categoryCounts: [(category: PlaceCategory, count: Int)] {
        let grouped = Dictionary(grouping: places, by: \.category)
        return PlaceCategory.allCases
            .map { ($0, grouped[$0]?.count ?? 0) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private var tagsWithCounts: [(tag: Tag, count: Int)] {
        tags
            .map { ($0, ($0.places ?? []).count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { ($0.0, $0.1) }
    }

    private var countryCounts: [(country: String, count: Int)] {
        Dictionary(grouping: places.filter { !$0.country.isEmpty }, by: \.country)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty && collections.isEmpty {
                    ContentUnavailableView(
                        "Nothing to organise yet",
                        systemImage: "folder",
                        description: Text("Add some places and they'll appear grouped here by category, tag, country, or any collection you create.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newName = ""
                        newDesc = ""
                        creating = true
                    } label: { Image(systemName: "folder.badge.plus") }
                }
            }
            .sheet(isPresented: $creating) {
                NewCollectionSheet(
                    name: $newName,
                    description: $newDesc,
                    onCreate: create,
                    onCancel: { creating = false }
                )
            }
        }
    }

    private var list: some View {
        List {
            if !categoryCounts.isEmpty {
                Section("Categories") {
                    ForEach(categoryCounts, id: \.category) { item in
                        NavigationLink {
                            GroupedPlacesView(
                                title: item.category.label,
                                accent: item.category.color,
                                places: places.filter { $0.category == item.category }
                            )
                        } label: {
                            categoryRow(item.category, count: item.count)
                        }
                    }
                }
            }

            if !tagsWithCounts.isEmpty {
                Section("Tags") {
                    ForEach(tagsWithCounts, id: \.tag.id) { item in
                        NavigationLink {
                            GroupedPlacesView(
                                title: item.tag.name,
                                subtitle: "Tagged \"\(item.tag.name)\"",
                                accent: Color(hex: item.tag.color),
                                places: item.tag.places ?? []
                            )
                        } label: {
                            tagRow(item.tag, count: item.count)
                        }
                    }
                }
            }

            if !countryCounts.isEmpty {
                Section("Countries") {
                    ForEach(countryCounts, id: \.country) { item in
                        NavigationLink {
                            GroupedPlacesView(
                                title: item.country,
                                accent: .appAccent,
                                places: places.filter { $0.country == item.country }
                            )
                        } label: {
                            countryRow(item.country, count: item.count)
                        }
                    }
                }
            }

            Section("My Collections") {
                if collections.isEmpty {
                    Text("No collections yet. Tap the folder icon to create one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(collections) { c in
                        NavigationLink {
                            CollectionDetail(collection: c)
                        } label: {
                            collectionRow(c)
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
        }
    }

    // MARK: - Rows

    private func categoryRow(_ category: PlaceCategory, count: Int) -> some View {
        HStack(spacing: 12) {
            Text(category.emoji)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(category.color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(category.label).font(.subheadline.weight(.medium))
            Spacer()
            countBadge(count, color: category.color)
        }
    }

    private func tagRow(_ tag: Tag, count: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: tag.color))
                .frame(width: 14, height: 14)
            Text(tag.name).font(.subheadline.weight(.medium))
            Spacer()
            countBadge(count, color: Color(hex: tag.color))
        }
    }

    private func countryRow(_ country: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(Color.appAccent)
                .frame(width: 32, height: 32)
                .background(Color.appAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(country).font(.subheadline.weight(.medium))
            Spacer()
            countBadge(count, color: .appAccent)
        }
    }

    private func collectionRow(_ c: PlaceCollection) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(c.name).font(.subheadline.weight(.medium))
                if !c.descriptionText.isEmpty {
                    Text(c.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            countBadge((c.places ?? []).count, color: .appAccent)
        }
    }

    private func countBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Actions

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let c = PlaceCollection(name: name, descriptionText: newDesc)
        modelContext.insert(c)
        creating = false
    }

    private func deleteCollections(offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(collections[idx])
        }
    }
}

private struct NewCollectionSheet: View {
    @Binding var name: String
    @Binding var description: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Collection name", text: $name)
                }
                Section("Description") {
                    TextField("Optional", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create", action: onCreate)
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
