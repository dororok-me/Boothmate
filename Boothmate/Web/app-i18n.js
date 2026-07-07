/* app-i18n.js — iOS 앱 전용 UI 언어 레이어 (KO ⇄ EN)
 *
 * 원칙:
 *  - 앱모드(<html class="bm-app">)에서만 작동. 일반 웹 브라우저에서는 아무 것도 안 함(웹은 한국어 유지).
 *  - 통역 자막(#mcWrap)과 반영 로그(#reflogList)는 절대 건드리지 않음(실제 통역 결과).
 *  - UI 껍데기(버튼/설정/용어집 라벨/placeholder 등)만 사전(DICT)에 있는 '정확히 일치하는' 문자열을 교체.
 *  - 자막 텍스트는 DICT에 없으므로 매칭되지 않아 안전.
 *  - alert()/confirm() 팝업은 DOM이 아니라 번역 대상 아님(추후 별도 처리).
 *
 * 사용: window.bmSetLang('en'|'ko'), window.bmGetLang()
 * 교수님(통역사) 검수용: 어색한 영어는 아래 DICT의 '값'(오른쪽)만 고치면 됩니다.
 */
(function () {
  'use strict';

  if (!document.documentElement.classList.contains('bm-app')) return;

  /* ── KO → EN 사전 (UI 껍데기만) ────────────────────────────── */
  var DICT = {
    // 상단/공통 버튼
    '방향 전환': 'Direction',
    '시작': 'Start',
    '정지': 'Stop',
    '시작 / 정지': 'Start / Stop',
    '오버레이': 'Overlay',
    '용어집': 'Glossary',
    '설정': 'Settings',
    '✕ 닫기': '✕ Close',
    '목록 새로고침': 'Refresh list',
    '맨 아래로 내려 자동 스크롤 재개': 'Scroll to bottom to resume auto-scroll',
    '로그 히스토리 지우기': 'Clear log history',
    '자막 리셋 (화면 자막 전체 지우기)': 'Reset subtitles (clear all on screen)',
    '이용약관': 'Terms of Service',
    '개인정보처리방침': 'Privacy Policy',
    '사업자정보 ▾': 'Business info ▾',
    '사업자정보 ▴': 'Business info ▴',
    '취소': 'Cancel',
    '저장': 'Save',
    '로그아웃': 'Log out',
    '추가': 'Add',
    '불러오기': 'Import',
    '전체 삭제': 'Delete all',
    '내보내기': 'Export',
    '자막 내보내기': 'Export subtitles',
    '자막 리셋하기': 'Reset subtitles',
    '저장된 세션': 'Saved sessions',
    '💾 현재 리스트를 클라우드에 저장': '💾 Save current list to cloud',
    '수정': 'Edit',
    '삭제': 'Delete',
    '이 파일을 용어집에 보내기': 'Send this file to glossary',

    // 섹션 제목
    '🔊 사운드 설정': '🔊 Sound settings',
    '번역 · 입력 설정': 'Translation · Input settings',
    '📖 Glossary(양방향)': '📖 Glossary (bidirectional)',
    '✏️ 용어 추가': '✏️ Add term',
    '💭 클라우드 용어집': '💭 Cloud glossary',
    '👤 계정': '👤 Account',
    '🔌 연결 방식': '🔌 Connection',
    '🔑 Gemini API 키 (직접 연결용)': '🔑 Gemini API key (for direct connection)',
    '🎫 통역 시작 티켓': '🎫 Interpretation ticket',
    '⚙ 테마 (스킨)': '⚙ Theme (skin)',
    '원문 (인식 결과)': 'Source (recognized speech)',
    '번역': 'Translation',
    '줄 간격 (여백)': 'Line spacing',
    '무음 자동 정지': 'Auto-stop on silence',
    '자막 기록': 'Subtitle records',
    "💭 저장된 클라우드 용어집 — 불러올 때 '삭제 후 불러오기 / 이어 붙이기'를 선택합니다": "💭 Saved cloud glossaries — when importing, choose 'Replace / Append'",

    // 설정 라벨/옵션
    '사운드 선택:': 'Sound source:',
    '🎤 외부 마이크 또는 오인페': '🎤 External mic or audio interface',
    '🖥️ 내 컴퓨터 사운드': "🖥️ My computer's sound",
    '목록에서 선택:': 'Select from list:',
    '기본 장치': 'Default device',
    '언어 선택:': 'Language:',
    '이 두 언어 사이에서만 양방향 번역됩니다': 'Translates both ways between these two languages only',
    '🔄 양방향 자동': '🔄 Auto (bidirectional)',
    '언어를 자동 인식해 양방향으로 번역합니다.': 'Automatically detects the language and translates both ways.',
    '$↔₩ 환율 환산': '$↔₩ Currency conversion',
    '📐 도량형 환산': '📐 Unit conversion',
    '크기': 'Size',
    '굵기': 'Weight',
    '색상': 'Color',
    '테마색': 'Theme color',
    '원문↔번역': 'Source↔Translation',
    '묶음 사이': 'Between blocks',
    '원문과 번역 줄 사이, 그리고 원문·번역 묶음끼리의 세로 여백을 조절합니다.': 'Adjusts the vertical spacing between the source and translation lines, and between source·translation blocks.',
    'Log 표시': 'Show log',
    '통역 중 적용된 용어집·환산 내역을 자막 아래에 표시합니다. 끄면 반영 로그 영역이 숨겨집니다.': 'Shows applied glossary·conversion details below the subtitles during interpretation. Turn off to hide the log area.',
    '음성 입력이 없으면': 'When there is no audio input',
    '사용 안 함': 'Off',
    '1분 후 정지': 'Stop after 1 min',
    '3분 후 정지': 'Stop after 3 min',
    '5분 후 정지': 'Stop after 5 min',
    '말소리(음성 인식 결과)가 설정한 시간 동안 들어오지 않으면 자동 정지합니다. 정지 30초 전에 경고를 표시하며, 다시 말하면 해제됩니다.': 'Automatically stops if no speech (recognized audio) is received for the set time. A warning appears 30 seconds before stopping, and speaking again cancels it.',
    '합쇼체 (~습니다)': 'Formal (-seumnida)',
    '해요체 (~에요)': 'Polite (-eyo)',
    '혼용': 'Mixed',
    '반말 (그대로)': 'Casual (as-is)',
    '직접 연결 (내 API 키 사용)': 'Direct (use my API key)',
    '중계 서버 (회원/베타 — 티켓 사용)': 'Relay server (member/beta — uses ticket)',
    '직접 연결은 본인 테스트용, 중계 서버는 회원용입니다.': 'Direct connection is for your own testing; the relay server is for members.',
    '☀️ 라이트': '☀️ Light',
    '🌙 다크': '🌙 Dark',
    '📄 페이퍼': '📄 Paper',
    '테마를 고르면 배경·글자색이 한 번에 바뀝니다. 아래에서 색을 직접 바꾸면 그 색이 우선됩니다.': 'Choosing a theme changes the background and text color at once. If you set a color manually below, that color takes priority.',

    // placeholder
    '용어 1 (예: patient)': 'Term 1 (e.g. patient)',
    '용어 2 (예: 피험자)': 'Term 2 (e.g. subject)',
    '용어 1 별칭 — 쉼표 구분 (예: participant, subject)': 'Term 1 aliases — comma separated (e.g. participant, subject)',
    '용어 2 별칭 — 쉼표 구분 (예: 참가자, 환자)': 'Term 2 aliases — comma separated (e.g. 참가자, 환자)',
    '🔍 등록된 용어 검색 — 비슷한 단어가 표시됩니다': '🔍 Search terms — similar words are shown',
    'Gemini API 키를 붙여넣으세요': 'Paste your Gemini API key',
    '중계 서버 주소 (운영자용)': 'Relay server address (for operator)',
    '발급받은 티켓을 붙여넣으세요': 'Paste your issued ticket',
    '용어 1 별칭 — 쉼표 구분': 'Term 1 aliases — comma separated',
    '용어 2 별칭 — 쉼표 구분': 'Term 2 aliases — comma separated',

    // 옵션/정렬
    '이 리스트 내보내기': 'Export this list',
    '최신순': 'Newest',
    'ABC순': 'A–Z',
    '가나다순': 'Korean (가나다)',
    '용어 정렬 순서': 'Term sort order',
    '별칭 추가·수정': 'Add·edit aliases',
    '별칭 없음': 'No aliases',

    // 빈 상태/안내 (DOM)
    '등록된 용어가 없습니다.': 'No terms registered.',
    '이미 등록된 비슷한 용어 — 클릭하면 입력칸에 채워져 수정할 수 있습니다': 'Similar term already registered — click to fill the input and edit',
    '이름을 붙여 보관하고, 행사마다 골라 불러옵니다': 'Save with a name and load it per event',
    '저장된 용어집이 없습니다. 위 버튼으로 현재 용어집을 이름 붙여 보관하세요.': 'No saved glossaries. Use the button above to save the current glossary with a name.',
    '저장된 세션이 없습니다.': 'No saved sessions.',
    '로그인 계정과 남은 시간이 표시됩니다.': 'Shows your account and remaining time.',
    '키는 이 브라우저에만 저장되며 외부로 전송되지 않습니다.': 'The key is stored only in this browser and is never sent externally.',
    '발급받은 티켓을 입력하면 바로 통역이 시작됩니다. 남은 시간이 차감됩니다.': 'Enter your ticket to start interpreting right away. Remaining time will be deducted.',
    '세션은 정지/새 시작 시 자동 저장(최대 50개). 내보내기는 현재 화면 자막을 txt로 저장합니다.': 'Sessions are auto-saved on stop/new start (up to 50). Export saves the current on-screen subtitles as a txt file.',
    '별칭은 각 용어와 같은 언어의 변이형입니다. participant·subject가 들리면 피험자로, 참가자·환자가 들리면 patient로 번역·교체됩니다.': 'Aliases are variants in the same language as each term. If participant·subject is heard it is translated·replaced as 피험자, and if 참가자·환자 is heard it becomes patient.',
    '양방향 자동: 들어온 말의 언어를 감지해 반대 언어로 자동 번역 · 단방향: 선택한 방향으로만 번역 (강연 등 한 사람만 말할 때 방향 오전환 방지)': 'Auto (bidirectional): detects the incoming language and translates to the other · One-way: translates only in the chosen direction (prevents wrong direction switches when only one person speaks, e.g. a lecture)',
    'Enter = 저장 · Shift+Enter = 줄바꿈 · Esc = 취소 · 저장 시 오버레이에도 즉시 반영됩니다': 'Enter = Save · Shift+Enter = New line · Esc = Cancel · Saving is reflected in the overlay instantly',
    '번역 수정 — 클릭한 단어가 선택되어 있습니다': 'Edit translation — the clicked word is selected',

    // 상태 배지/텍스트
    '로그인됨': 'Logged in',
    '무제한': 'Unlimited',
    '시간 소진 — 충전 필요': 'Time used up — recharge needed',
    '자동 감지': 'Auto-detect',
    '입력 사운드 레벨 (재생 전에도 소리가 들어오는지 확인)': 'Input sound level (check that audio is coming in even before playback)',
    '입력 사운드 레벨': 'Input sound level',
    '경과 시간': 'Elapsed time',

    // 언어 이름 (선택 메뉴에 보이는 것들)
    '한국어': 'Korean',
    '영어': 'English',
    '일본어': 'Japanese',
    '중국어': 'Chinese'
  };

  var SKIP_IDS = ['mcWrap', 'reflogList', 'reflogBox', 'bmLangGrp'];

  var REV = null;
  var lang = localStorage.getItem('bm_ui_lang') || 'en';   // 앱 기본값: 영어
  var observer = null, busy = false, scheduled = false;

  function reverse() {
    if (REV) return REV;
    REV = {};
    for (var k in DICT) if (DICT.hasOwnProperty(k)) REV[DICT[k]] = k;
    return REV;
  }

  function inSkip(node) {
    var el = node.nodeType === 3 ? node.parentNode : node;
    while (el && el.nodeType === 1) {
      if (el.id && SKIP_IDS.indexOf(el.id) !== -1) return true;
      el = el.parentNode;
    }
    return false;
  }

  function mapText(node, map) {
    var raw = node.nodeValue;
    if (!raw) return;
    var key = raw.trim();
    if (!key || !(key in map)) return;
    node.nodeValue = raw.match(/^\s*/)[0] + map[key] + raw.match(/\s*$/)[0];
  }

  function mapAttr(el, attr, map) {
    var v = el.getAttribute(attr);
    if (v == null) return;
    var key = v.trim();
    if (key in map) el.setAttribute(attr, map[key]);
  }

  function sweep(root, map) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    var batch = [], n;
    while ((n = walker.nextNode())) if (!inSkip(n)) batch.push(n);
    for (var i = 0; i < batch.length; i++) mapText(batch[i], map);
    var els = root.querySelectorAll('[placeholder],[title],input[type="button"],input[type="submit"]');
    for (var j = 0; j < els.length; j++) {
      var el = els[j];
      if (inSkip(el)) continue;
      mapAttr(el, 'placeholder', map);
      mapAttr(el, 'title', map);
      if (el.tagName === 'INPUT' && (el.type === 'button' || el.type === 'submit')) mapAttr(el, 'value', map);
    }
  }

  /* 설정 패널 맨 위에 KO/EN 토글 그룹 삽입 (없을 때만) */
  function ensureLangToggle() {
    var panel = document.getElementById('mcPanel');
    if (!panel || !panel.firstChild || document.getElementById('bmLangGrp')) return;
    var grp = document.createElement('div');
    grp.className = 'grp';
    grp.id = 'bmLangGrp';
    grp.innerHTML =
      '<div class="grp-ttl">🌐 Language</div>' +
      '<div style="display:flex; gap:8px;">' +
      '<button type="button" id="bmLangEn" style="flex:1; padding:9px 12px; border-radius:8px; border:1px solid var(--t-border); background:var(--t-input-bg); color:var(--t-text); font-size:13px; cursor:pointer;">English</button>' +
      '<button type="button" id="bmLangKo" style="flex:1; padding:9px 12px; border-radius:8px; border:1px solid var(--t-border); background:var(--t-input-bg); color:var(--t-text); font-size:13px; cursor:pointer;">한국어</button>' +
      '</div>';
    panel.insertBefore(grp, panel.firstChild);
    document.getElementById('bmLangEn').addEventListener('click', function () { window.bmSetLang('en'); });
    document.getElementById('bmLangKo').addEventListener('click', function () { window.bmSetLang('ko'); });
  }

  function syncToggle() {
    var en = document.getElementById('bmLangEn');
    var ko = document.getElementById('bmLangKo');
    [['en', en], ['ko', ko]].forEach(function (p) {
      if (!p[1]) return;
      var on = (lang === p[0]);
      p[1].style.background = on ? '#4f46e5' : 'var(--t-input-bg)';
      p[1].style.color = on ? '#fff' : 'var(--t-text)';
      p[1].style.borderColor = on ? '#4f46e5' : 'var(--t-border)';
    });
  }

  function curMap() { return lang === 'en' ? DICT : reverse(); }

  // 전체 훑기 (초기 1회 + 언어 토글 시에만)
  function applyAll() {
    busy = true;
    if (observer) observer.disconnect();
    ensureLangToggle();
    sweep(document.body, curMap());
    if (observer) observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    busy = false;
    syncToggle();
  }

  function translateNode(node, map) {
    if (inSkip(node)) return;
    if (node.nodeType === 3) mapText(node, map);
    else if (node.nodeType === 1) sweep(node, map);
  }

  // 관찰자 콜백: 새로 추가/변경된 부분만 처리 (전체 재훑기 X → 초기 로딩 부담 최소화)
  function processMutations(records) {
    if (busy) return;
    busy = true;
    if (observer) observer.disconnect();
    var map = curMap();
    for (var i = 0; i < records.length; i++) {
      var r = records[i];
      if (r.type === 'characterData') { if (!inSkip(r.target)) mapText(r.target, map); }
      else if (r.addedNodes) { for (var j = 0; j < r.addedNodes.length; j++) translateNode(r.addedNodes[j], map); }
    }
    ensureLangToggle();
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    busy = false;
    syncToggle();
  }

  window.bmGetLang = function () { return lang; };
  window.bmSetLang = function (l) {
    if (l !== 'en' && l !== 'ko') return;
    if (l === lang) { syncToggle(); return; }
    lang = l;
    try { localStorage.setItem('bm_ui_lang', l); } catch (e) {}
    applyAll();
  };

  function start() {
    applyAll();
    observer = new MutationObserver(processMutations);
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    setTimeout(applyAll, 400);
    setTimeout(applyAll, 1500);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
