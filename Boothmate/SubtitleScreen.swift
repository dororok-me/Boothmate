import SwiftUI
import Foundation

// MARK: - 자막 화면 (실시간 전사 코어)

struct SubtitleScreen: View {
    @ObservedObject var speechManager: SpeechManager

    @State private var showSettingsSheet = false
    @State private var showLanguageAlert = false
    @State private var isFullscreen = false

    private var boothColor: Color {
        switch speechManager.selectedBooth {
        case .kr: return AppColors.boothKR
        case .cn: return AppColors.boothCN
        case .jp: return AppColors.boothJP
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isFullscreen {
                toolbar
            }

            subtitleScroll

            if !isFullscreen {
                controlBar
                    .padding(.vertical, 8)
            }
        }
        .background(speechManager.selectedTheme.backgroundColor.ignoresSafeArea())
        .alert("언어 변경", isPresented: $showLanguageAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 언어를 변경해 주세요")
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(speechManager: speechManager)
        }
    }

    // MARK: - 상단 툴바

    private var toolbar: some View {
        HStack {
            Spacer()

            // 전체보기 (툴바/컨트롤 숨김)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = true }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(speechManager.selectedTheme.iconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(GlowButtonStyle())

            // 일시정지 (자물쇠)
            Button {
                guard speechManager.isRecording else { return }
                if speechManager.isPaused {
                    speechManager.resumeRecording()
                } else {
                    speechManager.pauseRecording()
                }
            } label: {
                Image(systemName: speechManager.isPaused ? "lock.fill" : "lock.open")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(speechManager.isPaused ? Color.orange : speechManager.selectedTheme.iconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(GlowButtonStyle())
            .opacity(speechManager.isRecording ? 1.0 : 0.3)
            .disabled(!speechManager.isRecording)

            // 폰트 크기
            Button { speechManager.cycleFontSize() } label: {
                HStack(spacing: 1) {
                    Text("−").font(.system(size: 11, weight: .medium))
                    Text("A").font(.system(size: 15, weight: .bold))
                    Text("+").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(speechManager.selectedTheme.iconColor)
                .frame(width: 40, height: 28)
            }
            .buttonStyle(GlowButtonStyle())

            // 자막 지우기
            Button { speechManager.clearSubtitles() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(speechManager.selectedTheme.iconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(GlowButtonStyle())

            // 설정
            Button { showSettingsSheet = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(speechManager.selectedTheme.iconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(GlowButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    // MARK: - 자막 스크롤

    private var subtitleScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: speechManager.lineSpacing) {
                    Color.clear.frame(height: 8)

                    ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, subtitle in
                        subtitleBlock(text: subtitle).id(index)
                    }

                    if !speechManager.currentText.isEmpty {
                        subtitleBlock(text: speechManager.currentText).id("current")
                    }

                    Color.clear.frame(height: 20).id("bottomAnchor")
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: speechManager.scrollTrigger) {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                // 전체보기 상태에서 복귀 버튼
                if isFullscreen {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = false }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
        }
    }

    private func subtitleBlock(text: String) -> some View {
        Text(text)
            .font(.system(size: speechManager.fontSize, weight: speechManager.fontBold ? .bold : .regular))
            .foregroundColor(speechManager.selectedTheme.textColor)
            .lineSpacing(speechManager.lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    // MARK: - 컨트롤 바

    private var controlBar: some View {
        ZStack {
            HStack(spacing: 4) {
                languageButton(index: 0)

                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                    } else {
                        speechManager.startRecording()
                    }
                } label: {
                    ZStack {
                        transcribingView.opacity(speechManager.isRecording ? 1 : 0)
                        startButtonView.opacity(speechManager.isRecording ? 0 : 1)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                languageButton(index: 1)
            }

            HStack {
                Spacer()
                Text(speechManager.isRecording ? String(format: "%02d:%02d",
                     (speechManager.elapsedSeconds % 3600) / 60,
                     speechManager.elapsedSeconds % 60) : "")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 36)
                    .padding(.trailing, 4)
            }
        }
    }

    @ViewBuilder
    private func languageButton(index: Int) -> some View {
        let languages = speechManager.languages
        if index < languages.count {
            let (name, code) = languages[index]
            Button {
                if speechManager.isRecording {
                    showLanguageAlert = true
                } else {
                    speechManager.selectedLanguage = code
                }
            } label: {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(speechManager.selectedLanguage == code
                                ? boothColor
                                : speechManager.selectedTheme.iconColor.opacity(0.12))
                    .foregroundColor(speechManager.selectedLanguage == code
                                     ? .white
                                     : speechManager.selectedTheme.iconColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .opacity(speechManager.isRecording ? 0.4 : 1.0)
        }
    }

    private var transcribingView: some View {
        ZStack {
            Circle().fill(Color.red.opacity(0.85)).frame(width: 36, height: 36)
            MarqueeText(text: "Boothmate transcribing")
                .id(speechManager.isRecording)
        }
        .frame(width: 36, height: 36).clipShape(Circle())
    }

    private var startButtonView: some View {
        ZStack {
            Circle().fill(Color(red: 0.25, green: 0.78, blue: 0.65)).frame(width: 36, height: 36)
            Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        }
    }
}

// MARK: - 마퀴 텍스트

struct MarqueeText: View {
    let text: String
    let fontSize: CGFloat = 6
    @State private var offset: CGFloat = 0
    @State private var isRunning = false
    @State private var timer: Timer? = nil

    private var textWidth: CGFloat { CGFloat(text.count) * 4.2 + 16 }
    private let speed: CGFloat = 28.0
    private let fps: CGFloat = 1.0 / 60.0

    var body: some View {
        ZStack {
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize()
                .offset(x: offset)
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize()
                .offset(x: offset + textWidth)
        }
        .clipped()
        .onAppear { startLoop() }
        .onDisappear { stopLoop() }
    }

    private func startLoop() {
        guard !isRunning else { return }
        isRunning = true
        offset = 0
        timer = Timer.scheduledTimer(withTimeInterval: fps, repeats: true) { _ in
            offset -= speed * fps
            if offset <= -textWidth {
                offset += textWidth
            }
        }
    }

    private func stopLoop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}
