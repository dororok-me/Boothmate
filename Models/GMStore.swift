import Foundation
import SwiftUI
import Combine

@MainActor
final class GMStore: ObservableObject {

    // MARK: - Data Structure

    struct GMEntry: Identifiable, Codable {
        var id = UUID()
        var word: String        // 검색한 단어
        var addedAt: Date       // 검색 시간
    }

    @Published var entries: [GMEntry] = []

    private let saveKey = "gm_entries"
    private let maxEntries = 100  // 최대 100개 저장

    init() {
        load()
    }

    // MARK: - Add

    func add(word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 이미 있으면 맨 앞으로 이동
        if let existing = entries.firstIndex(where: { $0.word.lowercased() == trimmed.lowercased() }) {
            entries.remove(at: existing)
        }

        let entry = GMEntry(word: trimmed, addedAt: Date())
        entries.insert(entry, at: 0)

        // 최대 개수 초과 시 오래된 것 삭제
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    // MARK: - Delete

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func deleteAll() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GMEntry].self, from: data) {
            entries = decoded
        }
    }
}
