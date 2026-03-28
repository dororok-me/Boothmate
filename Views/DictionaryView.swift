import SwiftUI
import WebKit
import Combine

struct DictionaryView: View {
    @State private var currentURL = URL(string: "https://dic.daum.net/index.do?dic=eng")!
    @State private var currentWord: String = ""

    var body: some View {
        DaumDictionaryWebView(url: currentURL)
                    .onReceive(NotificationCenter.default.publisher(for: .searchDictionary)) { notification in
                        guard let word = notification.object as? String else { return }
                        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        currentWord = trimmed
                        currentURL = makeSearchURL(for: trimmed)
                    }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.searchDictionary)) { notification in
            guard let word = notification.object as? String else { return }

            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            currentWord = trimmed
            currentURL = makeSearchURL(for: trimmed)
        }
    }

    private func makeSearchURL(for text: String) -> URL {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        return URL(string: "https://dic.daum.net/search.do?q=\(encoded)&dic=eng")!
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
        if webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }
}
