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
        let cleanSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanSource.isEmpty, !cleanTarget.isEmpty else { return }

        let entry = GlossaryEntry(source: cleanSource, target: cleanTarget)
        entries.append(entry)
        save()
    }

    func update(id: UUID, source: String, target: String) {
        let cleanSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanSource.isEmpty, !cleanTarget.isEmpty else { return }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }

        entries[index].source = cleanSource
        entries[index].target = cleanTarget
        save()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
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
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = decoded
        }
    }

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

                guard !source.isEmpty, !target.isEmpty else { continue }

                let alreadyExists = entries.contains {
                    normalizeForCompare($0.source) == normalizeForCompare(source) &&
                    normalizeForCompare($0.target) == normalizeForCompare(target)
                }

                if !alreadyExists {
                    entries.append(GlossaryEntry(source: source, target: target))
                }
            }
        }

        save()
    }

    // 단어 탭 시 매칭
    func findMatch(for word: String) -> GlossaryEntry? {
        let normalized = normalizeForCompare(word)

        return entries.first(where: {
            normalizeForCompare($0.source) == normalized ||
            normalizeForCompare($0.target) == normalized
        })
    }

    // 자막 표시용
    // 영어 문장이면 영어(한글), 한국어 문장이면 한국어(영어)
    // 단어 내부 오염 방지용으로 토큰 단위 처리
    func applyGlossary(to text: String) -> String {
        let tokens = tokenize(text)

        return tokens.map { token in
            guard let match = findMatch(for: token) else {
                return token
            }

            if isEnglish(token) {
                return "\(match.source)(\(match.target))"
            } else if isKorean(token) {
                return "\(match.target)(\(match.source))"
            } else {
                return token
            }
        }
        .joined()
    }

    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in text {
            if char.isLetter || char.isNumber {
                current.append(char)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func isEnglish(_ text: String) -> Bool {
        text.range(of: "[A-Za-z]", options: .regularExpression) != nil
    }

    private func isKorean(_ text: String) -> Bool {
        text.range(of: "[가-힣]", options: .regularExpression) != nil
    }

    private func normalizeForCompare(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
