import SwiftUI

/// 자막 표시 설정 (글자 크기·줄 간격·원문/번역 간격·색상·환산 토글).
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(StyleKey.srcFontSize)   private var srcFontSize: Double = 16
    @AppStorage(StyleKey.transFontSize) private var transFontSize: Double = 22
    @AppStorage(StyleKey.lineSpacing) private var lineSpacing: Double = 3
    @AppStorage(StyleKey.pairGap)     private var pairGap: Double = 4
    @AppStorage(StyleKey.srcColor)    private var srcColorIdx: Int = 6
    @AppStorage(StyleKey.transColor)  private var transColorIdx: Int = 0
    @AppStorage(StyleKey.bg)          private var bgIdx: Int = 0
    @AppStorage(StyleKey.conv)        private var convEnabled: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section("글자") {
                    stepper("원문 글자 크기", $srcFontSize, range: 10...40, step: 2, suffix: "pt")
                    stepper("번역 글자 크기", $transFontSize, range: 12...48, step: 2, suffix: "pt")
                    stepper("줄 간격", $lineSpacing, range: 0...24, step: 1)
                    stepper("원문·번역 간격", $pairGap, range: 0...32, step: 2)
                }

                Section("색상") {
                    colorRow("번역 글자색", $transColorIdx)
                    colorRow("원문 글자색", $srcColorIdx)
                    bgRow
                }

                Section("변환") {
                    Toggle("환율·도량형 자동 병기", isOn: $convEnabled)
                    Text("자막의 금액·단위 옆에 환산값을 괄호로 표시합니다. (예: $30 million(₩약 402억원))")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }

                Section {
                    Text("미리보기")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    preview
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    // MARK: - 컴포넌트

    private func stepper(_ title: String, _ value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String = "") -> some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            } label: { Image(systemName: "minus.circle.fill").font(.system(size: 24)) }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

            Text("\(Int(value.wrappedValue))\(suffix)")
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .frame(minWidth: 52)

            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            } label: { Image(systemName: "plus.circle.fill").font(.system(size: 24)) }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
        }
    }

    private func colorRow(_ title: String, _ sel: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14))
            HStack(spacing: 12) {
                ForEach(SubtitlePalette.text.indices, id: \.self) { i in
                    Circle()
                        .fill(swatchColor(i))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: sel.wrappedValue == i ? 3 : 0))
                        .onTapGesture { sel.wrappedValue = i }
                }
            }
        }
    }

    /// 팔레트 미리보기용 색 (0 "기본"은 현재 배경 명암 기준).
    private func swatchColor(_ i: Int) -> Color {
        if i == 0 { return SubtitlePalette.bgEntry(bgIdx).dark ? .white : .black }
        return SubtitlePalette.text[i]
    }

    private var bgRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("배경색").font(.system(size: 14))
            HStack(spacing: 12) {
                ForEach(SubtitlePalette.bg.indices, id: \.self) { i in
                    let e = SubtitlePalette.bg[i]
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(e.color)
                            .frame(width: 44, height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.25), lineWidth: 1))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: bgIdx == i ? 3 : 0))
                        Text(e.name).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .onTapGesture { bgIdx = i }
                }
            }
        }
    }

    private var preview: some View {
        let bg = SubtitlePalette.bgEntry(bgIdx)
        return VStack(alignment: .leading, spacing: pairGap) {
            Text("올해 매출은 3천만 달러입니다.")
                .font(.system(size: srcFontSize))
                .foregroundColor(SubtitlePalette.textColor(srcColorIdx, bgDark: bg.dark))
                .lineSpacing(lineSpacing)
            Text(convEnabled
                 ? "This year's revenue is $30 million(₩약 402억원)."
                 : "This year's revenue is $30 million.")
                .font(.system(size: transFontSize, weight: .medium))
                .foregroundColor(SubtitlePalette.textColor(transColorIdx, bgDark: bg.dark))
                .lineSpacing(lineSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(bg.color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
