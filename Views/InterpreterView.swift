import SwiftUI

/// 통역 메인 화면 (P1.5 — 언어쌍 + 방향 자동/수동).
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

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 8) {
            Text("Boothmate").font(.system(size: 18, weight: .bold))
            if vm.isRunning {
                Text("\(vm.langA.label) ⇄ \(vm.langB.label)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if vm.dirMode == .auto {
                    Text("→ \(vm.curTarget.label)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
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

    // MARK: - 시작 전 설정 (언어쌍 + 방향)

    private var setupPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                Text("언어쌍")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                HStack(spacing: 10) {
                    langMenu(selection: $vm.langA)
                    Image(systemName: "arrow.left.arrow.right").foregroundColor(.secondary)
                    langMenu(selection: $vm.langB)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("번역 방향")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                    Picker("방향", selection: $vm.dirMode) {
                        ForEach(DirMode.allCases) { m in
                            Text(m.label(vm.langA, vm.langB)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(dirHint)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("개발용 통과키 (임시 · P2에서 로그인으로 대체)")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    SecureField("PASS_KEY", text: $devPassKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
    }

    private func langMenu(selection: Binding<InterpretLanguage>) -> some View {
        Picker("", selection: selection) {
            ForEach(InterpretLanguage.all) { lang in
                Text(lang.label).tag(lang)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dirHint: String {
        switch vm.dirMode {
        case .auto: return "말하는 언어를 자동 인식해 양방향으로 번역합니다."
        case .aToB: return "\(vm.langA.label) 음성만 \(vm.langB.label)(으)로 번역합니다."
        case .bToA: return "\(vm.langB.label) 음성만 \(vm.langA.label)(으)로 번역합니다."
        }
    }

    // MARK: - 자막 (문장마다 원문+번역 쌍으로 누적)

    private var subtitles: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(vm.segments) { seg in
                        segmentRow(source: seg.source, translation: seg.translation)
                            .id(seg.id)
                    }
                    if !vm.liveSource.isEmpty || !vm.liveTranslation.isEmpty {
                        segmentRow(source: vm.liveSource, translation: vm.liveTranslation, live: true)
                            .id("live")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .onChange(of: vm.segments.count) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: vm.liveSource) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: vm.liveTranslation) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    /// 한 문장 = 원문(작게, 보조색) + 번역(크게, 강조) 한 쌍.
    private func segmentRow(source: String, translation: String, live: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !source.isEmpty {
                Text(source)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !translation.isEmpty {
                Text(translation)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue.opacity(live ? 0.35 : 0.6))
                .frame(width: 3)
        }
        .opacity(live ? 0.6 : 1)
    }

    // MARK: - 컨트롤 바

    private var controlBar: some View {
        Button {
            if vm.isRunning { vm.stop() } else { vm.start(passKey: devPassKey) }
        } label: {
            HStack {
                Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                Text(vm.isRunning ? "정지" : "시작").font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
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
