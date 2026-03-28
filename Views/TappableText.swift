import SwiftUI

struct TappableText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryColor: Color
    let onTapWord: (String) -> Void

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        label.addGestureRecognizer(tap)

        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = buildAttributedString()
        label.preferredMaxLayoutWidth = label.bounds.width > 0 ? label.bounds.width : UIScreen.main.bounds.width * 0.4
        context.coordinator.text = text
        context.coordinator.onTapWord = onTapWord
    }

    private func buildAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(textColor)
        ]
        let glossaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(glossaryColor)
        ]

        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c == "(" {
                // 괄호 시작 찾기
                if let closeIndex = text[i...].firstIndex(of: ")") {
                    let bracket = String(text[i...closeIndex])
                    result.append(NSAttributedString(string: bracket, attributes: glossaryAttrs))
                    i = text.index(after: closeIndex)
                } else {
                    result.append(NSAttributedString(string: String(c), attributes: baseAttrs))
                    i = text.index(after: i)
                }
            } else {
                result.append(NSAttributedString(string: String(c), attributes: baseAttrs))
                i = text.index(after: i)
            }
        }

        return result
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, onTapWord: onTapWord)
    }

    class Coordinator: NSObject {
        var text: String
        var onTapWord: (String) -> Void

        init(text: String, onTapWord: @escaping (String) -> Void) {
            self.text = text
            self.onTapWord = onTapWord
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let label = gesture.view as? UILabel else { return }
            let point = gesture.location(in: label)

            guard let attributedText = label.attributedText else { return }

            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            textContainer.lineBreakMode = label.lineBreakMode

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            let index = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

            guard index < text.count else { return }

            let nsText = text as NSString

            var wordStart = index
            var wordEnd = index

            while wordStart > 0 {
                let c = nsText.character(at: wordStart - 1)
                if CharacterSet.whitespaces.contains(Unicode.Scalar(c)!) { break }
                wordStart -= 1
            }

            while wordEnd < nsText.length {
                let c = nsText.character(at: wordEnd)
                if CharacterSet.whitespaces.contains(Unicode.Scalar(c)!) { break }
                wordEnd += 1
            }

            let word = nsText.substring(with: NSRange(location: wordStart, length: wordEnd - wordStart))
            let cleaned = word
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")

            if !cleaned.isEmpty {
                onTapWord(cleaned)
            }
        }
    }
}
