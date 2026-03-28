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
            webView.scrollView.minimumZoomScale = 0.3
            webView.scrollView.maximumZoomScale = 3.0

            // 페이지 로드 후 70%로 축소
        let script = WKUserScript(
                    source: """
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
                    document.head.appendChild(meta);
                    document.body.style.webkitTextSizeAdjust = '70%';

                    var style = document.createElement('style');
                                style.textContent = `
                                    .txt_cleansch { font-size: 22px !important; }
                                    .tit_cleansch { font-size: 22px !important; }
                                    .txt_emph1 { font-size: 22px !important; }
                                    .search_word .txt_search { font-size: 22px !important; }
                                    .cleansch_top .txt_emph1 { font-size: 22px !important; }
                                    .search_box .txt_search { font-size: 14px !important; }
                                    #searchBar, .search_bar, .wrap_searchbar, .search_top, .card_word .search_box, .clean_search_wrap, .search_cleansch { display: none !important; }
                                    .header_search, .wrap_topsearch, #header, .gnb_comm { display: none !important; }
                                                    .card_word .search_box, .box_searchbar, .wrap_select, .select_dic { display: none !important; }
                                `;
                    document.head.appendChild(style);
                    """,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            webView.configuration.userContentController.addUserScript(script)

            webView.load(URLRequest(url: url))
            return webView
        }

    func updateUIView(_ webView: WKWebView, context: Context) {
            if webView.url?.absoluteString != url.absoluteString {
                webView.load(URLRequest(url: url))
            }

            // 창 크기 변경 시 콘텐츠 너비 맞추기
            webView.evaluateJavaScript("""
                document.body.style.width = '100%';
                document.body.style.maxWidth = window.innerWidth + 'px';
                document.body.style.overflowX = 'hidden';
                document.querySelector('html').style.overflowX = 'hidden';
            """)
        }
}
