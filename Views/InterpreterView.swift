import SwiftUI

/// 통역 메인 화면 (P0 스켈레톤).
/// P1에서 여기에 AVAudioEngine 캡처 → 중계 WebSocket → 2단(원문/번역) 자막을 붙인다.
struct InterpreterView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                Text("Boothmate")
                    .font(.system(size: 28, weight: .bold))
                Text("실시간 통역 · 준비 중")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Text("v2.0 네이티브 재구축 — 통역 코어(P1) 연결 예정")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview {
    InterpreterView()
}
