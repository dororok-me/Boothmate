import SwiftUI

struct TappableText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let glossaryColor: Color
    let lineSpacing: CGFloat
    let glossaryStore: GlossaryStore
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
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]

        let glossaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor(glossaryColor),
            .paragraphStyle: paragraphStyle
        ]

        // 1. 기존 중복 괄호 제거
        var cleanedText = text
        let bracketPattern = "\\s?\\([가-힣A-Za-z\\s\\.,?!]+\\)"
        if let regex = try? NSRegularExpression(pattern: bracketPattern) {
            cleanedText = regex.stringByReplacingMatches(in: cleanedText, range: NSRange(cleanedText.startIndex..., in: cleanedText), withTemplate: "")
        }

        var workingText = cleanedText
        var replacements: [String: (display: String, translation: String)] = [:    ]
        
        // 2. 양방향 매칭 준비 (긴 단어 우선)
        var allPairs: [(String, String)] = []
        for entry in glossaryStore.entries {
            allPairs.append((entry.source, entry.target))
            allPairs.append((entry.target, entry.source))
        }
        let sortedPairs = allPairs.sorted { $0.0.count > $1.0.count }

        for (index, pair) in sortedPairs.enumerated() {
            // 모든 공백을 제거하고 글자 사이에 \s?를 넣어 띄어쓰기 무시
            let strippedSource = pair.0.replacingOccurrences(of: " ", with: "")
            let flexiblePattern = strippedSource.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s?")
            
            // [수정 포인트] 뒤쪽에 한글 조사([가-힣])가 와도 매칭이 되도록 후방 탐색 조건을 제거하거나 완화합니다.
            // 영문자나 숫자가 뒤에 붙는 것만 방지합니다.
            let pattern = "(?<![A-Za-z0-9가-힣])\(flexiblePattern)(?![A-Za-z0-9])"
            
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            
            let placeholder = "__GLO_\(index)__"
            let range = NSRange(workingText.startIndex..., in: workingText)
            
            // 문장에서 실제로 발견된 텍스트 형태 추출
            if let match = regex.firstMatch(in: workingText, range: range) {
                let originalInText = (workingText as NSString).substring(with: match.range)
                
                // 플레이스홀더로 치환
                workingText = regex.stringByReplacingMatches(in: workingText, range: range, withTemplate: placeholder)
                replacements[placeholder] = (originalInText, pair.1)
            }
        }

        // 3. 최종 조립
        let finalResult = NSMutableAttributedString()
        let finalRegex = try! NSRegularExpression(pattern: "__GLO_\\d+__")
        let nsWorkingText = workingText as NSString
        var lastIndex = 0

        finalRegex.enumerateMatches(in: workingText, range: NSRange(location: 0, length: nsWorkingText.length)) { match, _, _ in
            if let matchRange = match?.range {
                let preRange = NSRange(location: lastIndex, length: matchRange.location - lastIndex)
                if preRange.length > 0 {
                    finalResult.append(NSAttributedString(string: nsWorkingText.substring(with: preRange), attributes: baseAttrs))
                }
                
                let placeholder = nsWorkingText.substring(with: matchRange)
                if let data = replacements[placeholder] {
                    let coloredWord = NSMutableAttributedString(string: data.display, attributes: glossaryAttrs)
                    let translation = NSAttributedString(string: "(\(data.translation))", attributes: glossaryAttrs)
                    coloredWord.append(translation)
                    finalResult.append(coloredWord)
                }
                lastIndex = matchRange.location + matchRange.length
            }
        }
        
        if lastIndex < nsWorkingText.length {
            finalResult.append(NSAttributedString(string: nsWorkingText.substring(from: lastIndex), attributes: baseAttrs))
        }

        return finalResult
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
            guard let label = gesture.view as? UILabel, let attributedText = label.attributedText else { return }
            let point = gesture.location(in: label)
            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            textContainer.lineBreakMode = label.lineBreakMode

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            let index = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
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
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                             .replacingOccurrences(of: "(", with: "")
                             .replacingOccurrences(of: ")", with: "")

            if !cleaned.isEmpty {
                onTapWord(cleaned)
            }
        }
    }
}
