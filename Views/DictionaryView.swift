import SwiftUI

// MARK: - 사전 모드

enum DictionaryMode: String, CaseIterable, Identifiable {
    case daum = "Daum"
    var id: String { rawValue }
}

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
    }

    var body: some View {
        VStack(spacing: 0) {

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

                        // 뜻 목록
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

    // MARK: - 뜻 가져오기

    private func fetchMeaning(word: String, tab: DicTab) {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=\(tab.rawValue == "English" ? "eng" : tab.rawValue == "Japanese" ? "jp" : "ch")") else { return }

        isLoading = true
        meanings = []

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            let parsed = parseOgDescription(from: html)

            DispatchQueue.main.async {
                meanings = parsed
                isLoading = false
            }
        }.resume()
    }

    // MARK: - og:description 파싱

    private func parseOgDescription(from html: String) -> [String] {
        // og:description 추출
        guard let ogRange = html.range(of: "og:description"),
              let contentStart = html.range(of: "content=\"", range: ogRange.upperBound..<html.endIndex),
              let contentEnd = html.range(of: "\"", range: contentStart.upperBound..<html.endIndex) else {
            return []
        }

        var raw = String(html[contentStart.upperBound..<contentEnd.lowerBound])

        // HTML 엔티티 디코딩
        raw = raw.replacingOccurrences(of: "&hellip;", with: "…")
        raw = raw.replacingOccurrences(of: "&amp;", with: "&")
        raw = raw.replacingOccurrences(of: "&lt;", with: "<")
        raw = raw.replacingOccurrences(of: "&gt;", with: ">")
        raw = raw.replacingOccurrences(of: "&nbsp;", with: " ")
        raw = raw.replacingOccurrences(of: "&#39;", with: "'")
        raw = raw.replacingOccurrences(of: "&quot;", with: "\"")

        // "1.뜻 2.뜻 3.뜻 " 형태에서 각 뜻 분리
        // 숫자. 패턴으로 분리
        var results: [String] = []
        let pattern = #"\d+\.\s*(.+?)(?=\s*\d+\.|$)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = raw as NSString
            let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            for match in matches {
                if match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: raw) {
                    let meaning = String(raw[range]).trimmingCharacters(in: .whitespaces)
                    if !meaning.isEmpty {
                        results.append(meaning)
                    }
                }
            }
        }

        return results
    }
}

