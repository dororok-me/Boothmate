/* currency.js — 환율 환산 후처리 (BoothmateG currency.ts v0.10.0 → JS 포팅)
   원본: BoothmateG_Windows/src/renderer/console/src/currency.ts (v0.10.0)
   환율 API: https://open.er-api.com/v6/latest/KRW  (CORS 허용, 키 불필요)
   번역 자막 텍스트에서 금액을 감지해 괄호로 환산값을 덧붙인다(원본 통화는 그대로 보존).
   - 원본 통화는 깎지 않음: "43,200 달러(₩6,635만원)", "27,000원($18)".
   - 환산값(괄호)은 "클수록 뒤를 더 끊기": $1만→₩1,536만원, 2.8억→2억8,200만원.
   - 언어별 원화 단위: 영어 자막=₩600 million / 한국어 자막=6억원.
   API(전역 window.BoothmateCurrency):
     fetchRates()  applyConversion(text, lang)  applyConversionWithLog(text, lang)
     getRates()  getLastUpdated() */
(function (global) {
  "use strict";

  var CODES = ["USD", "EUR", "GBP", "JPY", "CNY"];

  // code → KRW (1 USD = 1340 KRW 식). 네트워크 실패 시 폴백 기본값.
  var DEFAULT_RATES = { USD: 1340, EUR: 1460, GBP: 1700, JPY: 9, CNY: 185 };
  var rates = { USD: 1340, EUR: 1460, GBP: 1700, JPY: 9, CNY: 185 };
  var lastUpdated = null;
  var isLoading = false;

  // 통화기호 → (코드, 정규식용 기호)
  var SYMBOL_TO_CODE = [
    ["USD", "\\$"],
    ["EUR", "€"],
    ["GBP", "£"],
    ["JPY", "¥"],
    ["CNY", "元"]
  ];

  // ── 환율 가져오기 (KRW 기준 → 역수로 code→KRW) ──
  function fetchRates() {
    if (isLoading) return Promise.resolve();
    isLoading = true;
    return fetch("https://open.er-api.com/v6/latest/KRW")
      .then(function (r) { return r.json(); })
      .then(function (json) {
        var rd = json && json.rates;
        if (rd) {
          var nr = {};
          for (var i = 0; i < CODES.length; i++) {
            var code = CODES[i];
            var v = rd[code];
            if (typeof v === "number" && v > 0) nr[code] = 1 / v;
          }
          if (Object.keys(nr).length) { rates = nr; lastUpdated = new Date(); }
        }
      })
      .catch(function () { /* 실패 시 기본값 유지 */ })
      .then(function () { isLoading = false; });
  }

  function countChar(s, c) { var n = 0; for (var i = 0; i < s.length; i++) if (s.charAt(i) === c) n++; return n; }
  // STT가 긴 숫자를 "6,820 7만" / "6,820 ₩70,000"처럼 공백으로 쪼갠 조각인지 판별.
  // 매치 바로 앞이 "숫자 "(+공백)로 끝나면 떨어진 조각으로 보고 환산을 건너뛴다
  // (조각의 뒷부분만 환산하면 68백만원이 $45처럼 엉뚱하게 표시돼 신뢰도가 떨어짐).
  function isNumFragmentBefore(fullOut, m) {
    var before = String(fullOut).slice(0, m.index);
    var lead = /^\s+/.exec(m[0]);          // 매치가 삼킨 앞 공백(₩?\s* 등)까지 포함해 판정
    if (lead) before += lead[0];
    return /\d[\d,]*(?:\.\d+)?\s+$/.test(before);
  }
  function stripComma(s) { return String(s).replace(/,/g, ""); }
  function fmtComma(v) { return Math.round(v).toLocaleString("en-US"); }

  // applyConversionWithLog 실행 중에만 설정되는 변경 수집기(동기 실행이라 안전)
  var activeLog = null;
  // 현재 변환 중인 자막 언어. 'ko'면 원화 한글 단위(억/만), 그 외(영어 등)면 영어 단위(million/billion).
  var activeLang = null;
  function wonInEnglish() { return activeLang != null && activeLang !== "ko"; }

  // 매치를 뒤에서부터 교체. fn이 null 반환 시 그 매치는 건너뜀.
  // 공통 가드: 바로 뒤가 '(' (이미 환산됨)이거나 괄호 안(열림>닫힘)이면 건너뜀.
  function replaceMatches(text, regex, fn) {
    var matches = [];
    var m;
    regex.lastIndex = 0;
    while ((m = regex.exec(text)) !== null) {
      matches.push(m);
      if (m.index === regex.lastIndex) regex.lastIndex++; // 빈 매치 방지
    }
    var output = text;
    for (var i = matches.length - 1; i >= 0; i--) {
      var mm = matches[i];
      var start = mm.index;
      if (start == null || start < 0) continue;
      var end = start + mm[0].length;
      if (output.charAt(end) === "(") continue;
      var before = output.slice(0, start);
      if (countChar(before, "(") > countChar(before, ")")) continue;
      var rep = fn(mm, output, end);
      if (rep == null) continue;
      if (activeLog) activeLog.push({ from: mm[0], to: rep });
      output = output.slice(0, start) + rep + output.slice(end);
    }
    return output;
  }

  // ── 포맷 헬퍼 ──
  function formatWonEnglish(v) {
    var u = function (n) { return Number.isInteger(n) ? String(n) : n.toFixed(1); };
    if (v >= 1e15) return "₩" + u(v / 1e15) + " quadrillion";
    if (v >= 1e12) return "₩" + u(v / 1e12) + " trillion";   // 조 단위 (1조=1e12) — billion으로 안 끊김
    if (v >= 1e9) return "₩" + u(v / 1e9) + " billion";
    if (v >= 1e6) return "₩" + u(v / 1e6) + " million";
    return "₩" + fmtComma(v);
  }
  // 외화→원화 환산값(괄호): 언어 무관하게 항상 한글 단위. 1억 미만 정확("약" 생략), 억 이상 "약".
  function formatKRW(v) {
    if (v < 1e8) return "₩" + koreanNumber(v);
    return "₩약 " + koreanNumber(v);
  }
  function formatWonUnit(v) {
    if (wonInEnglish()) return formatWonEnglish(v);
    return formatKRWkorean(v);
  }
  // 환산값을 한글 단위로 끊어 표시. "클수록 뒤를 더 끊기" — 상위 단위 값 100↑면 다음(작은) 단위 생략.
  function koreanNumber(v) {
    var gyeong = 1e16, jo = 1e12, eok = 1e8, man = 1e4;
    if (v >= gyeong) {
      var g = Math.floor(v / gyeong);
      var j = Math.floor((v % gyeong) / jo);
      return j > 0 ? fmtComma(g) + "경" + fmtComma(j) + "조원" : fmtComma(g) + "경원";
    } else if (v >= jo) {
      var j2 = Math.floor(v / jo);
      var e = Math.floor((v % jo) / eok);
      if (j2 >= 100) return fmtComma(j2) + "조원";
      return e > 0 ? fmtComma(j2) + "조" + fmtComma(e) + "억원" : fmtComma(j2) + "조원";
    } else if (v >= eok) {
      var e2 = Math.floor(v / eok);
      var m = Math.floor((v % eok) / man);
      if (e2 >= 100) return fmtComma(e2) + "억원";
      return m > 0 ? fmtComma(e2) + "억" + fmtComma(m) + "만원" : fmtComma(e2) + "억원";
    } else if (v >= man) {
      var mn = Math.floor(v / man);
      var r = Math.floor(v % man);
      if (mn >= 100) return fmtComma(mn) + "만원";
      return r > 0 ? fmtComma(mn) + "만" + fmtComma(r) + "원" : fmtComma(mn) + "만원";
    }
    return fmtComma(Math.floor(v)) + "원";
  }
  function formatKRWkorean(v) {
    var eok = 1e8, man = 1e4;
    if (v >= eok) {
      var e = Math.floor(v / eok);
      var m = Math.floor((v % eok) / man);
      var cheon = Math.floor(m / 1000);
      return cheon > 0 ? "₩" + e + "억" + cheon + "천만원" : "₩" + e + "억원";
    } else if (v >= man) {
      return "₩" + fmtComma(Math.floor(v / man)) + "만원";
    }
    return "₩" + fmtComma(v) + "원";
  }
  function formatUSDsimple(v) {
    var u = function (n) { return Number.isInteger(n) ? String(n) : n.toFixed(1); };
    if (v >= 1e15) return "$" + u(v / 1e15) + " quadrillion";
    if (v >= 1e12) return "$" + u(v / 1e12) + " trillion";   // 조 단위 — billion으로 안 끊김
    if (v >= 1e9) return "$" + u(v / 1e9) + " billion";
    if (v >= 1e6) return "$" + u(v / 1e6) + " million";
    return "$" + fmtComma(v);
  }

  var NUM = "(\\d+(?:,\\d+)*(?:\\.\\d+)?)";

  // ── 한국어 복합 수사 파서 ──
  // 번역기가 "8억 5천만 달러", "4억 3,900만 달러", "23조 3,486억" 처럼 여러 단위를 이어 쓰면
  // 기존엔 마지막 단위(예: 5천만)만 잡혀 값이 10~100배 틀렸다. 런 전체를 한 덩어리로 합산한다.
  var KUNIT = "(?:조|억|천만|백만|만|천)";
  // 복합 런: (숫자+단위) 1회 이상 + 선택적 끝자리 숫자.  "5천만", "152억", "8억 5천만", "4억 3,900만"
  var KRUN = "((?:\\d[\\d,]*(?:\\.\\d+)?\\s*" + KUNIT + "\\s*)+(?:\\d[\\d,]*(?:\\.\\d+)?)?)";
  var KUNIT_VAL = { "조": 1e12, "억": 1e8, "천만": 1e7, "백만": 1e6, "만": 1e4, "천": 1e3 };
  function parseKoreanAmount(str) {
    var re = /(\d[\d,]*(?:\.\d+)?)\s*(조|억|천만|백만|만|천)?/g;
    var total = 0, matched = false, m;
    while ((m = re.exec(str)) !== null) {
      if (!m[0] || !m[0].trim()) { if (re.lastIndex <= m.index) re.lastIndex = m.index + 1; continue; }
      var n = parseFloat(stripComma(m[1]));
      if (!isNaN(n)) { total += n * (m[2] ? KUNIT_VAL[m[2]] : 1); matched = true; }
    }
    return matched ? total : NaN;
  }

  // 1. $숫자 + 조/억/만 (한국어 모드) — 원본 달러 표기는 그대로, 환산(괄호)만 단위로 끊음
  function convertDollarKoreanUnit(text) {
    var usdRate = rates.USD;
    if (!usdRate || usdRate <= 0) return text;
    var out = text;
    var P = [["조", 1e12], ["억", 1e8], ["만", 1e4]];
    for (var i = 0; i < P.length; i++) {
      (function (unit, mult) {
        out = replaceMatches(out, new RegExp("\\$\\s*" + NUM + "\\s*" + unit, "g"), function (m) {
          var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
          var krw = a * mult * usdRate;
          return m[0] + "(" + formatKRW(krw) + ")";
        });
      })(P[i][0], P[i][1]);
    }
    return out;
  }

  // 2. 원화 → 달러 (원본 통화는 변형하지 않음)
  function convertKRWtoUSD(text) {
    var usdRate = rates.USD;
    if (!usdRate || usdRate <= 0) return text;
    var out = text;
    // 복합 한국어 수사("5억 3천만", "23조 3,486억") + 원 → 달러 (런 전체 합산)
    out = replaceMatches(out, new RegExp("₩?\\s*" + KRUN + "\\s*원", "g"), function (m, fullOut) {
      if (isNumFragmentBefore(fullOut, m)) return null;
      var a = parseKoreanAmount(m[1]); if (isNaN(a)) return null;
      return m[0] + "(" + formatUSDsimple(a / usdRate) + ")";
    });
    var krwUnit = function (pattern, multiplier) {
      out = replaceMatches(out, new RegExp(pattern, "g"), function (m, fullOut) {
        if (isNumFragmentBefore(fullOut, m)) return null;
        var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
        var usd = (a * multiplier) / usdRate;
        return m[0] + "(" + formatUSDsimple(usd) + ")";
      });
    };
    krwUnit("₩?\\s*" + NUM + "\\s*조\\s*원", 1e12);
    krwUnit("₩?\\s*" + NUM + "\\s*억\\s*원", 1e8);
    krwUnit("₩?\\s*" + NUM + "\\s*만\\s*원", 1e4);
    krwUnit("₩?\\s*" + NUM + "\\s*천\\s*원", 1e3);
    // ₩ + 숫자 → 원본 그대로 + 달러 환산
    // 멱등 가드: 뒤에 영어 단위(million/billion…)가 오면 이미 원화 영어 표기(formatWonEnglish)의
    // 일부이므로 건너뜀. 안 그러면 "₩600 million($…)" 재처리 시 "₩600($0) million($…)"로 중복됨.
    out = replaceMatches(out, new RegExp("₩\\s*" + NUM, "g"), function (m, fullOut, end) {
      if (isNumFragmentBefore(fullOut, m)) return null;
      var after = fullOut.slice(end, end + 13).toLowerCase();
      if (after.indexOf(" million") === 0 || after.indexOf(" billion") === 0 ||
          after.indexOf(" trillion") === 0 || after.indexOf(" quadrillion") === 0) return null;
      var krw = parseFloat(stripComma(m[1])); if (isNaN(krw)) return null;
      return m[0] + "(" + formatUSDsimple(krw / usdRate) + ")";
    });
    // 큰 숫자(쉼표 포함) + 원 → 원본 그대로 + 달러
    out = replaceMatches(out, /(\d{1,3}(?:,\d{3})+)\s*원/g, function (m, fullOut) {
      if (isNumFragmentBefore(fullOut, m)) return null;
      var krw = parseFloat(stripComma(m[1])); if (isNaN(krw)) return null;
      return m[0] + "(" + formatUSDsimple(krw / usdRate) + ")";
    });
    return out;
  }

  // 3. 한국어 달러 표현 → 원화 환산 (괄호만 단위로 끊음)
  function convertKoreanDollar(text) {
    var usdRate = rates.USD;
    if (!usdRate || usdRate <= 0) return text;
    var out = text;
    // 복합 한국어 수사("8억 5천만", "4억 3,900만", "152억") + 달러 — 런 전체를 합산해 한 번에 환산
    out = replaceMatches(out, new RegExp(KRUN + "\\s*달러", "g"), function (m) {
      var a = parseKoreanAmount(m[1]); if (isNaN(a)) return null;
      return m[0] + "(" + formatKRW(a * usdRate) + ")";
    });
    // 큰 숫자(쉼표 포함, 단위 없음) + 달러
    out = replaceMatches(out, /(\d{1,3}(?:,\d{3})+)\s*달러/g, function (m) {
      var usd = parseFloat(stripComma(m[1])); if (isNaN(usd)) return null;
      return m[0] + "(" + formatKRW(usd * usdRate) + ")";
    });
    // 작은 숫자(쉼표·단위 없음) + 달러
    out = replaceMatches(out, /(\d+(?:\.\d+)?)\s*달러/g, function (m) {
      var usd = parseFloat(m[1]); if (isNaN(usd)) return null;
      return m[0] + "(" + formatKRW(usd * usdRate) + ")";
    });
    return out;
  }

  // 4. million/billion/trillion + 일반 dollars/euros/pounds
  function convertLargeAmount(text) {
    var out = text, i;
    var symPatterns = [
      ["\\$", "USD", 1e12, "trillion"], ["\\$", "USD", 1e9, "billion"], ["\\$", "USD", 1e6, "million"],
      ["€", "EUR", 1e12, "trillion"], ["€", "EUR", 1e9, "billion"], ["€", "EUR", 1e6, "million"],
      ["£", "GBP", 1e12, "trillion"], ["£", "GBP", 1e9, "billion"], ["£", "GBP", 1e6, "million"]
    ];
    for (i = 0; i < symPatterns.length; i++) {
      (function (sym, code, mult, word) {
        var rate = rates[code]; if (!rate) return;
        out = replaceMatches(out, new RegExp(sym + "\\s*" + NUM + "\\s*" + word, "gi"), function (m) {
          var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
          return m[0] + "(" + formatKRW(a * mult * rate) + ")";
        });
      })(symPatterns[i][0], symPatterns[i][1], symPatterns[i][2], symPatterns[i][3]);
    }
    var wordPatterns = [
      ["USD", 1e12, "trillion", "dollars"], ["USD", 1e9, "billion", "dollars"], ["USD", 1e6, "million", "dollars"],
      ["EUR", 1e12, "trillion", "euros"], ["EUR", 1e9, "billion", "euros"], ["EUR", 1e6, "million", "euros"],
      ["GBP", 1e12, "trillion", "pounds"], ["GBP", 1e9, "billion", "pounds"], ["GBP", 1e6, "million", "pounds"]
    ];
    for (i = 0; i < wordPatterns.length; i++) {
      (function (code, mult, big, cur) {
        var rate = rates[code]; if (!rate) return;
        out = replaceMatches(out, new RegExp(NUM + "\\s*" + big + "\\s*" + cur, "gi"), function (m) {
          var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
          return m[0] + "(" + formatKRW(a * mult * rate) + ")";
        });
      })(wordPatterns[i][0], wordPatterns[i][1], wordPatterns[i][2], wordPatterns[i][3]);
    }
    // "2,000 dollars" (million/billion 없는 일반 숫자 + dollars/euros/pounds)
    var plainPatterns = [["USD", "dollars"], ["EUR", "euros"], ["GBP", "pounds"]];
    for (i = 0; i < plainPatterns.length; i++) {
      (function (code, cur) {
        var rate = rates[code]; if (!rate) return;
        out = replaceMatches(out, new RegExp(NUM + "\\s*" + cur, "gi"), function (m, fullOut) {
          var start = m.index || 0;
          var beforeLower = fullOut.slice(0, start).toLowerCase();
          if (beforeLower.lastIndexOf("million ") === beforeLower.length - 8 ||
              beforeLower.lastIndexOf("billion ") === beforeLower.length - 8 ||
              beforeLower.lastIndexOf("trillion ") === beforeLower.length - 9) {
            return null;
          }
          var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
          return m[0] + "(" + formatKRW(a * rate) + ")";
        });
      })(plainPatterns[i][0], plainPatterns[i][1]);
    }
    return out;
  }

  // 5. 영어 원화 표현 → 달러 ("20 million won")
  function convertEnglishWon(text) {
    var usdRate = rates.USD;
    if (!usdRate || usdRate <= 0) return text;
    var out = text;
    var P = [["trillion", 1e12], ["billion", 1e9], ["million", 1e6]];
    for (var i = 0; i < P.length; i++) {
      (function (big, mult) {
        out = replaceMatches(out, new RegExp(NUM + "\\s*" + big + "\\s*won", "gi"), function (m) {
          var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
          var krw = a * mult;
          return formatWonUnit(krw) + "(" + formatUSDsimple(krw / usdRate) + ")";
        });
      })(P[i][0], P[i][1]);
    }
    // 단순 "숫자 won" (쉼표 있는 숫자만)
    out = replaceMatches(out, /(\d{1,3}(?:,\d{3})+)\s*won/gi, function (m) {
      var a = parseFloat(stripComma(m[1])); if (isNaN(a)) return null;
      return formatWonUnit(a) + "(" + formatUSDsimple(a / usdRate) + ")";
    });
    return out;
  }

  // 6. 일반 외화 기호 → 원화
  function convertForeignToKRW(text) {
    var out = text;
    for (var i = 0; i < SYMBOL_TO_CODE.length; i++) {
      (function (code, sym) {
        var rate = rates[code]; if (!rate) return;
        out = replaceMatches(out, new RegExp(sym + "\\s*" + NUM, "g"), function (m, fullOut, end) {
          var after = fullOut.slice(end, end + 9);
          var al = after.toLowerCase();
          if (al.indexOf(" million") === 0 || al.indexOf(" billion") === 0 || al.indexOf(" trillio") === 0) return null;
          if (after.charAt(0) === "억" || after.charAt(0) === "조" || after.charAt(0) === "만" ||
              after.indexOf(" 억") === 0 || after.indexOf(" 조") === 0 || after.indexOf(" 만") === 0) {
            return null;
          }
          var amount = parseFloat(stripComma(m[1])); if (isNaN(amount)) return null;
          var krw = amount * rate;
          // 달러 큰 금액(긴 숫자)은 영어 단위(million/billion)로 끊어 표시
          var head = code === "USD" && amount >= 1e6 ? formatUSDsimple(amount) : m[0];
          return head + "(" + formatKRW(krw) + ")";
        });
      })(SYMBOL_TO_CODE[i][0], SYMBOL_TO_CODE[i][1]);
    }
    return out;
  }

  // 변환 단계 실행 (데스크탑 applyConversion 순서).
  function runConvert(text) {
    if (!text) return text;
    var o = text;
    o = convertDollarKoreanUnit(o);
    o = convertKRWtoUSD(o);
    o = convertKoreanDollar(o);
    o = convertLargeAmount(o);
    o = convertEnglishWon(o);
    o = convertForeignToKRW(o);
    return o;
  }

  // 전체 적용. lang은 자막 언어('ko'=원화 한글 단위, 그 외=영어 단위).
  function applyConversion(text, lang) {
    activeLang = lang != null ? lang : null;
    try { return runConvert(text); }
    finally { activeLang = null; }
  }

  // 반영 로그용: 변환 결과 + 변경 내역(원본 통화 표현 → 환산 결과)
  function applyConversionWithLog(text, lang) {
    var changes = [];
    activeLang = lang != null ? lang : null;
    activeLog = changes;
    try { return { result: runConvert(text), changes: changes }; }
    finally { activeLang = null; activeLog = null; }
  }

  global.BoothmateCurrency = {
    DEFAULT_RATES: DEFAULT_RATES,
    fetchRates: fetchRates,
    applyConversion: applyConversion,
    applyConversionWithLog: applyConversionWithLog,
    getRates: function () { return rates; },
    getLastUpdated: function () { return lastUpdated; }
  };

  // 로드 시 환율 1회 갱신 (실패해도 기본값으로 동작)
  try { fetchRates(); } catch (e) {}

  // Node 환경(테스트)용
  if (typeof module !== "undefined" && module.exports) {
    module.exports = global.BoothmateCurrency;
  }
})(typeof window !== "undefined" ? window : this);
