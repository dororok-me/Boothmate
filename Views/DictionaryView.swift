import SwiftUI
import WebKit
import UIKit

// MARK: - 사전 모드

enum DictionaryMode: String, CaseIterable, Identifiable {
    case daum = "Daum"
    var id: String { rawValue }
}

// MARK: - DictionaryView

struct DictionaryView: View {
    var hideTabs: Bool = false
    @AppStorage("dictionaryMode") private var dictionaryMode: String = DictionaryMode.daum.rawValue
    @State private var isRecording: Bool = false

    @State private var selectedDic: DicTab = .eng
    @State private var currentURL: URL? = nil
    @State private var currentWord: String = ""

    enum DicTab: String, CaseIterable {
        case eng = "English"
        case jp  = "Japanese"
        case ch  = "Chinese"

        var dicCode: String {
            switch self {
            case .eng: return "eng"
            case .jp:  return "jp"
            case .ch:  return "ch"
            }
        }

        var activeColor: Color {
            switch self {
            case .eng: return .blue
            case .jp:  return .black
            case .ch:  return .red
            }
        }
    }

    private var mode: DictionaryMode {
        DictionaryMode(rawValue: dictionaryMode) ?? .daum
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
                                currentURL = makeSearchURL(for: currentWord, tab: tab)
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

            // 사전 컨텐츠
            Group {
                if let url = currentURL {
                    DaumDictionaryWebView(url: url)
                } else {
                    emptyView
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
                // 한국어 단어 → Booth 모드에 따라 한영/한일/한중
                let targetTab: DicTab
                switch boothLanguage {
                case "ja-JP": targetTab = .jp
                case "zh-CN": targetTab = .ch
                default:      targetTab = .eng
                }
                selectedDic = targetTab
                currentURL = makeSearchURL(for: trimmed, tab: targetTab)
            } else if isJapanese {
                selectedDic = .jp
                currentURL = makeSearchURL(for: trimmed, tab: .jp)
            } else if isChinese && boothLanguage == "zh-CN" {
                selectedDic = .ch
                currentURL = makeSearchURL(for: trimmed, tab: .ch)
            } else {
                // 영어 등 기타 → Booth 언어 기준
                let targetTab: DicTab
                switch boothLanguage {
                case "ja-JP": targetTab = .jp
                case "zh-CN": targetTab = .ch
                default:      targetTab = .eng
                }
                selectedDic = targetTab
                currentURL = makeSearchURL(for: trimmed, tab: targetTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .boothChanged)) { notification in
            guard let boothLanguage = notification.object as? String else { return }
            switch boothLanguage {
            case "ja-JP": selectedDic = .jp
            case "zh-CN": selectedDic = .ch
            default:      selectedDic = .eng
            }
            currentWord = ""
            currentURL = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("recordingStateChanged"))) { notification in
            isRecording = notification.object as? Bool ?? false
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.3))
                .padding(.bottom, 8)
            Text("단어를 탭하면 검색됩니다")
                .font(.system(size: 13))
                .foregroundColor(.gray.opacity(0.5))
            Spacer()
        }
    }

    private func makeSearchURL(for text: String, tab: DicTab) -> URL? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let isKorean = text.unicodeScalars.contains(where: { $0.value >= 0xAC00 && $0.value <= 0xD7A3 })

        switch tab {
        case .eng:
            // 한국어 → 한영(eng), 영어 → 영한(eng) 다음이 자동 처리
            return URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=eng")
        case .jp:
            // 한국어 → 한일(jp), 일본어 → 일한(jp)
            return URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=jp")
        case .ch:
            // 한국어 → 한중(ch), 중국어 → 중한(ch)
            return URL(string: "https://small.dic.daum.net/search.do?q=\(encoded)&dic=ch")
        }
    }
}

// MARK: - Daum Dictionary WebView (기존 유지)

struct DaumDictionaryWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

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
                '.direct_area', '.autocomplete_wrap',
                '.box_keyword', '.keyword_area', '.wrap_keyword',
                '.select_keyword', '.btn_keyword', '.wrap_dic_tit',
                '.tit_dic', '.logo_daum', '.wrap_logo', '.service_logo',
                '.area_title', '.area_search_total', '.wrap_search_total',
                '.box_search', '.form_search', '.inp_search', '.btn_search',
                '.select_lang', '.wrap_select_lang', '.box_select_lang',
                '.search_total', '.cleansch_top',
                '.wrap_tit_search', '.tit_search', '.box_tit_search',
                '.rank_star', '.star_area', '.wrap_star',
                '.ico_star', '.num_star', '.point_star',
                '.keyword_link', '.wrap_keyword_link',
                '.badge_keyword', '.tag_keyword'
            ];
            hide.forEach(function(sel) {
                document.querySelectorAll(sel).forEach(function(el) {
                    el.style.setProperty('display', 'none', 'important');
                    el.style.setProperty('height', '0', 'important');
                    el.style.setProperty('overflow', 'hidden', 'important');
                    el.style.setProperty('padding', '0', 'important');
                    el.style.setProperty('margin', '0', 'important');
                });
            });

            // ★ 별표 + 언어 표시 텍스트 제거 (card_word 안 첫 번째 p, span 등)
            document.querySelectorAll('.card_word .wrap_search, .card_word .search_box, .card_word > p, .card_word > div:first-child').forEach(function(el) {
                var text = el.innerText || '';
                if (text.includes('영어') || text.includes('★') || text.includes('일본어') || text.includes('중국어')) {
                    el.style.setProperty('display', 'none', 'important');
                }
            });

            // input, select, form 요소 강제 숨기기
            document.querySelectorAll('form, input[type="text"], select').forEach(function(el) {
                var parent = el.closest('.card_word, #mArticle, .wrap_dic');
                if (!parent) {
                    el.style.setProperty('display', 'none', 'important');
                    if (el.parentElement) {
                        el.parentElement.style.setProperty('display', 'none', 'important');
                    }
                }
            });
        }

        function showResults() {
            var resultSelectors = [
                '.list_search_result', '.search_result', '#mArticle',
                '.wrap_dic', '.inner_dic', '.card_word',
                '.cont_dic', '.list_dic', '.wrap_search_result'
            ];
            resultSelectors.forEach(function(sel) {
                document.querySelectorAll(sel).forEach(function(el) {
                    el.style.setProperty('display', 'block', 'important');
                    el.style.setProperty('visibility', 'visible', 'important');
                    el.style.setProperty('opacity', '1', 'important');
                });
            });
        }

        function cleanPage() { hideSearchBar(); fixLayout(); showResults(); }

        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
        document.head.appendChild(meta);

        var style = document.createElement('style');
        style.textContent = '::-webkit-scrollbar{display:none !important;width:0 !important;}*{max-width:100vw !important;}body,html{overflow-x:hidden !important;}.card_word>.search_box,.card_word>.wrap_searchbar,.card_word>form,.search_suggest,.list_suggest,.wrap_suggest,.clean_search_input,.inner_searchbar,.tog_cleansch,.autocomplete_wrap,.direct_area,#searchBar,.card_word .search_area,.clean_search_wrap,.search_cleansch,.wrap_searchbar,.search_top,.box_searchbar,.wrap_select,.select_dic,.search_word,.txt_info,#suggestionWrap,.search_input,.wrap_search,.search_area,.area_search,.inner_search,#header,.gnb_comm,.header_search,.wrap_topsearch,.cleansch_border,.wrap_toolbar,.toolbar_dic,.box_keyword,.keyword_area,.wrap_keyword,.select_keyword,.btn_keyword,.wrap_dic_tit,.tit_dic,.logo_daum,.link_logo,.wrap_logo,.service_logo,.inner_service_logo,.area_title,.area_search_total,.wrap_search_total,.search_total,.box_search,.form_search,.inp_search,.btn_search,.select_lang,.wrap_select_lang,.box_select_lang,.wrap_tit_search,.tit_search,.box_tit_search,.rank_star,.star_area,.wrap_star,.ico_star,.num_star,.point_star,.keyword_link,.wrap_keyword_link,.badge_keyword,.tag_keyword{display:none !important;height:0 !important;padding:0 !important;margin:0 !important;overflow:hidden !important;}';
        document.head.appendChild(style);

        document.body.style.webkitTextSizeAdjust = '70%';
        cleanPage();
        setTimeout(cleanPage, 300);
        setTimeout(cleanPage, 800);
        setTimeout(cleanPage, 1500);
        setTimeout(cleanPage, 3000);
        window.addEventListener('resize', fixLayout);
        var observer = new MutationObserver(cleanPage);
        observer.observe(document.body, { childList: true, subtree: true });
        """

        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.scrollView.minimumZoomScale = 0.3
        webView.scrollView.maximumZoomScale = 3.0
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
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
                document.documentElement.style.maxWidth='\(Int(width))px';
                document.documentElement.style.overflowX='hidden';
                document.body.style.maxWidth='\(Int(width))px';
                document.body.style.overflowX='hidden';
                document.body.style.width='100%';
                document.body.style.minWidth='0';
                document.querySelectorAll('#daumContent,.container_dic,#mArticle,.wrap_dic,.inner_dic,.search_cont,#dimmedLayer,.card_word,.cleansch_top,.wrap_cleansch').forEach(function(el){
                    el.style.maxWidth='100%';el.style.width='100%';el.style.minWidth='0';
                    el.style.overflowX='hidden';el.style.boxSizing='border-box';
                });
            """)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
                (function() {
                    function showResults() {
                        var resultSelectors = [
                            '.list_search_result', '.search_result', '#mArticle',
                            '.wrap_dic', '.inner_dic', '.card_word',
                            '.cont_dic', '.list_dic', '.wrap_search_result'
                        ];
                        resultSelectors.forEach(function(sel) {
                            document.querySelectorAll(sel).forEach(function(el) {
                                el.style.setProperty('display', 'block', 'important');
                                el.style.setProperty('visibility', 'visible', 'important');
                                el.style.setProperty('opacity', '1', 'important');
                            });
                        });

                        var hide = ['#header','.gnb_comm','.header_search','.wrap_topsearch',
                            '#searchBar','.search_bar','.wrap_searchbar','.search_top',
                            '.clean_search_wrap','.search_cleansch','.box_searchbar',
                            '.wrap_select','.select_dic','.search_word','.txt_info',
                            '#suggestionWrap','.search_input','.wrap_search',
                            '.search_area','.area_search','.inner_search',
                            '.direct_area','.autocomplete_wrap'];
                        hide.forEach(function(sel) {
                            document.querySelectorAll(sel).forEach(function(el) {
                                el.style.display = 'none';
                            });
                        });
                    }

                    showResults();
                    setTimeout(showResults, 400);
                    setTimeout(showResults, 1000);
                })();
            """
            webView.evaluateJavaScript(js)
        }
    }
}
