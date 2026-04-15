import Foundation
import WebKit
import Combine

final class SharedWebViewModel {
    let webView: WKWebView

    init() {
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

            document.querySelectorAll('.card_word .wrap_search, .card_word .search_box, .card_word > p, .card_word > div:first-child').forEach(function(el) {
                var text = el.innerText || '';
                if (text.includes('영어') || text.includes('★') || text.includes('일본어') || text.includes('중국어')) {
                    el.style.setProperty('display', 'none', 'important');
                }
            });

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

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.keyboardDismissMode = .onDrag
        wv.scrollView.minimumZoomScale = 0.3
        wv.scrollView.maximumZoomScale = 3.0
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.showsVerticalScrollIndicator = false
        wv.scrollView.showsHorizontalScrollIndicator = false
        self.webView = wv
    }

    func load(url: URL) {
        if webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }
}
