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

    // 빠른 검색을 위한 캐시
    private var sourceCache: Set<String> = []
    private var targetCache: Set<String> = []

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

    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
        rebuildCache()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = decoded
        }
        rebuildCache()
    }

    private func rebuildCache() {
        sourceCache = Set(entries.map { $0.source.lowercased() })
        targetCache = Set(entries.map { $0.target.lowercased() })
    }

    // source 캐시에서 빠른 검색
    func hasSource(_ word: String) -> Bool {
        sourceCache.contains(word.lowercased())
    }

    // target 캐시에서 빠른 검색
    func hasTarget(_ word: String) -> Bool {
        targetCache.contains(word.lowercased())
    }

    // 단어가 글로서리에 있는지 확인 (source 또는 target)
    func findMatch(for word: String) -> GlossaryEntry? {
        let lower = word.lowercased()
        return entries.first(where: {
            $0.source.lowercased() == lower || $0.target.lowercased() == lower
        })
    }

    // CSV 가져오기
    func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.lowercased().starts(with: "source") { continue }

            let cols = trimmed.components(separatedBy: ",")
            if cols.count >= 2 {
                let source = cols[0].trimmingCharacters(in: .whitespaces)
                let target = cols[1].trimmingCharacters(in: .whitespaces)
                if !source.isEmpty {
                    if !entries.contains(where: { $0.source == source }) {
                        entries.append(GlossaryEntry(source: source, target: target))
                    }
                }
            }
        }
        save()
    }
}
