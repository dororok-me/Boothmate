import SwiftUI

struct SubtitleTextView: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryStore: GlossaryStore
    let onTapWord: (String) -> Void

    private struct DisplayPiece: Identifiable {
        let id = UUID()
        let text: String
        let tapValue: String?
        let isGlossary: Bool
    }

    private var rawTokens: [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private var pieces: [DisplayPiece] {
        buildPieces(from: rawTokens)
    }

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(pieces) { piece in
                pieceView(piece)
            }
        }
    }

    private func pieceView(_ piece: DisplayPiece) -> some View {
        Text(piece.text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(piece.isGlossary ? .orange : textColor)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(piece.isGlossary ? Color.orange.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let tapValue = piece.tapValue, !tapValue.isEmpty else { return }
                onTapWord(tapValue)
            }
    }

    private func buildPieces(from tokens: [String]) -> [DisplayPiece] {
        guard !tokens.isEmpty else { return [] }

        var result: [DisplayPiece] = []
        var index = 0

        while index < tokens.count {
            if let phraseMatch = longestPhraseMatch(in: tokens, start: index) {
                result.append(phraseMatch.piece)
                index += phraseMatch.length
                continue
            }

            let token = tokens[index]
            let cleaned = cleanedWord(from: token)

            if let entry = glossaryStore.findMatch(for: cleaned) {
                result.append(singleTokenGlossaryPiece(token: token, entry: entry))
            } else if let koreanPiece = koreanSuffixGlossaryPiece(token: token) {
                result.append(koreanPiece)
            } else {
                result.append(
                    DisplayPiece(
                        text: token,
                        tapValue: cleaned.isEmpty ? nil : cleaned,
                        isGlossary: false
                    )
                )
            }

            index += 1
        }

        return result
    }

    private func singleTokenGlossaryPiece(token: String, entry: GlossaryStore.GlossaryEntry) -> DisplayPiece {
        let cleaned = cleanedWord(from: token)
        let punctuation = trailingPunctuation(from: token)

        if matches(cleaned, with: entry.source) {
            return DisplayPiece(
                text: "\(cleaned)(\(entry.target))\(punctuation)",
                tapValue: entry.source,
                isGlossary: true
            )
        }

        return DisplayPiece(
            text: "\(cleaned)(\(entry.source))\(punctuation)",
            tapValue: entry.target,
            isGlossary: true
        )
    }

    private func koreanSuffixGlossaryPiece(token: String) -> DisplayPiece? {
        let cleaned = cleanedWord(from: token)
        let punctuation = trailingPunctuation(from: token)

        guard isKorean(cleaned) else { return nil }

        for entry in glossaryStore.entries {
            let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { continue }
            guard !target.contains(" ") else { continue }
            guard cleaned.hasPrefix(target) else { continue }
            guard cleaned != target else { continue }

            let suffix = String(cleaned.dropFirst(target.count))
            guard !suffix.isEmpty else { continue }

            return DisplayPiece(
                text: "\(target)(\(entry.source))\(suffix)\(punctuation)",
                tapValue: target,
                isGlossary: true
            )
        }

        return nil
    }

    private func longestPhraseMatch(in tokens: [String], start: Int) -> (piece: DisplayPiece, length: Int)? {
        let sortedEntries = glossaryStore.entries.sorted {
            max(wordCount(of: $0.source), wordCount(of: $0.target)) >
            max(wordCount(of: $1.source), wordCount(of: $1.target))
        }

        for entry in sortedEntries {
            let sourceWords = splitTermWords(entry.source)
            let targetWords = splitTermWords(entry.target)

            if sourceWords.count > 1,
               start + sourceWords.count <= tokens.count,
               tokensMatch(tokens, start: start, words: sourceWords) {
                let phraseTokens = Array(tokens[start..<(start + sourceWords.count)])
                let phraseText = joinedCleanedPhrase(from: phraseTokens)
                let punctuation = trailingPunctuation(from: phraseTokens.last ?? "")

                return (
                    DisplayPiece(
                        text: "\(phraseText)(\(entry.target))\(punctuation)",
                        tapValue: entry.source,
                        isGlossary: true
                    ),
                    sourceWords.count
                )
            }

            if targetWords.count > 1,
               start + targetWords.count <= tokens.count,
               tokensMatch(tokens, start: start, words: targetWords) {
                let phraseTokens = Array(tokens[start..<(start + targetWords.count)])
                let phraseText = joinedCleanedPhrase(from: phraseTokens)
                let punctuation = trailingPunctuation(from: phraseTokens.last ?? "")

                return (
                    DisplayPiece(
                        text: "\(phraseText)(\(entry.source))\(punctuation)",
                        tapValue: entry.target,
                        isGlossary: true
                    ),
                    targetWords.count
                )
            }
        }

        return nil
    }

    private func tokensMatch(_ tokens: [String], start: Int, words: [String]) -> Bool {
        guard start + words.count <= tokens.count else { return false }

        for offset in 0..<words.count {
            let token = cleanedWord(from: tokens[start + offset])
            let word = words[offset]

            if !matches(token, with: word) {
                return false
            }
        }

        return true
    }

    private func joinedCleanedPhrase(from tokens: [String]) -> String {
        tokens.map { cleanedWord(from: $0) }.joined(separator: " ")
    }

    private func splitTermWords(_ term: String) -> [String] {
        term
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private func wordCount(of term: String) -> Int {
        splitTermWords(term).count
    }

    private func cleanedWord(from word: String) -> String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
    }

    private func trailingPunctuation(from word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.trimmingCharacters(in: .punctuationCharacters)

        guard trimmed.count >= cleaned.count else { return "" }

        let suffixCount = trimmed.count - cleaned.count
        guard suffixCount > 0 else { return "" }

        return String(trimmed.suffix(suffixCount))
    }

    private func matches(_ lhs: String, with rhs: String) -> Bool {
        normalize(lhs) == normalize(rhs)
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isKorean(_ text: String) -> Bool {
        text.range(of: "[가-힣]", options: .regularExpression) != nil
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0
        guard maxWidth > 0 else {
            let totalWidth = subviews.reduce(CGFloat.zero) { partial, subview in
                partial + subview.sizeThatFits(.unspecified).width + spacing
            }
            let maxHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return CGSize(width: totalWidth, height: maxHeight)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
