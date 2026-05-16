import Foundation
import SwiftUI

// Bridges TriggerStore (Codable persistence) and the SwiftUI views.
// All mutations go through the store, which fires its onSave callback
// — App.swift hooks that callback to engine.setTriggers so the matcher
// picks up edits the moment the user saves them.

@MainActor
final class TriggerListViewModel: ObservableObject {
    @Published var triggers: [Trigger] = []
    @Published var selectedID: String?
    @Published var searchText: String = ""

    private let store: TriggerStore

    init(store: TriggerStore) {
        self.store = store
        reload()
    }

    var filteredTriggers: [Trigger] {
        guard !searchText.isEmpty else { return triggers }
        let q = searchText.lowercased()
        return triggers.filter {
            $0.trigger.lowercased().contains(q)
                || $0.title.lowercased().contains(q)
                || $0.content.lowercased().contains(q)
        }
    }

    func reload() {
        do {
            triggers = try store.load().triggers
                .sorted { $0.trigger < $1.trigger }
        } catch {
            Logger.error("TriggerStore.load failed: \(error)")
        }
    }

    func add() {
        let now = Date()
        let new = Trigger(id: ULID.generate(now: now),
                          trigger: "newtrigger",
                          content: "",
                          title: "Untitled",
                          scope: nil,
                          createdAt: now,
                          updatedAt: now)
        triggers.append(new)
        selectedID = new.id
        persist()
    }

    func save(_ updated: Trigger) {
        var copy = updated
        copy.updatedAt = Date()
        if let i = triggers.firstIndex(where: { $0.id == copy.id }) {
            triggers[i] = copy
        } else {
            triggers.append(copy)
        }
        persist()
    }

    func delete(id: String) {
        triggers.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
        persist()
    }

    private func persist() {
        var file = TriggerFile.empty()
        file.triggers = triggers
        do {
            try store.save(file)
        } catch {
            Logger.error("TriggerStore.save failed: \(error)")
        }
    }
}
