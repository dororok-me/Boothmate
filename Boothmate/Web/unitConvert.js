/* unitConvert.js — 도량형 환산 후처리 (BoothmateG unitConvert.ts v0.4.0 → JS 포팅)
   원본: BoothmateG_Windows/src/renderer/console/src/unitConvert.ts (v0.4.0)
   자막의 면적 단위를 감지해 괄호로 환산을 덧붙임(평 ↔ ㎡, 양방향, 원본 유지).
   - 한글 복합 단위(2천만 평/3억 평)·영어(20 million pyeong) 인식.
   - 언어별 단위: 한국어=만/억평·㎡, 영어=million/billion pyeong·m².
   API(전역 window.BoothmateUnit):
     applyUnitConversion(text, lang)  applyUnitConversionWithLog(text, lang) */
(function (global) {
  "use strict";

  var PYEONG_TO_SQM = 400 / 121; // ≈ 3.305785
  var SQM_TO_PYEONG = 121 / 400; // ≈ 0.3025

  var activeLog = null;
  // 'ko'(또는 미지정)면 한글 단위(만/억), 그 외(영어 등)면 영어 단위(million/billion)
  var activeLang = null;
  function isKorean() { return activeLang == null || activeLang === "ko"; }

  function countChar(s, c) { var n = 0; for (var i = 0; i < s.length; i++) if (s.charAt(i) === c) n++; return n; }
  // 정수면 그대로, 소수면 1자리. 천 단위 콤마.
  function fmtNum(v) { return (Math.round(v * 10) / 10).toLocaleString("en-US", { maximumFractionDigits: 1 }); }
  function unitNum(n) { return Number.isInteger(n) ? String(n) : n.toFixed(1); }

  // 한글 단위로 끊어 표시. "클수록 뒤를 더 끊기" — 상위 단위 값 100↑면 다음(작은) 단위 생략.
  function koreanUnit(v) {
    var eok = 1e8, man = 1e4;
    if (v >= eok) {
      var e = Math.floor(v / eok);
      var m = Math.floor((v % eok) / man);
      if (e >= 100) return fmtNum(e) + "억";
      return m > 0 ? fmtNum(e) + "억" + fmtNum(m) + "만" : fmtNum(e) + "억";
    }
    if (v >= man) {
      var mn = Math.floor(v / man);
      var r = Math.floor(v % man);
      if (mn >= 100) return fmtNum(mn) + "만";
      return r > 0 ? fmtNum(mn) + "만" + fmtNum(r) : fmtNum(mn) + "만";
    }
    return fmtNum(v);
  }

  // ㎡ 표기(한국어 만/억㎡, 영어 million/billion m²)
  function fmtSqm(v) {
    if (!isKorean()) {
      if (v >= 1e9) return unitNum(v / 1e9) + " billion m²";
      if (v >= 1e6) return unitNum(v / 1e6) + " million m²";
      return fmtNum(v) + " m²";
    }
    return v >= 1e4 ? koreanUnit(v) + "㎡" : fmtNum(v) + "㎡";
  }
  // 평 표기(한국어 만/억평, 영어 million/billion pyeong)
  function fmtPyeong(v) {
    if (!isKorean()) {
      if (v >= 1e9) return unitNum(v / 1e9) + " billion pyeong";
      if (v >= 1e6) return unitNum(v / 1e6) + " million pyeong";
      return fmtNum(v) + " pyeong";
    }
    return v >= 1e4 ? koreanUnit(v) + "평" : fmtNum(v) + "평";
  }

  function replaceMatches(text, regex, fn) {
    var matches = [];
    var m;
    regex.lastIndex = 0;
    while ((m = regex.exec(text)) !== null) {
      matches.push(m);
      if (m.index === regex.lastIndex) regex.lastIndex++;
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
      var rep = fn(mm);
      if (rep == null) continue;
      if (activeLog) activeLog.push({ from: mm[0], to: rep });
      output = output.slice(0, start) + rep + output.slice(end);
    }
    return output;
  }

  function toNum(s) { return parseFloat(String(s).replace(/,/g, "")); }

  var NUM = "(\\d+(?:,\\d+)*(?:\\.\\d+)?)";

  // 평 → ㎡ (한글 복합 단위 + 영어 million/billion + 단순, 원본 유지 + ㎡ 괄호)
  function convertPyeong(text) {
    var o = text, i;
    var krUnits = [["조", 1e12], ["억", 1e8], ["천만", 1e7], ["백만", 1e6], ["만", 1e4], ["천", 1e3]];
    for (i = 0; i < krUnits.length; i++) {
      (function (unit, mul) {
        o = replaceMatches(o, new RegExp(NUM + "\\s*" + unit + "\\s*평(?!방)", "g"), function (m) {
          var n = toNum(m[1]); if (isNaN(n)) return null;
          return m[0] + "(" + fmtSqm(n * mul * PYEONG_TO_SQM) + ")";
        });
      })(krUnits[i][0], krUnits[i][1]);
    }
    var enUnits = [["trillion", 1e12], ["billion", 1e9], ["million", 1e6]];
    for (i = 0; i < enUnits.length; i++) {
      (function (unit, mul) {
        o = replaceMatches(o, new RegExp(NUM + "\\s*" + unit + "\\s*pyeong", "gi"), function (m) {
          var n = toNum(m[1]); if (isNaN(n)) return null;
          return m[0] + "(" + fmtSqm(n * mul * PYEONG_TO_SQM) + ")";
        });
      })(enUnits[i][0], enUnits[i][1]);
    }
    // 단순 평(한글)
    o = replaceMatches(o, new RegExp(NUM + "\\s*평(?!방)", "g"), function (m) {
      var n = toNum(m[1]); if (isNaN(n)) return null;
      return m[0] + "(" + fmtSqm(n * PYEONG_TO_SQM) + ")";
    });
    // 단순 pyeong(영어, 하이픈 허용)
    o = replaceMatches(o, new RegExp(NUM + "\\s*-?\\s*pyeong", "gi"), function (m) {
      var n = toNum(m[1]); if (isNaN(n)) return null;
      return m[0] + "(" + fmtSqm(n * PYEONG_TO_SQM) + ")";
    });
    return o;
  }

  // ㎡ → 평 (영어 million/billion m² + 한글 만/억 ㎡ + 단순, 원본 유지 + 평 괄호)
  function convertSqm(text) {
    var o = text, i;
    var SQM = "(?:㎡|m²|m2|제곱미터|평방미터|square\\s*met(?:er|re)s?)";
    var enUnits = [["trillion", 1e12], ["billion", 1e9], ["million", 1e6]];
    for (i = 0; i < enUnits.length; i++) {
      (function (unit, mul) {
        o = replaceMatches(o, new RegExp(NUM + "\\s*" + unit + "\\s*" + SQM, "gi"), function (m) {
          var n = toNum(m[1]); if (isNaN(n)) return null;
          return m[0] + "(" + fmtPyeong(n * mul * SQM_TO_PYEONG) + ")";
        });
      })(enUnits[i][0], enUnits[i][1]);
    }
    var krUnits = [["조", 1e12], ["억", 1e8], ["천만", 1e7], ["백만", 1e6], ["만", 1e4]];
    for (i = 0; i < krUnits.length; i++) {
      (function (unit, mul) {
        o = replaceMatches(o, new RegExp(NUM + "\\s*" + unit + "\\s*(?:㎡|제곱미터)", "g"), function (m) {
          var n = toNum(m[1]); if (isNaN(n)) return null;
          return m[0] + "(" + fmtPyeong(n * mul * SQM_TO_PYEONG) + ")";
        });
      })(krUnits[i][0], krUnits[i][1]);
    }
    // 단순 ㎡
    o = replaceMatches(o, new RegExp(NUM + "\\s*" + SQM, "gi"), function (m) {
      var n = toNum(m[1]); if (isNaN(n)) return null;
      return m[0] + "(" + fmtPyeong(n * SQM_TO_PYEONG) + ")";
    });
    return o;
  }

  function applyUnitConversion(text, lang) {
    if (!text) return text;
    activeLang = lang != null ? lang : null;
    try {
      var o = text;
      o = convertPyeong(o);
      o = convertSqm(o);
      return o;
    } finally { activeLang = null; }
  }

  // 반영 로그용: 변환 결과 + 변경 내역
  function applyUnitConversionWithLog(text, lang) {
    var changes = [];
    activeLang = lang != null ? lang : null;
    activeLog = changes;
    try {
      var o = text;
      o = convertPyeong(o);
      o = convertSqm(o);
      return { result: o, changes: changes };
    } finally { activeLang = null; activeLog = null; }
  }

  global.BoothmateUnit = {
    applyUnitConversion: applyUnitConversion,
    applyUnitConversionWithLog: applyUnitConversionWithLog
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = global.BoothmateUnit;
  }
})(typeof window !== "undefined" ? window : this);
