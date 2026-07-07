import SwiftUI

/// 자막 표시 설정 저장 키 (@AppStorage에서 공유).
enum StyleKey {
    static let srcFontSize   = "dispSrcFontSize"
    static let transFontSize = "dispTransFontSize"
    static let lineSpacing = "dispLineSpacing"
    static let pairGap     = "dispPairGap"
    static let srcColor    = "dispSrcColor"
    static let transColor  = "dispTransColor"
    static let bg          = "dispBg"
    static let conv        = "dispConvEnabled"
}

/// 자막 색상 팔레트.
enum SubtitlePalette {

    /// 글자색 옵션 (index 0 "기본"은 배경 명암에 맞춰 흑/백으로 자동).
    static let textNames = ["기본", "파랑", "초록", "주황", "빨강", "보라", "회색"]
    static let text: [Color] = [
        .primary,
        .blue,
        Color(red: 0.13, green: 0.6, blue: 0.33),
        .orange,
        .red,
        .purple,
        .gray,
    ]

    /// 배경 프리셋 (name, color, dark=명암).
    static let bg: [(name: String, color: Color, dark: Bool)] = [
        ("기본", Color(.systemBackground), false),
        ("검정", .black, true),
        ("크림", Color(red: 1.0, green: 0.97, blue: 0.86), false),
        ("남색", Color(red: 0.07, green: 0.09, blue: 0.16), true),
    ]

    static func bgEntry(_ idx: Int) -> (name: String, color: Color, dark: Bool) {
        bg[max(0, min(idx, bg.count - 1))]
    }

    /// 글자색 해석. "기본"(0)은 배경이 어두우면 흰색, 밝으면 검정.
    static func textColor(_ idx: Int, bgDark: Bool) -> Color {
        if idx <= 0 { return bgDark ? .white : .black }
        let i = min(idx, text.count - 1)
        return text[i]
    }
}
