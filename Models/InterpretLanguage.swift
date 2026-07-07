import Foundation

/// 통역 언어 (P1 최소 세트). 서버 setup의 targetLanguageCode / 지시문에 사용.
enum InterpretLanguage: String, CaseIterable, Identifiable {
    case ko, en, ja, zh

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        case .zh: return "中文"
        }
    }

    /// 지시문에 쓰는 영어 언어명.
    var englishName: String {
        switch self {
        case .ko: return "Korean"
        case .en: return "English"
        case .ja: return "Japanese"
        case .zh: return "Chinese"
        }
    }

    /// Gemini translationConfig.targetLanguageCode.
    var geminiCode: String { rawValue }
}
