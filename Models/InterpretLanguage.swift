import Foundation

/// 통역 언어. rawValue = Gemini translationConfig 코드.
enum InterpretLanguage: String, CaseIterable, Identifiable {
    case ko, en, ja
    case zh          // 中文 (简体)
    case zhTW = "zh-TW"
    case es, fr, de, it, pt, ru, vi, th, ar, hi
    case indo = "id" // Indonesian (case 'id'는 Identifiable.id와 충돌해 indo)

    var id: String { rawValue }

    /// Gemini translationConfig.targetLanguageCode (zh-TW는 그대로, 나머지는 접두 코드).
    var geminiCode: String { rawValue }

    /// 지역 변형 제거한 접두 코드 (감지/비교용).
    var prefix: String { String(rawValue.split(separator: "-").first ?? "") }

    /// UI 표시용 자국어 라벨.
    var label: String {
        switch self {
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        case .zh: return "中文(简)"
        case .zhTW: return "中文(繁)"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .vi: return "Tiếng Việt"
        case .th: return "ไทย"
        case .indo: return "Indonesia"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        }
    }

    /// 지시문에 쓰는 영어 언어명.
    var englishName: String {
        switch self {
        case .ko: return "Korean"
        case .en: return "English"
        case .ja: return "Japanese"
        case .zh: return "Chinese"
        case .zhTW: return "Traditional Chinese"
        case .es: return "Spanish"
        case .fr: return "French"
        case .de: return "German"
        case .it: return "Italian"
        case .pt: return "Portuguese"
        case .ru: return "Russian"
        case .vi: return "Vietnamese"
        case .th: return "Thai"
        case .indo: return "Indonesian"
        case .ar: return "Arabic"
        case .hi: return "Hindi"
        }
    }
}

/// 번역 방향 모드.
enum DirMode: String, CaseIterable, Identifiable {
    case auto   // 양방향 자동 (입력 언어 감지 → 반대 언어로)
    case aToB   // A → B 단방향
    case bToA   // B → A 단방향

    var id: String { rawValue }

    func label(_ a: InterpretLanguage, _ b: InterpretLanguage) -> String {
        switch self {
        case .auto: return "⇄ 자동"
        case .aToB: return "\(a.label) → \(b.label)"
        case .bToA: return "\(b.label) → \(a.label)"
        }
    }
}

/// 스크립트(문자 체계) 기반 간이 언어 감지 — 웹앱 detectLang 이식.
enum LanguageDetector {

    private struct Scripts {
        var ko = false, kana = false, cjk = false, cyr = false
        var arabic = false, hebrew = false, indic = false, thai = false, greek = false, latin = false
    }

    private static func scan(_ text: String) -> Scripts {
        var s = Scripts()
        for u in text.unicodeScalars {
            let v = u.value
            switch v {
            case 0xAC00...0xD7A3: s.ko = true
            case 0x3040...0x30FF, 0x31F0...0x31FF: s.kana = true
            case 0x4E00...0x9FFF: s.cjk = true
            case 0x0400...0x04FF: s.cyr = true
            case 0x0600...0x06FF: s.arabic = true
            case 0x0590...0x05FF: s.hebrew = true
            case 0x0900...0x097F: s.indic = true
            case 0x0E00...0x0E7F: s.thai = true
            case 0x0370...0x03FF: s.greek = true
            case 0x41...0x5A, 0x61...0x7A: s.latin = true
            default: break
            }
        }
        return s
    }

    private static func score(_ prefix: String, _ s: Scripts) -> Int {
        switch prefix {
        case "ko": return s.ko ? 2 : 0
        case "ja": return s.kana ? 2 : (s.cjk ? 1 : 0)
        case "zh": return (s.cjk && !s.kana) ? 2 : 0
        case "ar", "fa", "ur": return s.arabic ? 2 : 0
        case "he": return s.hebrew ? 2 : 0
        case "hi", "bn", "ta", "te": return s.indic ? 2 : 0
        case "th": return s.thai ? 2 : 0
        case "ru", "uk", "bg", "sr": return s.cyr ? 2 : 0
        case "el": return s.greek ? 2 : 0
        default: return s.latin ? 1 : 0   // 라틴 계열(영어 등)
        }
    }

    /// 입력 텍스트가 쌍(a,b) 중 어느 언어인지. 불확실하면 nil.
    static func detect(_ text: String, _ a: InterpretLanguage, _ b: InterpretLanguage) -> InterpretLanguage? {
        let s = scan(text)
        let sa = score(a.prefix, s), sb = score(b.prefix, s)
        if sa > sb { return a }
        if sb > sa { return b }
        return nil
    }

    /// 쌍(a,b)에 없는 강한 스크립트가 섞였는지(=쌍 밖 언어) — 라틴/숫자만이면 false.
    static func isForeignToPair(_ text: String, _ a: InterpretLanguage, _ b: InterpretLanguage) -> Bool {
        let s = scan(text)
        var present: [String] = []
        if s.ko { present.append("hangul") }
        if s.kana { present.append("kana") }
        if s.cjk { present.append("cjk") }
        if s.cyr { present.append("cyr") }
        if s.arabic { present.append("arabic") }
        if s.hebrew { present.append("hebrew") }
        if s.indic { present.append("indic") }
        if s.thai { present.append("thai") }
        if s.greek { present.append("greek") }
        if present.isEmpty { return false }
        let allowed = Set(scripts(a) + scripts(b))
        return present.contains { !allowed.contains($0) }
    }

    private static func scripts(_ lang: InterpretLanguage) -> [String] {
        switch lang.prefix {
        case "ko": return ["hangul"]
        case "ja": return ["kana", "cjk"]
        case "zh": return ["cjk"]
        case "ru", "uk", "bg", "sr": return ["cyr"]
        case "ar", "fa", "ur": return ["arabic"]
        case "he": return ["hebrew"]
        case "hi", "bn", "ta", "te": return ["indic"]
        case "th": return ["thai"]
        case "el": return ["greek"]
        default: return ["latin"]
        }
    }
}
