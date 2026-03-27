import SwiftUI
import WebKit
import Combine

struct DictionaryView: View {
    @State private var currentURL = URL(string: "https://small.dic.daum.net")!
    @State private var currentWord: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(currentWord.isEmpty ? "Dictionary" : "Search: \(currentWord)")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    currentWord = ""
                    currentURL = URL(string: "https://small.dic.daum.net")!
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            Divider()

            DaumDictionaryWebView(url: currentURL)
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchDictionary)) { notification in
            guard let word = notification.object as? String else { return }
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            currentWord = trimmed
            currentURL = makeSearchURL(for: trimmed)
        }
    }

    private func makeSearchURL(for text: String) -> URL {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text

        let isKorean = text.unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(scalar.value)
        }

        let dicType = isKorean ? "ee" : "eq"

        return URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=\(dicType)")!
    }
}

struct DaumDictionaryWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
