import SwiftUI
import WebKit

struct DictionaryView: View {
    @State private var searchText = ""
    @State private var currentURL: URL?
    @State private var webViewID = UUID()

    private let baseURL = "https://small.dic.daum.net"

    var body: some View {
        DaumDicWebView(url: currentURL ?? URL(string: baseURL)!)
            .id(webViewID)
            .onReceive(NotificationCenter.default.publisher(for: .searchDictionary)) { notification in
                if let word = notification.object as? String {
                    searchText = word
                    search()
                }
            }
    }

    private func search() {
        guard !searchText.isEmpty else { return }
        let encoded = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
        let isKorean = searchText.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
        let dicType = isKorean ? "ee" : "eq"
        currentURL = URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=\(dicType)")
        webViewID = UUID()
    }
}

struct DaumDicWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
    }
}
