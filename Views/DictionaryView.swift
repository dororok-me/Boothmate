import SwiftUI

// MARK: - DictionaryView

struct DictionaryView: View {
    var hideTabs: Bool = false

    @State private var selectedDic: DicTab = .eng
    @State private var currentWord: String = ""
    @State private var meanings: [String] = []
    @State private var isLoading: Bool = false
    @State private var isRecording: Bool = false

    enum DicTab: String, CaseIterable {
        case eng = "English"
        case jp  = "Japanese"
        case ch  = "Chinese"

        var activeColor: Color {
            switch self {
            case .eng: return .blue
            case .jp:  return .black
            case .ch:  return .red
            }
        }

        var dicCode: String {
            switch self {
            case .eng: return "eng"
            case .jp:  return "jp"
            case .ch:  return "ch"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // 사전 탭 바 (hideTabs가 false일 때만 표시)
            if !hideTabs {
                HStack(spacing: 0) {
                    ForEach(DicTab.allCases, id: \.self) { tab in
                        Button {
                            selectedDic = tab
                            if !currentWord.isEmpty {
                                fetchMeaning(word: currentWord, tab: tab)
                            }
                            let boothLanguage: String
                            switch tab {
                            case .eng: boothLanguage = "en-US"
                            case .jp:  boothLanguage = "ja-JP"
                            case .ch:  boothLanguage = "zh-CN"
                            }
                            NotificationCenter.default.post(name: .dicTabChanged, object: boothLanguage)
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(selectedDic == tab ? tab.activeColor : Color.clear)
                                .foregroundColor(selectedDic == tab ? .white : .primary)
                        }
                        .disabled(isRecording)
                    }
                }
                .background(Color.gray.opacity(0.12))
                .opacity(isRecording ? 0.4 : 1.0)
            }

            // 사전 콘텐츠
            if currentWord.isEmpty {
                emptyView
            } else if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if meanings.isEmpty {
                Spacer()
                Text("검색 결과가 없습니다")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 검색어
                        Text(currentWord)
                            .font(.system(size: 28, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 12)

                        Divider()
                            .padding(.horizontal, 16)

                        // 뜻 목록 (1. 2. 3. ...)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(meanings.enumerated()), id: \.offset) { index, meaning in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24, alignment: .leading)
                                    Text(meaning)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchDictionary)) { notification in
            guard let word = notification.object as? String else { return }
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let boothLanguage = notification.userInfo?["language"] as? String ?? "en-US"
            currentWord = trimmed

            let isKorean = trimmed.unicodeScalars.contains(where: {
                $0.value >= 0xAC00 && $0.value <= 0xD7A3
            })
            let isJapanese = trimmed.unicodeScalars.contains(where: {
                ($0.value >= 0x3040 && $0.value <= 0x30FF) ||
                ($0.value >= 0x31F0 && $0.value <= 0x31FF)
            })
            let isChinese = trimmed.unicodeScalars.contains(where: {
                $0.value >= 0x4E00 && $0.value <= 0x9FFF
            })

            if isKorean {
                switch boothLanguage {
                case "ja-JP": selectedDic = .jp
                case "zh-CN": selectedDic = .ch
                default:      selectedDic = .eng
                }
            } else if isJapanese {
                selectedDic = .jp
            } else if isChinese && boothLanguage == "zh-CN" {
                selectedDic = .ch
            } else {
                switch boothLanguage {
                case "ja-JP": selectedDic = .jp
                case "zh-CN": selectedDic = .ch
                default:      selectedDic = .eng
                }
            }

            fetchMeaning(word: trimmed, tab: selectedDic)
        }
        .onReceive(NotificationCenter.default.publisher(for: .boothChanged)) { notification in
            guard let boothLanguage = notification.object as? String else { return }
            switch boothLanguage {
            case "ja-JP": selectedDic = .jp
            case "zh-CN": selectedDic = .ch
            default:      selectedDic = .eng
            }
            currentWord = ""
            meanings = []
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("recordingStateChanged"))) { notification in
            isRecording = notification.object as? Bool ?? false
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            DictionaryTabIcon(isSelected: false, iconSize: 88)
            Spacer()
        }
    }

    // MARK: - HTML 파싱으로 뜻만 가져오기

    private func fetchMeaning(word: String, tab: DicTab) {
        guard !word.isEmpty else { return }
        isLoading = true
        meanings = []

        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlStr = "https://dic.daum.net/search.do?q=\(encoded)&dic=\(tab.dicCode)"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("ko-KR,ko;q=0.9", forHTTPHeaderField: "Accept-Language")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ fetchMeaning error: \(error)")
                DispatchQueue.main.async { isLoading = false }
                return
            }
            if let http = response as? HTTPURLResponse {
                print("📡 HTTP status: \(http.statusCode), url: \(http.url?.absoluteString ?? "")")
            }
            guard let data = data else {
                print("❌ data is nil")
                DispatchQueue.main.async { isLoading = false }
                return
            }
            print("📦 data size: \(data.count) bytes")

            let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
                    ?? ""

            // txt_mean 개수 확인
            let txtMeanCount = html.components(separatedBy: "txt_mean").count - 1
            print("🔍 txt_mean count in html: \(txtMeanCount)")
            print("📄 HTML preview:\n\(html.prefix(3000))")

            let parsed = parseDefinitions(from: html)
            print("✅ parsed meanings: \(parsed)")

            DispatchQueue.main.async {
                meanings = parsed
                isLoading = false
            }
        }.resume()
    }

    private func parseDefinitions(from html: String) -> [String] {
        // og:description에 뜻이 바로 들어있음
        // <meta property="og:description" content="1.성능 2.성과 3.수행 4.공연 5.성적 "/>
        if let ogMatch = try? NSRegularExpression(pattern: "og:description\"[^>]*content=\"([^\"]+)\"")
            .matches(in: html, range: NSRange(html.startIndex..., in: html)).first,
           ogMatch.numberOfRanges > 1,
           let r = Range(ogMatch.range(at: 1), in: html) {

            let raw = String(html[r])  // "1.성능 2.성과 3.수행 4.공연 5.성적 "
            // "1.성능 2.성과" → ["성능", "성과", ...]
            let pattern = #"\d+\.([^\d]+)"#
            if let numRegex = try? NSRegularExpression(pattern: pattern) {
                let matches = numRegex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
                let results = matches.compactMap { m -> String? in
                    guard m.numberOfRanges > 1, let wr = Range(m.range(at: 1), in: raw) else { return nil }
                    return String(raw[wr]).trimmingCharacters(in: .whitespaces)
                }.filter { !$0.isEmpty }

                if !results.isEmpty {
                    print("✅ og:description parsed: \(results)")
                    return results
                }
            }
        }

        // fallback: txt_mean 방식 (PC 버전 HTML인 경우)
        guard let blockRegex = try? NSRegularExpression(
            pattern: "class=\"txt_mean\"[^>]*>(.+?)</span>",
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let nsHtml = html as NSString
        let range = NSRange(location: 0, length: nsHtml.length)
        let blockMatches = blockRegex.matches(in: html, range: range)
        var results: [String] = []

        for match in blockMatches {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let block = String(html[r])

            guard let wordRegex = try? NSRegularExpression(
                pattern: "<daum:word[^>]*>([^<]+)</daum:word>", options: []
            ) else { continue }

            let nsBlock = block as NSString
            let wordMatches = wordRegex.matches(in: block, range: NSRange(location: 0, length: nsBlock.length))

            if !wordMatches.isEmpty {
                let words = wordMatches.compactMap { m -> String? in
                    guard m.numberOfRanges > 1, let wr = Range(m.range(at: 1), in: block) else { return nil }
                    return String(block[wr])
                }
                let joined = cleanText(words.joined(separator: " "))
                if !joined.isEmpty && !isNoise(joined) { results.append(joined) }
            } else {
                let plain = cleanText(stripTags(block))
                if !plain.isEmpty && !isNoise(plain) { results.append(plain) }
            }
            if results.count >= 8 { break }
        }
        return results
    }

    private func regexMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> String? in
            let r = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard let swiftRange = Range(r, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private func stripTags(_ html: String) -> String {
        (try? NSRegularExpression(pattern: "<[^>]+>"))
            .flatMap { regex -> String? in
                let range = NSRange(html.startIndex..., in: html)
                return regex.stringByReplacingMatches(in: html, range: range, withTemplate: " ")
            } ?? html
    }

    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isNoise(_ text: String) -> Bool {
        let noiseWords = ["더보기", "검색", "닫기", "이전", "다음", "English", "Japanese", "Chinese",
                          "로그인", "회원가입", "광고", "Cookie", "Privacy", "Terms"]
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count < 2 { return true }
        for n in noiseWords where t.contains(n) { return true }
        if t.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isSymbol || $0.isWhitespace }) { return true }
        return false
    }
}
