//
//  CollectionDetail.swift
//  My_Maxpster
//

import SwiftUI
import SwiftData

struct CollectionDetail: View {
    @Bindable var collection: PlaceCollection
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editingMeta = false
    @State private var addingPlaces = false
    @State private var confirmDelete = false

    var orderedPlaces: [Place] { collection.orderedPlaces }

    var body: some View {
        Group {
            if orderedPlaces.isEmpty {
                ContentUnavailableView(
                    "Empty Collection",
                    systemImage: "folder",
                    description: Text("Add places from the list below.")
                )
            } else {
                List {
                    ForEach(orderedPlaces) { place in
                        NavigationLink {
                            PlaceDetail(place: place)
                        } label: {
                            PlaceCard(place: place)
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: removeFromCollection)
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        addingPlaces = true
                    } label: { Label("Add Places", systemImage: "plus") }
                    Button {
                        editingMeta = true
                    } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: { Label("Delete Collection", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editingMeta) {
            CollectionEditSheet(collection: collection)
        }
        .sheet(isPresented: $addingPlaces) {
            AddPlacesToCollectionSheet(collection: collection)
        }
        .alert("Delete this collection?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(collection)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Places will remain saved.")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ids = collection.sortOrder
        if ids.count != orderedPlaces.count {
            ids = orderedPlaces.map(\.id)
        }
        ids.move(fromOffsets: source, toOffset: destination)
        collection.sortOrder = ids
        collection.updatedAt = Date()
    }

    private func removeFromCollection(_ offsets: IndexSet) {
        var places = collection.places ?? []
        for idx in offsets {
            let place = orderedPlaces[idx]
            if let pIdx = places.firstIndex(where: { $0.id == place.id }) {
                places.remove(at: pIdx)
            }
            collection.sortOrder.removeAll { $0 == place.id }
        }
        collection.places = places
        collection.updatedAt = Date()
    }
}

struct CollectionEditSheet: View {
    @Bindable var collection: PlaceCollection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $collection.name)
                }
                Section("Description") {
                    TextField("Description", text: $collection.descriptionText, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        collection.updatedAt = Date()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddPlacesToCollectionSheet: View {
    @Bindable var collection: PlaceCollection
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Place.name) private var allPlaces: [Place]
    @State private var query: String = ""

    var filtered: [Place] {
        guard !query.isEmpty else { return allPlaces }
        return allPlaces.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { place in
                Button {
                    toggle(place)
                } label: {
                    HStack {
                        PlaceCard(place: place)
                        Spacer()
                        if (collection.places ?? []).contains(where: { $0.id == place.id }) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: "Search places")
            .navigationTitle("Add Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }

    private func toggle(_ place: Place) {
        var places = collection.places ?? []
        if let idx = places.firstIndex(where: { $0.id == place.id }) {
            places.remove(at: idx)
            collection.sortOrder.removeAll { $0 == place.id }
        } else {
            places.append(place)
            if !collection.sortOrder.contains(place.id) {
                collection.sortOrder.append(place.id)
            }
        }
        collection.places = places
        collection.updatedAt = Date()
    }
}
