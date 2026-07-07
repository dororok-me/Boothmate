import Foundation

/// 통역 언어. gemini-live-translate 지원 언어 (웹앱 LANGUAGES 이식).
struct InterpretLanguage: Identifiable, Hashable {
    let code: String        // 예: "ko", "zh-TW", "es-MX"
    let label: String       // 자국어 표기(UI)
    let englishName: String // 지시문용 영어명

    var id: String { code }

    /// 지역 변형 제거한 접두 코드 (감지/비교용).
    var prefix: String { String(code.split(separator: "-").first ?? "") }

    /// Gemini translationConfig.targetLanguageCode.
    /// 지역 변형(es-MX 등)은 미지원 코드 오류를 피하려 기본 코드(es)로 보낸다.
    /// (지역 말투는 systemInstruction의 englishName이 담당.) zh-TW는 그대로.
    var geminiCode: String { code == "zh-TW" ? "zh-TW" : prefix }

    static func byCode(_ c: String) -> InterpretLanguage {
        all.first { $0.code == c } ?? all[0]
    }

    // 자주 쓰는 기본값
    static let ko = byCode("ko")
    static let en = byCode("en")

    /// 지원 언어 전체 (웹앱과 동일 세트).
    static let all: [InterpretLanguage] = [
        .init(code: "ko",     label: "한국어",                    englishName: "Korean"),
        .init(code: "en",     label: "English",                   englishName: "English"),
        .init(code: "ja",     label: "日本語",                    englishName: "Japanese"),
        .init(code: "zh",     label: "中文 (简体)",               englishName: "Chinese"),
        .init(code: "zh-TW",  label: "中文 (繁體)",               englishName: "Traditional Chinese"),
        .init(code: "es",     label: "Español",                   englishName: "Spanish"),
        .init(code: "es-MX",  label: "Español (México)",          englishName: "Mexican Spanish"),
        .init(code: "es-AR",  label: "Español (Argentina)",       englishName: "Argentine Spanish"),
        .init(code: "es-419", label: "Español (Latinoamérica)",   englishName: "Latin American Spanish"),
        .init(code: "fr",     label: "Français",                  englishName: "French"),
        .init(code: "de",     label: "Deutsch",                   englishName: "German"),
        .init(code: "it",     label: "Italiano",                  englishName: "Italian"),
        .init(code: "pt",     label: "Português",                 englishName: "Portuguese"),
        .init(code: "pt-BR",  label: "Português (Brasil)",        englishName: "Brazilian Portuguese"),
        .init(code: "ru",     label: "Русский",                   englishName: "Russian"),
        .init(code: "nl",     label: "Nederlands",                englishName: "Dutch"),
        .init(code: "pl",     label: "Polski",                    englishName: "Polish"),
        .init(code: "tr",     label: "Türkçe",                    englishName: "Turkish"),
        .init(code: "vi",     label: "Tiếng Việt",                englishName: "Vietnamese"),
        .init(code: "th",     label: "ไทย",                       englishName: "Thai"),
        .init(code: "id",     label: "Bahasa Indonesia",          englishName: "Indonesian"),
        .init(code: "ms",     label: "Bahasa Melayu",             englishName: "Malay"),
        .init(code: "hi",     label: "हिन्दी",                     englishName: "Hindi"),
        .init(code: "bn",     label: "বাংলা",                     englishName: "Bengali"),
        .init(code: "ta",     label: "தமிழ்",                     englishName: "Tamil"),
        .init(code: "te",     label: "తెలుగు",                    englishName: "Telugu"),
        .init(code: "ur",     label: "اردو",                      englishName: "Urdu"),
        .init(code: "ar",     label: "العربية",                   englishName: "Arabic"),
        .init(code: "he",     label: "עברית",                     englishName: "Hebrew"),
        .init(code: "fa",     label: "فارسی",                     englishName: "Persian"),
        .init(code: "uk",     label: "Українська",                englishName: "Ukrainian"),
        .init(code: "cs",     label: "Čeština",                   englishName: "Czech"),
        .init(code: "sk",     label: "Slovenčina",                englishName: "Slovak"),
        .init(code: "ro",     label: "Română",                    englishName: "Romanian"),
        .init(code: "hu",     label: "Magyar",                    englishName: "Hungarian"),
        .init(code: "el",     label: "Ελληνικά",                  englishName: "Greek"),
        .init(code: "bg",     label: "Български",                 englishName: "Bulgarian"),
        .init(code: "hr",     label: "Hrvatski",                  englishName: "Croatian"),
        .init(code: "sr",     label: "Српски",                    englishName: "Serbian"),
        .init(code: "sl",     label: "Slovenščina",               englishName: "Slovenian"),
        .init(code: "sv",     label: "Svenska",                   englishName: "Swedish"),
        .init(code: "da",     label: "Dansk",                     englishName: "Danish"),
        .init(code: "fi",     label: "Suomi",                     englishName: "Finnish"),
        .init(code: "nb",     label: "Norsk",                     englishName: "Norwegian"),
        .init(code: "is",     label: "Íslenska",                  englishName: "Icelandic"),
        .init(code: "et",     label: "Eesti",                     englishName: "Estonian"),
        .init(code: "lv",     label: "Latviešu",                  englishName: "Latvian"),
        .init(code: "lt",     label: "Lietuvių",                  englishName: "Lithuanian"),
        .init(code: "fil",    label: "Filipino",                  englishName: "Filipino"),
        .init(code: "sw",     label: "Kiswahili",                 englishName: "Swahili"),
        .init(code: "af",     label: "Afrikaans",                 englishName: "Afrikaans"),
        .init(code: "ca",     label: "Català",                    englishName: "Catalan"),
        .init(code: "gl",     label: "Galego",                    englishName: "Galician"),
        .init(code: "eu",     label: "Euskara",                   englishName: "Basque"),
    ]
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
            switch u.value {
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
}
