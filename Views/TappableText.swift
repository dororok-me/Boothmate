import SwiftUI
import UIKit

struct TappableText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryColor: Color
    let lineSpacing: CGFloat
    let glossaryEnabled: Bool
    let fontBold: Bool
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
        if !context.coordinator.isHighlighting {
            label.attributedText = buildAttributedString()
        }
        if label.bounds.width > 0 {
            label.preferredMaxLayoutWidth = label.bounds.width
        }
        context.coordinator.onTapWord = onTapWord
    }

    // MARK: - Attributed String
    //
    // 괄호 색깔 규칙:
    // 1. 글로서리: SpeechManager가 〔...〕마커로 감싸줌 → 마커 안 전체 glossaryColor, 마커는 숨김
    //    - "〔artificial intelligence(인공 지능)〕" → 전체 주황색, 〔〕는 안 보임
    // 2. 환산: 숫자+단위(변환) → 괄호 안만 glossaryColor
    //    - "7 feet(2.1m)" → feet 기본색, (2.1m) 주황색

    private func buildAttributedString() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let weight: UIFont.Weight = fontBold ? .bold : .regular
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]

        let glossaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: UIColor(glossaryColor),
            .paragraphStyle: paragraphStyle
        ]

        // 마커 숨김용 (폰트 크기 0, 투명)
        let hiddenAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 0.001),
            .foregroundColor: UIColor.clear,
            .paragraphStyle: paragraphStyle
        ]

        guard glossaryEnabled else {
            // 글로서리 비활성화 시에도 마커는 제거
            let cleaned = text.replacingOccurrences(of: "〔", with: "").replacingOccurrences(of: "〕", with: "")
            return NSAttributedString(string: cleaned, attributes: baseAttrs)
        }

        let result = NSMutableAttributedString(string: text, attributes: baseAttrs)
        let nsText = text as NSString

        // 1단계: 〔〕마커 처리 (글로서리 - 전체 색칠, 마커 숨김)
        if let markerRegex = try? NSRegularExpression(pattern: "〔([^〕]+)〕", options: []) {
            let matches = markerRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                // 전체 범위 glossaryColor
                result.addAttributes(glossaryAttrs, range: match.range)
                // 〔 숨기기 (첫 글자)
                result.addAttributes(hiddenAttrs, range: NSRange(location: match.range.location, length: 1))
                // 〕 숨기기 (마지막 글자)
                result.addAttributes(hiddenAttrs, range: NSRange(location: match.range.location + match.range.length - 1, length: 1))
            }
        }

        // 2단계: 환산 패턴 처리 (괄호 안만 색칠)
        // 마커 없는 것 중에서 숫자/통화 앞에 있는 괄호만
        guard let conversionRegex = try? NSRegularExpression(
            pattern: "\\S+\\([^)]+\\)",
            options: []
        ) else { return result }

        let matches = conversionRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let matchedStr = nsText.substring(with: match.range)

            // 마커 안에 있는 것은 이미 처리됨 → 스킵
            if matchedStr.contains("〔") || matchedStr.contains("〕") { continue }

            guard let parenOpenIndex = matchedStr.firstIndex(of: "(") else { continue }
            let prefix = String(matchedStr[matchedStr.startIndex..<parenOpenIndex])

            // 환산 판별: 괄호 앞 또는 괄호 안 내용으로 판별
            let hasDigit = prefix.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) })
            let hasCurrency = prefix.unicodeScalars.contains(where: {
                CharacterSet(charactersIn: "$₩¥€£").contains($0)
            })
            let insideParen = String(matchedStr[parenOpenIndex...].dropFirst().prefix(while: { $0 != ")" }))
            let insideHasCurrency = insideParen.unicodeScalars.contains(where: {
                CharacterSet(charactersIn: "$₩¥€£").contains($0)
            })
            let insideFirstIsDigit = insideParen.first?.isNumber == true

            if hasDigit || hasCurrency || insideHasCurrency || insideFirstIsDigit {
                // 환산: 괄호 안만 색칠
                let parenOffset = matchedStr.distance(from: matchedStr.startIndex, to: parenOpenIndex)
                let parenRange = NSRange(
                    location: match.range.location + parenOffset,
                    length: match.range.length - parenOffset
                )
                result.addAttributes(glossaryAttrs, range: parenRange)
            }
            // 환산 아닌 것(마커 없는 글로서리)은 색칠 안 함 - SpeechManager가 마커 안 붙인 건 매칭 안 된 것
        }

        return result
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapWord: onTapWord)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var onTapWord: (String) -> Void
        var isHighlighting: Bool = false

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
                .replacingOccurrences(of: "〔", with: "")
                .replacingOccurrences(of: "〕", with: "")
                .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                let highlightRange = NSRange(location: wordStart, length: wordEnd - wordStart)
                let highlighted = NSMutableAttributedString(attributedString: attributedText)
                highlighted.addAttribute(
                    .backgroundColor,
                    value: UIColor.systemYellow.withAlphaComponent(0.5),
                    range: highlightRange
                )
                self.isHighlighting = true
                label.attributedText = highlighted

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isHighlighting = false
                    label.attributedText = attributedText
                }

                onTapWord(cleaned)
            }
        }
    }
}
