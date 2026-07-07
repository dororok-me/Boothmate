import SwiftUI

/// 통역 메인 화면.
struct InterpreterView: View {
    @StateObject private var vm = InterpreterViewModel()
    @AppStorage("dev_pass_key") private var devPassKey = ""

    // 표시 설정
    @AppStorage(StyleKey.srcFontSize)   private var srcFontSize: Double = 16
    @AppStorage(StyleKey.transFontSize) private var transFontSize: Double = 22
    @AppStorage(StyleKey.lineSpacing)   private var lineSpacing: Double = 3
    @AppStorage(StyleKey.pairGap)       private var pairGap: Double = 4
    @AppStorage(StyleKey.srcColor)      private var srcColorIdx: Int = 6
    @AppStorage(StyleKey.transColor)    private var transColorIdx: Int = 0
    @AppStorage(StyleKey.bg)            private var bgIdx: Int = 0
    @AppStorage(StyleKey.conv)          private var convEnabled: Bool = true

    @State private var showSettings = false
    @State private var isFullscreen = false

    private var bgEntry: (name: String, color: Color, dark: Bool) { SubtitlePalette.bgEntry(bgIdx) }

    var body: some View {
        ZStack {
            (isFullscreen ? bgEntry.color : Color(.systemBackground)).ignoresSafeArea()

            VStack(spacing: 0) {
                if !isFullscreen {
                    header
                    Divider()
                    menuBox
                    Divider()
                }
                subtitles
                    .frame(maxHeight: .infinity)
                    .background(isFullscreen ? Color.clear : bgEntry.color)
                if let err = vm.errorText {
                    Text(err)
                        .font(.system(size: 12)).foregroundColor(.white)
                        .padding(8).frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.85))
                }
                if !isFullscreen {
                    controlBar
                }
            }

            if isFullscreen && vm.isRunning {
                fullscreenOverlay
            }
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .onAppear { vm.currency.fetchRates() }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 8) {
            Text("Boothmate").font(.system(size: 18, weight: .bold))
            if vm.isRunning, vm.dirMode == .auto {
                Text("→ \(vm.curTarget.label)")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.blue)
            }
            Spacer()
            if let s = vm.secondsLeft {
                Label(timeString(s), systemImage: "clock")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(s < 300 ? .red : .secondary)
            }
            if vm.isRunning {
                iconButton("arrow.up.left.and.arrow.down.right") { withAnimation { isFullscreen = true } }
            }
            iconButton("gearshape") { showSettings = true }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func iconButton(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 메뉴 박스 (언어쌍 · 방향 · 초기화 · 통과키)

    private var menuBox: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Group {
                    langMenu($vm.langA)
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 11)).foregroundColor(.secondary)
                    langMenu($vm.langB)
                    dirMenu
                }
                .disabled(vm.isRunning)   // 녹음 중 언어/방향 변경 방지

                Spacer(minLength: 2)

                Button { vm.clearTranscript() } label: {
                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }

            if !vm.isRunning {
                SecureField("개발용 PASS_KEY (임시)", text: $devPassKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(size: 13))
                    .padding(8)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func langMenu(_ sel: Binding<InterpretLanguage>) -> some View {
        Picker("", selection: sel) {
            ForEach(InterpretLanguage.all) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
        .font(.system(size: 13))
    }

    private var dirMenu: some View {
        Picker("", selection: $vm.dirMode) {
            ForEach(DirMode.allCases) { Text($0.label(vm.langA, vm.langB)).tag($0) }
        }
        .pickerStyle(.menu)
        .font(.system(size: 13))
    }

    // MARK: - 자막 (문장마다 원문+번역 쌍, 정지 후에도 유지)

    private var subtitles: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let pairs = sentencePairs()
                LazyVStack(alignment: .leading, spacing: 16) {
                    if pairs.isEmpty {
                        Text(vm.isRunning ? "말해보세요…" : "‘시작’을 눌러 통역을 시작하세요")
                            .font(.system(size: 14))
                            .foregroundColor(SubtitlePalette.textColor(srcColorIdx, bgDark: bgEntry.dark).opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(pairs.enumerated()), id: \.offset) { item in
                            segmentRow(source: item.element.0,
                                       translation: item.element.1,
                                       live: vm.isRunning && item.offset == pairs.count - 1)
                                .id(item.offset)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .onChange(of: vm.sourceText) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: vm.translationText) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private func segmentRow(source: String, translation: String, live: Bool) -> some View {
        VStack(alignment: .leading, spacing: pairGap) {
            if !source.isEmpty {
                Text(source)
                    .font(.system(size: srcFontSize))
                    .foregroundColor(SubtitlePalette.textColor(srcColorIdx, bgDark: bgEntry.dark))
                    .lineSpacing(lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !translation.isEmpty {
                Text(translation)
                    .font(.system(size: transFontSize, weight: .medium))
                    .foregroundColor(SubtitlePalette.textColor(transColorIdx, bgDark: bgEntry.dark))
                    .lineSpacing(lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(live ? 0.6 : 1)
    }

    /// 원문/번역을 문장으로 나눠 인덱스로 짝짓고, 번역엔 환율·도량형 병기.
    private func sentencePairs() -> [(String, String)] {
        let src = Self.sentences(vm.sourceText)
        let trg = Self.sentences(vm.translationText)
        let n = max(src.count, trg.count)
        guard n > 0 else { return [] }
        var out: [(String, String)] = []
        for i in 0..<n {
            let s = i < src.count ? src[i] : ""
            var t = i < trg.count ? trg[i] : ""
            if convEnabled, !t.isEmpty { t = vm.converted(t) }
            out.append((s, t))
        }
        return out.count > 40 ? Array(out.suffix(40)) : out
    }

    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ".!?。！？…".contains(ch) {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { result.append(s) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    // MARK: - 전체화면 오버레이

    private var fullscreenOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Spacer()
                floatButton("arrow.down.right.and.arrow.up.left") { withAnimation { isFullscreen = false } }
                floatButton("stop.fill", tint: .red) { vm.stop(); isFullscreen = false }
            }
            Spacer()
        }
        .padding(16)
    }

    private func floatButton(_ name: String, tint: Color = .white, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .padding(10)
                .background(Color.black.opacity(0.35))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
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
