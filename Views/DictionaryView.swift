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
                            .font(.system(size: 24, weight: .medium))
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

        // ★ PC 버전 요청 (모바일보다 파싱 가능한 태그가 더 많음)
        let urlStr = "https://dic.daum.net/search.do?q=\(encoded)&dic=\(tab.dicCode)"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        // PC User-Agent로 변경 → txt_mean, txt_search 등 클래스가 있는 HTML 수신
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
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

            print("📄 HTML preview:\n\(html.prefix(3000))")

            let parsed = parseDefinitions(from: html)
            print("✅ parsed meanings: \(parsed)")

            DispatchQueue.main.async {
                meanings = parsed
                isLoading = false
            }
        }.resume()
    }

    // MARK: - 다단계 파싱 (여러 fallback 전략)

    private func parseDefinitions(from html: String) -> [String] {

        // ── 1단계: og:description ──
        // <meta property="og:description" content="1.성능 2.성과 3.수행 4.공연 5.성적 "/>
        if let results = parseOgDescription(from: html), !results.isEmpty {
            print("✅ [1] og:description parsed: \(results)")
            return results
        }

        // ── 2단계: txt_mean (PC 버전 메인 패턴) ──
        let txtMeanResults = parseTxtMean(from: html)
        if !txtMeanResults.isEmpty {
            print("✅ [2] txt_mean parsed: \(txtMeanResults)")
            return txtMeanResults
        }

        // ── 3단계: list_search 안의 txt_search (검색 결과 목록) ──
        let txtSearchResults = parseTxtSearch(from: html)
        if !txtSearchResults.isEmpty {
            print("✅ [3] txt_search parsed: \(txtSearchResults)")
            return txtSearchResults
        }

        // ── 4단계: daum:word 태그 직접 추출 ──
        let daumWordResults = parseDaumWord(from: html)
        if !daumWordResults.isEmpty {
            print("✅ [4] daum:word parsed: \(daumWordResults)")
            return daumWordResults
        }

        // ── 5단계: span.txt_emean1 (영한사전 뜻 클래스) ──
        let emeanResults = parseEmean(from: html)
        if !emeanResults.isEmpty {
            print("✅ [5] txt_emean parsed: \(emeanResults)")
            return emeanResults
        }

        // ── 6단계: desc_item 등 범용 뜻 블록 ──
        let descResults = parseDescItem(from: html)
        if !descResults.isEmpty {
            print("✅ [6] desc_item parsed: \(descResults)")
            return descResults
        }

        print("❌ 모든 파싱 전략 실패")
        return []
    }

    // MARK: 파싱 전략 1: og:description

    private func parseOgDescription(from html: String) -> [String]? {
        guard let ogRegex = try? NSRegularExpression(
            pattern: #"og:description"[^>]*content="([^"]+)""#
        ) else { return nil }

        let range = NSRange(html.startIndex..., in: html)
        guard let match = ogRegex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: html) else { return nil }

        let raw = String(html[r])

        // "1.성능 2.성과" 형태
        if let numRegex = try? NSRegularExpression(pattern: #"\d+\.([^\d]+)"#) {
            let numRange = NSRange(raw.startIndex..., in: raw)
            let matches = numRegex.matches(in: raw, range: numRange)
            let results = matches.compactMap { m -> String? in
                guard m.numberOfRanges > 1, let wr = Range(m.range(at: 1), in: raw) else { return nil }
                return cleanText(String(raw[wr]))
            }.filter { !$0.isEmpty }
            if !results.isEmpty { return results }
        }

        // 번호 없이 쉼표/세미콜론으로 구분된 경우: "성능, 성과, 수행"
        let commaItems = raw.components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { cleanText($0) }
            .filter { !$0.isEmpty && $0.count >= 1 }
        if !commaItems.isEmpty && commaItems.count <= 20 {
            return commaItems
        }

        // 단일 뜻인 경우
        let single = cleanText(raw)
        if !single.isEmpty && single.count >= 2 {
            return [single]
        }

        return nil
    }

    // MARK: 파싱 전략 2: txt_mean

    private func parseTxtMean(from html: String) -> [String] {
        guard let blockRegex = try? NSRegularExpression(
            pattern: #"class="txt_mean"[^>]*>(.+?)</span>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        let blockMatches = blockRegex.matches(in: html, range: range)
        var results: [String] = []

        for match in blockMatches {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let block = String(html[r])

            // daum:word 태그가 있으면 그 안의 텍스트를 합침
            if let wordRegex = try? NSRegularExpression(
                pattern: #"<daum:word[^>]*>([^<]+)</daum:word>"#
            ) {
                let nsBlock = block as NSString
                let wordMatches = wordRegex.matches(in: block, range: NSRange(location: 0, length: nsBlock.length))

                if !wordMatches.isEmpty {
                    let words = wordMatches.compactMap { m -> String? in
                        guard m.numberOfRanges > 1, let wr = Range(m.range(at: 1), in: block) else { return nil }
                        return String(block[wr])
                    }
                    let joined = cleanText(words.joined(separator: " "))
                    if !joined.isEmpty && !isNoise(joined) { results.append(joined) }
                    if results.count >= 8 { break }
                    continue
                }
            }

            // daum:word 없으면 태그 제거 후 텍스트 추출
            let plain = cleanText(stripTags(block))
            if !plain.isEmpty && !isNoise(plain) { results.append(plain) }
            if results.count >= 8 { break }
        }
        return results
    }

    // MARK: 파싱 전략 3: txt_search (검색 결과 리스트)

    private func parseTxtSearch(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"class="txt_search"[^>]*>(.+?)</(?:span|a)>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var results: [String] = []

        for match in matches {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = cleanText(stripTags(String(html[r])))
            if !raw.isEmpty && !isNoise(raw) && raw.count >= 2 {
                results.append(raw)
            }
            if results.count >= 8 { break }
        }
        return results
    }

    // MARK: 파싱 전략 4: daum:word 태그 직접 추출

    private func parseDaumWord(from html: String) -> [String] {
        // 뜻 영역(txt_mean 또는 desc_item) 안에서 daum:word 추출
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:txt_mean|desc_item|mean_info)[^>]*>.*?<daum:word[^>]*>([^<]+)</daum:word>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var results: [String] = []
        var seen = Set<String>()

        for match in matches {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let word = cleanText(String(html[r]))
            if !word.isEmpty && !isNoise(word) && !seen.contains(word) {
                seen.insert(word)
                results.append(word)
            }
            if results.count >= 8 { break }
        }
        return results
    }

    // MARK: 파싱 전략 5: txt_emean1 (영한사전 전용)

    private func parseEmean(from html: String) -> [String] {
        // txt_emean1, txt_emean2, ... 등 영한사전 뜻 클래스
        guard let regex = try? NSRegularExpression(
            pattern: #"class="txt_emean\d?"[^>]*>(.+?)</(?:span|dd)>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var results: [String] = []

        for match in matches {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = cleanText(stripTags(String(html[r])))
            if !raw.isEmpty && !isNoise(raw) {
                results.append(raw)
            }
            if results.count >= 8 { break }
        }
        return results
    }

    // MARK: 파싱 전략 6: desc_item (범용)

    private func parseDescItem(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"class="(?:desc_item|mean_item|list_mean)[^"]*"[^>]*>(.+?)</(?:li|dd|div)>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var results: [String] = []

        for match in matches {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let raw = cleanText(stripTags(String(html[r])))
            if !raw.isEmpty && !isNoise(raw) && raw.count >= 2 {
                results.append(raw)
            }
            if results.count >= 8 { break }
        }
        return results
    }

    // MARK: - 유틸리티

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
            .replacingOccurrences(of: "&hellip;", with: "...")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#8230;", with: "…")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isNoise(_ text: String) -> Bool {
        let noiseWords = ["더보기", "검색", "닫기", "이전", "다음", "English", "Japanese", "Chinese",
                          "로그인", "회원가입", "광고", "Cookie", "Privacy", "Terms",
                          "사전", "메뉴", "설정", "공유", "즐겨찾기", "번역"]
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count < 2 { return true }
        for n in noiseWords where t == n { return true }  // ★ 정확히 일치할 때만 노이즈 처리
        if t.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isSymbol || $0.isWhitespace }) { return true }
        return false
    }
}
