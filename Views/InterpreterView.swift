import SwiftUI

/// 통역 메인 화면 (P1).
/// 상단 원문 / 하단 번역 2단 자막 + 시작·정지. 로그인/티켓(P2) 전이라
/// 개발용 통과키(PASS_KEY)로 연결해 실기기에서 통역을 바로 검증한다.
struct InterpreterView: View {
    @StateObject private var vm = InterpreterViewModel()
    @AppStorage("dev_pass_key") private var devPassKey = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.isRunning {
                subtitles
            } else {
                setupPanel
            }
            if let err = vm.errorText {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.85))
            }
            controlBar
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: - 헤더 (제목 + 잔여시간 배지)

    private var header: some View {
        HStack {
            Text("Boothmate")
                .font(.system(size: 18, weight: .bold))
            Spacer()
            if let s = vm.secondsLeft {
                Label(timeString(s), systemImage: "clock")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(s < 300 ? .red : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 시작 전 설정

    private var setupPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                langRow(title: "말하는 언어", selection: $vm.sourceLang)
                langRow(title: "번역 언어", selection: $vm.targetLang)

                VStack(alignment: .leading, spacing: 6) {
                    Text("개발용 통과키 (임시 · P2에서 로그인으로 대체)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    SecureField("PASS_KEY", text: $devPassKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("‘시작’을 누르면 마이크 음성이 실시간으로 전사·번역됩니다.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }

    private func langRow(title: String, selection: Binding<InterpretLanguage>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            Picker(title, selection: selection) {
                ForEach(InterpretLanguage.allCases) { lang in
                    Text(lang.label).tag(lang)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 자막 (상단 원문 / 하단 번역)

    private var subtitles: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                subtitlePane(
                    title: "원문",
                    color: .primary,
                    lines: vm.segments.map { $0.source },
                    live: vm.liveSource
                )
                .frame(height: geo.size.height / 2)

                Divider()

                subtitlePane(
                    title: "번역",
                    color: .blue,
                    lines: vm.segments.map { $0.translation },
                    live: vm.liveTranslation
                )
                .frame(height: geo.size.height / 2)
            }
        }
    }

    private func subtitlePane(title: String, color: Color, lines: [String], live: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            if !line.isEmpty {
                                Text(line)
                                    .font(.system(size: 20))
                                    .foregroundColor(color)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                            }
                        }
                        if !live.isEmpty {
                            Text(live)
                                .font(.system(size: 20))
                                .foregroundColor(color.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("live")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: lines.count) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: live) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - 컨트롤 바

    private var controlBar: some View {
        Button {
            if vm.isRunning { vm.stop() } else { vm.start(passKey: devPassKey) }
        } label: {
            HStack {
                Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                Text(vm.isRunning ? "정지" : "시작")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(vm.isRunning ? Color.red : Color(red: 0.25, green: 0.78, blue: 0.65))
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ sec: Int) -> String {
        String(format: "%02d:%02d", (sec % 3600) / 60, sec % 60)
    }
}

#Preview {
    InterpreterView()
}
