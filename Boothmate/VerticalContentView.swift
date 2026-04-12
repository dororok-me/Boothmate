import SwiftUI
import Speech
import AVFoundation

struct VerticalContentView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var glossaryStore: GlossaryStore
    @ObservedObject var gmStore: GMStore
    @ObservedObject var subscriptionManager: SubscriptionManager

    // 드래그 비율 상태
    @State private var topRatio: CGFloat = 0.58
    @State private var isDragging: Bool = false
    @State private var handleUnlocked: Bool = false
    @State private var cachedAvailableHeight: CGFloat = 0
    @State private var dragStartRatio: CGFloat = 0
    @State private var isFullscreen: Bool = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isLandscapeMode: Bool = false
    @State private var landscapeSafeLeading: CGFloat = 0
    @State private var landscapeSafeTrailing: CGFloat = 0

    // 하단 탭
    @State private var selectedTab: RightPanelTab = .dictionary
    @State private var memoText: String = ""
    @State private var previewFileURL: URL? = nil
    @State private var previewBookmarkData: Data? = nil

    // 알림 상태
    @State private var showLanguageAlert = false
    @State private var showBoothAlert = false
    @State private var showPaywall = false
    @State private var showGlossarySheet = false
    @State private var showSettingsSheet = false
    @State private var marqueeOffset: CGFloat = 0

    enum RightPanelTab {
        case dictionary, file, memo, gm
        var icon: String {
            switch self {
            case .dictionary: return "text.book.closed"
            case .file:       return "doc"
            case .memo:       return "note.text"
            case .gm:         return "clock.arrow.circlepath"
            }
        }
        var iconFilled: String {
            switch self {
            case .dictionary: return "text.book.closed.fill"
            case .file:       return "doc.fill"
            case .memo:       return "note.text"
            case .gm:         return "clock.arrow.circlepath"
            }
        }
        var activeColor: Color {
            switch self {
            case .dictionary: return Color(red: 0.2, green: 0.5, blue: 1.0)
            case .file:       return Color(red: 1.0, green: 0.5, blue: 0.2)
            case .memo:       return Color(red: 0.4, green: 0.75, blue: 0.4)
            case .gm:         return Color(red: 0.8, green: 0.3, blue: 0.7)
            }
        }
        var label: String {
            switch self {
            case .dictionary: return "사전"
            case .file:       return "파일"
            case .memo:       return "메모"
            case .gm:         return "GM"
            }
        }
    }

    private var boothColor: Color {
        switch speechManager.selectedBooth {
        case .kr: return AppColors.boothKR
        case .cn: return AppColors.boothCN
        case .jp: return AppColors.boothJP
        }
    }

    // 가로모드 드래그
    @State private var leftRatio: CGFloat = 0.6
    @State private var isLandscapeDragging: Bool = false
    @State private var landscapeDragStartRatio: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            Group {
                if landscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .onAppear { isLandscapeMode = landscape }
            .onChange(of: landscape) { newVal in
                isLandscapeMode = newVal
                if !newVal { isFullscreen = false }
            }
        }
    }

    // MARK: - 세로 레이아웃

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let totalHeight = geo.size.height
                let handleHeight: CGFloat = 24
                let availableHeight = totalHeight - handleHeight
                let topHeight = isFullscreen
                    ? totalHeight
                    : min(max(availableHeight * topRatio, availableHeight * 0.2), availableHeight * 0.8)

                VStack(spacing: 0) {
                    subtitlePanel()
                        .frame(height: topHeight)
                        .background(speechManager.selectedTheme.backgroundColor)

                    if !isFullscreen {
                        dragHandle
                            .frame(height: handleHeight)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                    .onChanged { value in
                                        if !isDragging {
                                            isDragging = true
                                            dragStartRatio = topRatio
                                        }
                                        let delta = value.translation.height / availableHeight
                                        topRatio = min(max(dragStartRatio + delta, 0.2), 0.8)
                                    }
                                    .onEnded { _ in isDragging = false }
                            )

                        bottomPanel
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .alert("언어 변경", isPresented: $showLanguageAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 언어를 변경해 주세요")
        }
        .alert("Booth 변경", isPresented: $showBoothAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 Booth를 변경해 주세요")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .interactiveDismissDisabled(!subscriptionManager.canUseApp)
        }
        .sheet(isPresented: $showGlossarySheet) {
            GlossaryView(glossaryStore: glossaryStore)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(speechManager: speechManager)
        }
        .onAppear { if speechManager.isRecording { startMarquee() } }
        .onChange(of: speechManager.isRecording) { if !$0 { marqueeOffset = 0 } }
    }

    // MARK: - 가로 레이아웃

    private var landscapeLayout: some View {
        GeometryReader { geo in
            let safeLeading = max(geo.safeAreaInsets.leading, 59)
            let safeTrailing = geo.safeAreaInsets.trailing
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let handleWidth: CGFloat = 18

            // 실제 콘텐츠 너비 (safeArea 제외한 순수 영역)
            let contentWidth = totalWidth
            let leftWidth = isFullscreen
                ? contentWidth
                : min(max(contentWidth * leftRatio, contentWidth * 0.3), contentWidth * 0.8)
            let rightWidth = contentWidth - leftWidth - handleWidth

            ZStack(alignment: .topLeading) {
                // 배경
                HStack(spacing: 0) {
                    speechManager.selectedTheme.backgroundColor
                        .frame(width: leftWidth + safeLeading)
                    if !isFullscreen {
                        Color(.systemGray5).frame(width: handleWidth)
                        Color(.systemGray6)
                            .frame(width: rightWidth + safeTrailing)
                    }
                }
                .ignoresSafeArea()

                // 콘텐츠
                HStack(spacing: 0) {
                    // 좌측: 자막창 (safeLeading을 내부 패딩으로 전달)
                    subtitlePanel(leadingPadding: safeLeading)
                        .padding(.top, safeTop)
                        .frame(width: leftWidth + safeLeading, height: totalHeight)

                    if !isFullscreen {
                        // 드래그 핸들
                        ZStack {
                            Color(.systemGray5)
                            Rectangle()
                                .fill(isLandscapeDragging ? Color(.systemGray2) : Color(.systemGray4))
                                .frame(width: 1)
                            Image(systemName: "chevron.left.chevron.right")
                                .font(.system(size: 9, weight: isLandscapeDragging ? .semibold : .light))
                                .foregroundColor(isLandscapeDragging ? Color(.systemGray) : Color(.systemGray3))
                                .background(Color(.systemGray5))
                        }
                        .frame(width: handleWidth, height: totalHeight)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                .onChanged { value in
                                    if !isLandscapeDragging {
                                        isLandscapeDragging = true
                                        landscapeDragStartRatio = leftRatio
                                    }
                                    let delta = value.translation.width / contentWidth
                                    leftRatio = min(max(landscapeDragStartRatio + delta, 0.3), 0.8)
                                }
                                .onEnded { _ in isLandscapeDragging = false }
                        )

                        // 우측: 탭 패널 (safeTrailing 포함)
                        VStack(spacing: 0) {
                            landscapeTabBar
                            landscapePanelContent
                        }
                        .padding(.bottom, safeBottom)
                        .frame(width: rightWidth + safeTrailing, height: totalHeight)
                        .background(Color(.systemGray6))
                    }
                }
                .ignoresSafeArea()
            }
        }
        .alert("언어 변경", isPresented: $showLanguageAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 언어를 변경해 주세요")
        }
        .alert("Booth 변경", isPresented: $showBoothAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 Booth를 변경해 주세요")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .interactiveDismissDisabled(!subscriptionManager.canUseApp)
        }
        .sheet(isPresented: $showGlossarySheet) {
            GlossaryView(glossaryStore: glossaryStore)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(speechManager: speechManager)
        }
        .onAppear { if speechManager.isRecording { startMarquee() } }
        .onChange(of: speechManager.isRecording) { if !$0 { marqueeOffset = 0 } }
    }

    // MARK: - 가로 탭바

    private var landscapeTabBar: some View {
        HStack(spacing: 0) {
            ForEach([RightPanelTab.dictionary, .file, .memo, .gm], id: \.label) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon).font(.system(size: 14))
                        Text(tab.label).font(.system(size: 9))
                    }
                    .foregroundColor(selectedTab == tab ? .primary : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color(.systemGray4)), alignment: .bottom)
    }

    @ViewBuilder
    private var landscapePanelContent: some View {
        switch selectedTab {
        case .dictionary: DictionaryView(hideTabs: true)
        case .file:       verticalFilePanel
        case .memo:       MemoPanel(text: $memoText, hideHeader: true)
        case .gm:         GMView(gmStore: gmStore, glossaryStore: glossaryStore, hideHeader: true)
        }
    }

    // MARK: - 상단 자막창

    private func subtitlePanel(leadingPadding: CGFloat = 0) -> some View {
        VStack(spacing: 0) {

            // 상단 우측 툴바
            HStack {
                Spacer()

                // 전체화면 버튼 (가로모드일 때만)
                if isLandscapeMode {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isFullscreen.toggle()
                        }
                    } label: {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isFullscreen ? .blue : speechManager.selectedTheme.iconColor)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(GlowButtonStyle())
                }

                // 일시정지
                Button {
                    guard speechManager.isRecording else { return }
                    if speechManager.isPaused {
                        speechManager.resumeRecording()
                    } else {
                        speechManager.pauseRecording()
                    }
                } label: {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(speechManager.isPaused ? Color.orange : speechManager.selectedTheme.iconColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlowButtonStyle())
                .opacity(speechManager.isRecording ? 1.0 : 0.3)
                .disabled(!speechManager.isRecording)

                Button { showGlossarySheet = true } label: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(speechManager.selectedTheme.iconColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlowButtonStyle())

                Button { speechManager.clearSubtitles() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(speechManager.selectedTheme.iconColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlowButtonStyle())

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

                Button { showSettingsSheet = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(speechManager.selectedTheme.iconColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlowButtonStyle())
            }
            .padding(.leading, 8 + leadingPadding)
            .padding(.trailing, 8)
            .padding(.vertical, 2)

            // 자막 스크롤
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: speechManager.lineSpacing) {
                        Color.clear.frame(height: 8)

                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, subtitle in
                            subtitleBlock(text: subtitle, leadingPadding: leadingPadding).id(index)
                        }

                        if !speechManager.currentText.isEmpty {
                            subtitleBlock(text: speechManager.currentText, leadingPadding: leadingPadding).id("current")
                        }

                        Color.clear.frame(height: 20).id("bottomAnchor")
                    }
                }
                .onChange(of: speechManager.scrollTrigger) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }

            controlBar
                .padding(.vertical, 8)
                .padding(.leading, leadingPadding)
        }
    }

    private func subtitleBlock(text: String, leadingPadding: CGFloat = 0) -> some View {
        TappableText(
            text: text,
            fontSize: speechManager.fontSize,
            textColor: speechManager.selectedTheme.textColor,
            glossaryColor: speechManager.glossaryEnabled
                ? speechManager.glossaryColor.color
                : speechManager.selectedTheme.textColor,
            lineSpacing: speechManager.lineSpacing,
            glossaryEnabled: speechManager.glossaryEnabled,
            fontBold: speechManager.fontBold,
            onTapWord: { word in
                let dicLanguage: String
                switch speechManager.selectedBooth {
                case .kr: dicLanguage = "en-US"
                case .cn: dicLanguage = "zh-CN"
                case .jp: dicLanguage = "ja-JP"
                }
                NotificationCenter.default.post(
                    name: .searchDictionary,
                    object: word,
                    userInfo: ["language": dicLanguage]
                )
                gmStore.add(word: word)
                selectedTab = .dictionary
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16 + leadingPadding)
        .padding(.trailing, 16)
    }

    // MARK: - 컨트롤 바

    private var controlBar: some View {
        ZStack {
            // 중앙: KR [▶] EN
            HStack(spacing: 4) {
                languageButton(index: 0)

                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                        marqueeOffset = 0
                    } else {
                        if !subscriptionManager.canUseApp {
                            showPaywall = true
                        } else {
                            speechManager.startRecording()
                            startMarquee()
                        }
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

            // 우측: 타이머 (고정 위치)
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
        .padding(.vertical, 8)
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
                .id(speechManager.isRecording) // isRecording 바뀔 때 뷰 재생성
        }
        .frame(width: 36, height: 36).clipShape(Circle())
    }

    private var startButtonView: some View {
        ZStack {
            Circle().fill(Color(red: 0.25, green: 0.78, blue: 0.65)).frame(width: 36, height: 36)
            Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        }
    }

    private func startMarquee() {
        // MarqueeText가 자체적으로 애니메이션 처리
    }

    // MARK: - 드래그 핸들

    private var dragHandle: some View {
        ZStack {
            // 배경 (터치 영역 확보)
            Color(.systemBackground)

            // 중앙 실선
            Rectangle()
                .fill(isDragging ? Color(.systemGray2) : Color(.systemGray4))
                .frame(height: 1)
                .animation(.easeInOut(duration: 0.15), value: isDragging)

            // 화살표 아이콘 (실선 위에 배경색으로 끊어줌)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: isDragging ? .semibold : .light))
                .foregroundColor(isDragging ? Color(.systemGray) : Color(.systemGray3))
                .padding(.horizontal, 10)
                .background(Color(.systemBackground))
                .animation(.easeInOut(duration: 0.15), value: isDragging)
        }
    }

    // MARK: - 하단 패널

    @State private var filePickerShown = false

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .dictionary:
                    DictionaryView(hideTabs: true)
                case .file:
                    verticalFilePanel
                case .memo:
                    MemoPanel(text: $memoText, hideHeader: true)
                case .gm:
                    GMView(gmStore: gmStore, glossaryStore: glossaryStore, hideHeader: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(Color(.systemGray6))
    }

    private var verticalFilePanel: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = previewFileURL {
                QuickLookPreview(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Button {
                    filePickerShown = true
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Button {
                        filePickerShown = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 44))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("파일 열기")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $filePickerShown) {
            DocumentPicker { url in previewFileURL = url }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([RightPanelTab.dictionary, .file, .memo, .gm], id: \.label) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                            .font(.system(size: 15, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? tab.activeColor : .gray.opacity(0.6))
                        Text(tab.label)
                            .font(.system(size: 8, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? tab.activeColor : .gray.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 40)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }

    // MARK: - Helpers

    private func sendBoothChangedNotification() {
        let boothLanguage: String
        switch speechManager.selectedBooth {
        case .kr: boothLanguage = "en-US"
        case .cn: boothLanguage = "zh-CN"
        case .jp: boothLanguage = "ja-JP"
        }
        NotificationCenter.default.post(name: .boothChanged, object: boothLanguage)
    }
}

// MARK: - 마퀴 텍스트

struct MarqueeText: View {
    let text: String
    let fontSize: CGFloat = 6
    @State private var offset: CGFloat = 18
    @State private var isRunning = false

    private var textWidth: CGFloat { CGFloat(text.count) * 5.5 + 12 }
    private let duration: Double = 6.0

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
        .onAppear { startLoop() }
        .onDisappear { isRunning = false }
    }

    private func startLoop() {
        isRunning = true
        offset = 18
        animate()
    }

    private func animate() {
        guard isRunning else { return }
        withAnimation(.linear(duration: duration)) {
            offset = 18 - textWidth
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard isRunning else { return }
            offset = 18
            animate()
        }
    }
}
