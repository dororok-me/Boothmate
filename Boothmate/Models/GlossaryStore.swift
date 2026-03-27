import Foundation
import SwiftUI
import Combine

@MainActor
class GlossaryStore: ObservableObject {
    @Published var entries: [GlossaryEntry] = []

    struct GlossaryEntry: Identifiable, Codable {
        var id = UUID()
        var source: String
        var target: String
    }

    private let saveKey = "glossary_entries"

    init() {
        load()
    }

    func add(source: String, target: String) {
        let entry = GlossaryEntry(source: source, target: target)
        entries.append(entry)
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func deleteAll() {
        entries.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = decoded
        }
    }
}
