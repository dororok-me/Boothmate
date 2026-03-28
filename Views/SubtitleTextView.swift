import SwiftUI

struct SubtitleTextView: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryStore: GlossaryStore
    let onTapWord: (String) -> Void

    private var words: [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                wordView(word)
            }
        }
    }

    private func wordView(_ word: String) -> some View {
            let cleaned = word
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)

            // 양방향: source 또는 target 모두 하이라이트
            let isSource = glossaryStore.hasSource(cleaned)
            let isTarget = glossaryStore.hasTarget(cleaned)
            let isGlossary = isSource || isTarget

            return Text(word)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(isGlossary ? .orange : textColor)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(isGlossary ? Color.orange.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !cleaned.isEmpty else { return }
                onTapWord(cleaned)
            }
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
