import SwiftUI
import UIKit

struct TappableText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryColor: Color
    let lineSpacing: CGFloat
    let glossaryEnabled: Bool
    let onTapWord: (String) -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        label.addGestureRecognizer(tap)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = buildAttributedString()
        if label.bounds.width > 0 {
            label.preferredMaxLayoutWidth = label.bounds.width
        }
        context.coordinator.onTapWord = onTapWord
    }

    // MARK: - Attributed String
    //
    // 괄호 색깔 규칙:
    // 1. 환산: 숫자+단위(변환) → 괄호 안만 glossaryColor, 앞 단위는 기본색
    //    - "7 feet(2.1m)" → feet 기본색, (2.1m) glossaryColor
    //    - "$20,000(₩약 3,021만원)" → $20,000 기본색, (₩약...) glossaryColor
    //    - "10,000,000 km(6,213,727miles)" → km 기본색, (...) glossaryColor
    // 2. 글로서리: 단어(번역) → 전체 glossaryColor

    private func buildAttributedString() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]

        let result = NSMutableAttributedString(string: text, attributes: baseAttrs)
        let nsText = text as NSString

        guard glossaryEnabled else { return result }

        let glossaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(glossaryColor),
            .paragraphStyle: paragraphStyle
        ]

        // 환산 패턴: 괄호 앞에 숫자가 있는 경우 (공백 허용)
        // 예: "$20,000(₩약...)", "7 feet(2.1m)", "10,000,000 km(6,213,727miles)"
        // 매칭: [숫자/통화/콤마/소수점][공백?][단위?](괄호내용)
        guard let conversionRegex = try? NSRegularExpression(
            pattern: "(?:[\\d,.]+[\\s]?[A-Za-z°]*|[$₩¥€£][\\d,.]+)\\([^)]+\\)",
            options: []
        ) else { return result }

        // 글로서리 패턴: 비숫자 단어(괄호내용)
        guard let allParenRegex = try? NSRegularExpression(
            pattern: "\\S+\\([^)]+\\)",
            options: []
        ) else { return result }

        // 1단계: 환산 괄호 처리 (괄호 안만 색칠)
        let conversionMatches = conversionRegex.matches(
            in: text, range: NSRange(location: 0, length: nsText.length)
        )
        var conversionRanges = Set<Int>() // 환산으로 처리된 위치 기록

        for match in conversionMatches {
            let matchedStr = nsText.substring(with: match.range)
            if let parenStart = matchedStr.firstIndex(of: "(") {
                let parenOffset = matchedStr.distance(from: matchedStr.startIndex, to: parenStart)
                let parenRange = NSRange(
                    location: match.range.location + parenOffset,
                    length: match.range.length - parenOffset
                )
                result.addAttributes(glossaryAttrs, range: parenRange)

                // 이 범위는 환산으로 처리됨
                for i in match.range.location..<(match.range.location + match.range.length) {
                    conversionRanges.insert(i)
                }
            }
        }

        // 2단계: 글로서리 괄호 처리 (환산이 아닌 것만 전체 색칠)
        let allMatches = allParenRegex.matches(
            in: text, range: NSRange(location: 0, length: nsText.length)
        )

        for match in allMatches {
            // 이미 환산으로 처리된 범위면 스킵
            if conversionRanges.contains(match.range.location) { continue }

            result.addAttributes(glossaryAttrs, range: match.range)
        }

        return result
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapWord: onTapWord)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var onTapWord: (String) -> Void

        init(onTapWord: @escaping (String) -> Void) {
            self.onTapWord = onTapWord
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let label = gesture.view as? UILabel,
                  let attributedText = label.attributedText else { return }

            let point = gesture.location(in: label)

            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)

            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            textContainer.lineBreakMode = label.lineBreakMode

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            let index = layoutManager.characterIndex(
                for: point,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            guard index < attributedText.length else { return }

            let nsText = attributedText.string as NSString
            var wordStart = index
            var wordEnd = index

            while wordStart > 0 {
                let c = nsText.character(at: wordStart - 1)
                if CharacterSet.whitespacesAndNewlines.contains(Unicode.Scalar(c)!) { break }
                wordStart -= 1
            }
            while wordEnd < nsText.length {
                let c = nsText.character(at: wordEnd)
                if CharacterSet.whitespacesAndNewlines.contains(Unicode.Scalar(c)!) { break }
                wordEnd += 1
            }

            let word = nsText.substring(with: NSRange(location: wordStart, length: wordEnd - wordStart))
            let cleaned = word
                .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                let highlightRange = NSRange(location: wordStart, length: wordEnd - wordStart)
                let highlighted = NSMutableAttributedString(attributedString: attributedText)
                highlighted.addAttribute(
                    .backgroundColor,
                    value: UIColor.systemYellow.withAlphaComponent(0.4),
                    range: highlightRange
                )
                label.attributedText = highlighted

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    label.attributedText = attributedText
                }

                onTapWord(cleaned)
            }
        }
    }
}
