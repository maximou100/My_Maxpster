//
//  TagsPicker.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

struct TagsPicker: View {
    @Bindable var place: Place
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var newTagName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Add a new tag") {
                    HStack {
                        TextField("Tag name", text: $newTagName)
                            .textInputAutocapitalization(.words)
                        Button("Add") { addTag() }
                            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Available tags") {
                    if allTags.isEmpty {
                        Text("No tags yet").foregroundStyle(.secondary)
                    }
                    ForEach(allTags) { tag in
                        Button {
                            toggle(tag)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.color))
                                    .frame(width: 12, height: 12)
                                Text(tag.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if (place.tags ?? []).contains(where: { $0.id == tag.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ tag: Tag) {
        var tags = place.tags ?? []
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags.remove(at: idx)
        } else {
            tags.append(tag)
        }
        place.tags = tags
        place.updatedAt = Date()
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var tags = place.tags ?? []
        if let existing = allTags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            if !tags.contains(where: { $0.id == existing.id }) {
                tags.append(existing)
            }
        } else {
            let tag = Tag(name: name)
            modelContext.insert(tag)
            tags.append(tag)
        }
        place.tags = tags
        place.updatedAt = Date()
        newTagName = ""
    }
}

struct CollectionsPicker: View {
    @Bindable var place: Place
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceCollection.name) private var allCollections: [PlaceCollection]
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Add a new collection") {
                    HStack {
                        TextField("Collection name", text: $newName)
                            .textInputAutocapitalization(.words)
                        Button("Add") { addCollection() }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Available collections") {
                    if allCollections.isEmpty {
                        Text("No collections yet").foregroundStyle(.secondary)
                    }
                    ForEach(allCollections) { c in
                        Button {
                            toggle(c)
                        } label: {
                            HStack {
                                Text(c.name).foregroundStyle(.primary)
                                Spacer()
                                if (place.collections ?? []).contains(where: { $0.id == c.id }) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ c: PlaceCollection) {
        var collections = place.collections ?? []
        if let idx = collections.firstIndex(where: { $0.id == c.id }) {
            collections.remove(at: idx)
            c.sortOrder.removeAll { $0 == place.id }
        } else {
            collections.append(c)
            c.sortOrder.append(place.id)
        }
        place.collections = collections
        c.updatedAt = Date()
        place.updatedAt = Date()
    }

    private func addCollection() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let c = PlaceCollection(name: name)
        modelContext.insert(c)
        var collections = place.collections ?? []
        collections.append(c)
        place.collections = collections
        c.sortOrder.append(place.id)
        place.updatedAt = Date()
        newName = ""
    }
}
