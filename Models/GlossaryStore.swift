import Foundation
import SwiftUI
import Combine

@MainActor
class GlossaryStore: ObservableObject {
    // MARK: - Data Structure
    struct GlossaryEntry: Identifiable, Codable, Equatable {
        var id = UUID()
        var source: String           // 대표 원문 (예: Artificial Intelligence)
        var target: String           // 번역어 (예: 인공지능)
        var synonyms: [String] = []  // 유의어 리스트 (예: ["AI", "A.I."])
        
        // 매칭을 위해 검색해야 할 모든 단어 리스트 (원문 + 유의어)
        var allSearchTerms: [String] {
            var terms = [source]
            terms.append(contentsOf: synonyms)
            return terms.filter { !$0.isEmpty }
        }
    }

    @Published var entries: [GlossaryEntry] = []

    private let saveKey = "glossary_entries"
    
    // 유의어까지 포함하여 빠르게 검색하기 위한 캐시
    private var sourceCache: Set<String> = []
    private var targetCache: Set<String> = []

    init() {
        load()
    }

    // MARK: - CRUD Operations
    func add(source: String, target: String, synonyms: [String] = []) {
        // 이미 존재하는 원문인지 체크 (유의어 포함)
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let entry = GlossaryEntry(source: source, target: target, synonyms: synonyms)
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

    // MARK: - Persistence & Cache
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
        // 원문뿐만 아니라 유의어(synonyms)도 검색 캐시에 포함시킵니다.
        var sources = Set<String>()
        for entry in entries {
            sources.insert(entry.source.lowercased())
            for syn in entry.synonyms {
                sources.insert(syn.lowercased())
            }
        }
        sourceCache = sources
        targetCache = Set(entries.map { $0.target.lowercased() })
    }

    // MARK: - Search Logic
    func hasSource(_ word: String) -> Bool {
        sourceCache.contains(word.lowercased())
    }

    func hasTarget(_ word: String) -> Bool {
        targetCache.contains(word.lowercased())
    }

    func findMatch(for word: String) -> GlossaryEntry? {
        let lower = word.lowercased().trimmingCharacters(in: .whitespaces)
        return entries.first(where: {
            $0.source.lowercased() == lower ||
            $0.target.lowercased() == lower ||
            $0.synonyms.contains(where: { $0.lowercased() == lower })
        })
    }

    // MARK: - CSV Import (유의어 대응)
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

            // CSV 형식 가정: 원문,번역어,유의어1,유의어2...
            let cols = trimmed.components(separatedBy: ",")
            if cols.count >= 2 {
                let source = cols[0].trimmingCharacters(in: .whitespaces)
                let target = cols[1].trimmingCharacters(in: .whitespaces)
                
                var synonyms: [String] = []
                if cols.count > 2 {
                    // 3번째 열부터는 모두 유의어로 처리
                    synonyms = cols[2...].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }

                if !source.isEmpty {
                    // 중복 원문이 없을 때만 추가
                    if !entries.contains(where: { $0.source == source }) {
                        entries.append(GlossaryEntry(source: source, target: target, synonyms: synonyms))
                    }
                }
            }
        }
        save()
    }
}
