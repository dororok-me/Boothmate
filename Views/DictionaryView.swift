import SwiftUI
import WebKit

struct DictionaryView: View {
    @State private var currentURL = URL(string: "https://dic.daum.net/index.do?dic=eng")!
    @State private var currentWord: String = ""
    
    var body: some View {
        DaumDictionaryWebView(url: currentURL)
            .onReceive(NotificationCenter.default.publisher(for: .searchDictionary)) { notification in
                guard let word = notification.object as? String else { return }
                let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                
                let language = notification.userInfo?["language"] as? String ?? "en-US"
                currentWord = trimmed
                currentURL = makeSearchURL(for: trimmed, language: language)
            }
    }
    
    private func makeSearchURL(for text: String, language: String) -> URL {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text

            let isKorean = text.unicodeScalars.contains(where: { $0.value >= 0xAC00 && $0.value <= 0xD7A3 })

            let dicType: String

            if isKorean {
                switch language {
                case "ja-JP": dicType = "jp"
                case "zh-CN": dicType = "ch"
                default: dicType = "eng"
                }
            } else if text.unicodeScalars.contains(where: { $0.value >= 0x3040 && $0.value <= 0x30FF }) {
                dicType = "jp"
            } else if text.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF }) {
                switch language {
                case "ja-JP": dicType = "jp"
                default: dicType = "ch"
                }
            } else {
                dicType = "eng"
            }

            return URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=\(dicType)")!
        }
}

struct DaumDictionaryWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let js = """
        function fixLayout() {
            var w = window.innerWidth + 'px';
            document.documentElement.style.cssText = 'overflow-x:hidden !important; max-width:' + w + ' !important;';
            document.body.style.cssText += 'overflow-x:hidden !important; max-width:' + w + ' !important; min-width:0 !important; width:100% !important;';
            var containers = document.querySelectorAll('#daumContent, .container_dic, #mArticle, .wrap_dic, .inner_dic, .search_cont, #dimmedLayer, .card_word, .cleansch_top, .wrap_cleansch');
            containers.forEach(function(el) {
                el.style.maxWidth = '100%';
                el.style.width = '100%';
                el.style.minWidth = '0';
                el.style.overflowX = 'hidden';
                el.style.boxSizing = 'border-box';
            });
        }

        function hideSearchBar() {
            var hide = [
                '#header', '.gnb_comm', '.header_search', '.wrap_topsearch',
                '#searchBar', '.search_bar', '.wrap_searchbar', '.search_top',
                '.clean_search_wrap', '.search_cleansch', '.box_searchbar',
                '.wrap_select', '.select_dic', '.search_word', '.txt_info',
                '#suggestionWrap', '.search_input', '.wrap_search',
                '.search_area', '.area_search', '.inner_search',
                '.direct_area', '.autocomplete_wrap'
            ];
            hide.forEach(function(sel) {
                document.querySelectorAll(sel).forEach(function(el) {
                    el.style.display = 'none';
                });
            });
        }

        function cleanPage() {
            hideSearchBar();
            fixLayout();
        }

        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
        document.head.appendChild(meta);

        var style = document.createElement('style');
        style.textContent = '* { max-width: 100vw !important; } body, html { overflow-x: hidden !important; } .card_word > .search_box, .card_word > .wrap_searchbar, .card_word > form, .search_suggest, .list_suggest, .wrap_suggest, .clean_search_input, .inner_searchbar, .tog_cleansch, .autocomplete_wrap, .direct_area, #searchBar, .card_word .search_area, .clean_search_wrap, .search_cleansch, .wrap_searchbar, .search_top, .box_searchbar, .wrap_select, .select_dic, .search_word, .txt_info, #suggestionWrap, .search_input, .wrap_search, .search_area, .area_search, .inner_search, #header, .gnb_comm, .header_search, .wrap_topsearch, .cleansch_border, .wrap_toolbar, .toolbar_dic { display: none !important; height: 0 !important; padding: 0 !important; margin: 0 !important; }'; .card_word > .search_box, .card_word > .wrap_searchbar, .card_word > form, .search_suggest, .list_suggest, .wrap_suggest, .clean_search_input, .inner_searchbar, .tog_cleansch, .autocomplete_wrap, .direct_area, #searchBar, .card_word .search_area { display: none !important; height: 0 !important; overflow: hidden !important; }';
                document.head.appendChild(style);

        document.body.style.webkitTextSizeAdjust = '70%';

        cleanPage();
        setTimeout(cleanPage, 300);
        setTimeout(cleanPage, 800);
        setTimeout(cleanPage, 2000);

        window.addEventListener('resize', fixLayout);

        var observer = new MutationObserver(cleanPage);
        observer.observe(document.body, { childList: true, subtree: true });
        """

        let script = WKUserScript(
            source: js,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.scrollView.minimumZoomScale = 0.3
        webView.scrollView.maximumZoomScale = 3.0
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }

        let width = webView.bounds.width
        if width > 0 {
            webView.evaluateJavaScript("""
                document.documentElement.style.maxWidth = '\(Int(width))px';
                document.documentElement.style.overflowX = 'hidden';
                document.body.style.maxWidth = '\(Int(width))px';
                document.body.style.overflowX = 'hidden';
                document.body.style.width = '100%';
                document.body.style.minWidth = '0';
                document.querySelectorAll('#daumContent, .container_dic, #mArticle, .wrap_dic, .inner_dic, .search_cont, #dimmedLayer, .card_word, .cleansch_top, .wrap_cleansch').forEach(function(el) {
                    el.style.maxWidth = '100%';
                    el.style.width = '100%';
                    el.style.minWidth = '0';
                    el.style.overflowX = 'hidden';
                    el.style.boxSizing = 'border-box';
                });
            """)
        }
    }
}
