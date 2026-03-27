import SwiftUI

struct SubtitleTextView: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryStore: GlossaryStore
    let onTapWord: (String) -> Void

    var body: some View {
        let words = text.components(separatedBy: " ")

        WrappingHStack(words: words, glossaryStore: glossaryStore, fontSize: fontSize, textColor: textColor, onTapWord: onTapWord)
    }
}

struct WrappingHStack: View {
    let words: [String]
    let glossaryStore: GlossaryStore
    let fontSize: CGFloat
    let textColor: Color
    let onTapWord: (String) -> Void

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                wordView(word)
                    .padding(.vertical, 2)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if index == words.count - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == words.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { h in
            totalHeight = h
        }
    }

    private func wordView(_ word: String) -> some View {
        let isGlossary = glossaryStore.findMatch(for: word) != nil

        return Text(word + " ")
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(isGlossary ? .orange : textColor)
            .background(isGlossary ? Color.orange.opacity(0.15) : Color.clear)
            .cornerRadius(3)
            .onTapGesture {
            let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            onTapWord(cleaned)
            }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
