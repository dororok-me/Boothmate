import SwiftUI
import Combine
import UIKit
import Speech
import AVFoundation
import WebKit
import QuickLook
import UniformTypeIdentifiers

// MARK: - 색상 정의

struct AppColors {
    static let menuIcon = Color.primary.opacity(0.9)
    static let boothKR = Color.blue
    static let boothCN = Color.red
    static let boothJP = Color.black
    static let tabDictionary = Color(red: 0.6, green: 0.82, blue: 0.88)
    static let tabFile = Color(red: 0.95, green: 0.78, blue: 0.65)
    static let tabWeb = Color(red: 0.75, green: 0.85, blue: 0.72)
    static let tabMemo = Color(red: 0.88, green: 0.75, blue: 0.92)
    static let tabGM = Color(red: 0.98, green: 0.85, blue: 0.55)
}

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()
    @StateObject private var currencyConverter = CurrencyConverter()
    @StateObject private var gmStore = GMStore()

    @State private var showSettings = false
    @State private var showGlossary = false
    @State private var showLanguageAlert = false
    @State private var showBoothAlert = false
    @State private var marqueeOffset: CGFloat = 0
    @State private var showRightPanel = true
    @State private var boothRefresh = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    enum RightPanelTab: String, CaseIterable {
        case dictionary = "사전"
        case file = "파일"
        case web = "웹"
        case memo = "메모"
        case gm = "GM"

        var icon: String {
            switch self {
            case .dictionary: return "text.book.closed"
            case .file: return "doc"
            case .web: return "globe"
            case .memo: return "note.text"
            case .gm: return "clock.arrow.circlepath"
            }
        }

        var activeColor: Color {
            switch self {
            case .dictionary: return AppColors.tabDictionary
            case .file: return AppColors.tabFile
            case .web: return AppColors.tabWeb
            case .memo: return AppColors.tabMemo
            case .gm: return AppColors.tabGM
            }
        }
    }

    @State private var selectedPanelTab: RightPanelTab = .dictionary
    @State private var previewFileURL: URL? = nil
    @State private var previewBookmarkData: Data? = nil
    @State private var memoText: String = ""

    private var boothColor: Color {
        switch speechManager.selectedBooth {
        case .kr: return AppColors.boothKR
        case .cn: return AppColors.boothCN
        case .jp: return AppColors.boothJP
        }
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let isLandscape = totalWidth > totalHeight
            let safeLeading = geo.safeAreaInsets.leading
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let leftInset: CGFloat = isLandscape ? max(safeLeading, 44) : 0
            let menuBarHeight: CGFloat = 48
            let subtitleWidth = showRightPanel ? totalWidth * 0.65 : totalWidth
            let panelWidth = totalWidth * 0.35

            VStack(spacing: 0) {
                Color(.systemBackground).frame(height: safeTop)

                HStack(spacing: 0) {
                    subtitleArea(leftInset: leftInset)
                        .frame(width: subtitleWidth)
                        .background(speechManager.selectedTheme.backgroundColor)

                    if showRightPanel {
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1)
                        rightPanel
                            .frame(width: panelWidth)
                            .background(Color(.systemBackground))
                    }
                }

                Divider()

                bottomMenuBar(leftInset: leftInset)
                    .frame(height: menuBarHeight)
                    .background(Color(.systemBackground))
                    .id(boothRefresh)

                Color(.systemBackground).frame(height: safeBottom)
            }
            .frame(width: totalWidth, height: totalHeight)
        }
        .ignoresSafeArea()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(speechManager: speechManager)
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(glossaryStore: glossaryStore)
        }
        .onAppear {
            speechManager.glossaryStore = glossaryStore
            speechManager.currencyConverter = currencyConverter
            sendBoothChangedNotification()
            // 권한 요청과 환율 모두 백그라운드에서
            DispatchQueue.global(qos: .utility).async {
                SFSpeechRecognizer.requestAuthorization { _ in }
                AVAudioApplication.requestRecordPermission { _ in }
                Task { @MainActor in
                    currencyConverter.fetchRates()
                }
            }
        }
        .alert("언어 변경", isPresented: $showLanguageAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 언어를 변경해 주세요")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dicTabChanged)) { notification in
            guard let boothLanguage = notification.object as? String else { return }
            switch boothLanguage {
            case "ja-JP":
                speechManager.selectedBooth = .jp
                speechManager.selectedLanguage = BoothMode.jp.defaultLanguage
                speechManager.objectWillChange.send()
                sendBoothChangedNotification()
            case "zh-CN":
                speechManager.selectedBooth = .cn
                speechManager.selectedLanguage = BoothMode.cn.defaultLanguage
                speechManager.objectWillChange.send()
                sendBoothChangedNotification()
            default:
                speechManager.selectedBooth = .kr
                speechManager.selectedLanguage = BoothMode.kr.defaultLanguage
                speechManager.objectWillChange.send()
                sendBoothChangedNotification()
            }
        }
        .alert("Booth 변경", isPresented: $showBoothAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("녹음을 정지한 후 Booth를 변경해 주세요")
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            panelTabBar
            panelContent
        }
    }

    private var panelTabBar: some View {
        HStack(spacing: 0) {
            panelTabButton(tab: .dictionary)
            panelTabButton(tab: .file)
            panelTabButton(tab: .web)
            panelTabButton(tab: .memo)
            panelTabButton(tab: .gm)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.04))
    }

    private func panelTabButton(tab: RightPanelTab) -> some View {
        let isSelected = selectedPanelTab == tab
        return Button {
            selectedPanelTab = tab
        } label: {
            HStack(spacing: 2) {
                Image(systemName: tab.icon).font(.system(size: 10))
                Text(tab.rawValue).font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(isSelected ? Color(.systemBackground) : Color.clear)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? .primary : .gray)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch selectedPanelTab {
        case .dictionary: DictionaryView()
        case .file: FilePreviewPanel(fileURL: $previewFileURL, bookmarkData: $previewBookmarkData)
        case .web: WebBrowserPanel()
        case .memo: MemoPanel(text: $memoText)
        case .gm: GMView(gmStore: gmStore, glossaryStore: glossaryStore)
        }
    }

    // MARK: - Booth 변경 알림

    private func sendBoothChangedNotification() {
        let boothLanguage: String
        switch speechManager.selectedBooth {
        case .kr: boothLanguage = "en-US"
        case .cn: boothLanguage = "zh-CN"
        case .jp: boothLanguage = "ja-JP"
        }
        NotificationCenter.default.post(name: .boothChanged, object: boothLanguage)
    }

    // MARK: - Bottom Menu Bar

    private func bottomMenuBar(leftInset: CGFloat) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 0) {
                Text("Boothmate")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                Text("v1.0")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }

            recordButton
            languageToggle

            Button { speechManager.clearSubtitles() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.menuIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GlowButtonStyle())

            Button { showGlossary = true } label: {
                Image(systemName: "textformat.abc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.menuIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GlowButtonStyle())

            Button { speechManager.cycleFontSize() } label: {
                HStack(spacing: 2) {
                    Text("−").font(.system(size: 13, weight: .medium))
                    Text("A").font(.system(size: 18, weight: .bold))
                    Text("+").font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(AppColors.menuIcon)
                .frame(width: 44, height: 32)
            }
            .buttonStyle(GlowButtonStyle())

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.menuIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GlowButtonStyle())

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRightPanel.toggle()
                }
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.menuIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GlowButtonStyle())

            Spacer()

            if speechManager.isRecording {
                timerView
            }
        }
        .padding(.leading, 12 + leftInset)
        .padding(.trailing, 12)
    }

    private var timerView: some View {
        Text(String(format: "%02d:%02d:%02d",
             speechManager.elapsedSeconds / 3600,
             (speechManager.elapsedSeconds % 3600) / 60,
             speechManager.elapsedSeconds % 60))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.gray)
            .padding(.trailing, 4)
    }

    // MARK: - Booth Toggle

    private var boothToggle: some View {
        Button {
            if speechManager.isRecording {
                showBoothAlert = true
            } else {
                speechManager.selectedBooth = speechManager.selectedBooth.next
                speechManager.selectedLanguage = speechManager.selectedBooth.defaultLanguage
                sendBoothChangedNotification()
            }
        } label: {
            Text(speechManager.selectedBooth.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(boothColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .opacity(speechManager.isRecording ? 0.4 : 1.0)
    }

    // MARK: - Language Toggle

    private var languageToggle: some View {
        HStack(spacing: 0) {
            ForEach(speechManager.languages, id: \.1) { name, code in
                Button {
                    if speechManager.isRecording {
                        showLanguageAlert = true
                    } else {
                        speechManager.selectedLanguage = code
                    }
                } label: {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 28)
                        .background(speechManager.selectedLanguage == code ? boothColor : Color.clear)
                        .foregroundColor(speechManager.selectedLanguage == code ? .white : .primary)
                }
            }
        }
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(speechManager.isRecording ? 0.4 : 1.0)
    }

    // MARK: - Record Button

    // MARK: - Record Button

        private var recordButton: some View {
            HStack(spacing: 6) {
                // Start / Stop 버튼 (원형)
                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                        marqueeOffset = 0
                    } else {
                        speechManager.startRecording()
                        startMarquee()
                    }
                } label: {
                    if speechManager.isRecording {
                        transcribingView
                    } else {
                        startButtonView
                    }
                }
                .buttonStyle(.plain)

                // Pause 버튼 (항상 보임)
                pauseResumeButton
            }
        }

        private var pauseResumeButton: some View {
            Button {
                if speechManager.isRecording {
                    if speechManager.isPaused {
                        speechManager.resumeRecording()
                    } else {
                        speechManager.pauseRecording()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(speechManager.isPaused ? Color(red: 0.9, green: 0.2, blue: 0.5) : Color.gray.opacity(0.25))
                        .frame(width: 36, height: 36)

                    if speechManager.isPaused {
                        Text("||")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
            .opacity(speechManager.isRecording ? 1.0 : 0.3)
            .disabled(!speechManager.isRecording)
        }

        private var transcribingView: some View {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 36, height: 36)

                // 두 개의 텍스트로 자연스럽게 연속 흐르기
                ZStack {
                    Text("Transcribing")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .fixedSize()
                        .offset(x: marqueeOffset)

                    Text("Transcribing")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .fixedSize()
                        .offset(x: marqueeOffset + 100)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        }

        private var startButtonView: some View {
            ZStack {
                Circle()
                    .fill(Color(red: 0.25, green: 0.78, blue: 0.65))
                    .frame(width: 36, height: 36)

                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
        }

        private func startMarquee() {
            marqueeOffset = 30
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                marqueeOffset = -70
            }
        }

    // MARK: - Subtitle Area

    private func subtitleArea(leftInset: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: speechManager.lineSpacing) {
                        Color.clear.frame(height: 20)

                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, subtitle in
                            subtitleBlock(text: subtitle, leftInset: leftInset)
                                .id(index)
                        }

                        if !speechManager.currentText.isEmpty {
                            subtitleBlock(text: speechManager.currentText, leftInset: leftInset)
                                .id("current")
                        }

                        Color.clear.frame(height: 30).id("bottomAnchor")
                    }
                }
                .onChange(of: speechManager.scrollTrigger) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }

            // 세로 모드 안내
            if verticalSizeClass == .regular {
                Text("이 앱은\n가로 모드에\n최적화되어\n있습니다")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary.opacity(0.25))
                    .rotationEffect(.degrees(90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Subtitle Block

    private func subtitleBlock(text: String, leftInset: CGFloat) -> some View {
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
                // GM에 검색 기록 저장
                gmStore.add(word: word)
                if !showRightPanel {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRightPanel = true
                    }
                }
                selectedPanelTab = .dictionary
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20 + leftInset)
        .padding(.trailing, 20)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

// MARK: - 메모 패널

struct MemoPanel: View {
    @Binding var text: String
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("메모").font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                Spacer()
                Text("\(text.count)자").font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.08))

            TextEditor(text: $text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 6)
                .padding(.top, 4)
        }
    }
}

// MARK: - 파일 프리뷰 패널

struct FilePreviewPanel: View {
    @Binding var fileURL: URL?
    @Binding var bookmarkData: Data?
    @State private var showFilePicker = false
    @State private var previewID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            fileHeader
            fileContent
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { url in
                if let bookmark = try? url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil, relativeTo: nil
                ) { bookmarkData = bookmark }
                fileURL = url
                previewID = UUID()
            }
        }
    }

    private var fileHeader: some View {
        HStack {
            if let url = fileURL {
                Image(systemName: iconForFile(url)).font(.system(size: 12)).foregroundColor(.blue)
                Text(url.lastPathComponent).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button { showFilePicker = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder").font(.system(size: 12))
                    Text("파일 열기").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.08))
    }

    @ViewBuilder
    private var fileContent: some View {
        if let url = resolveFileURL() {
            QuickLookPreview(url: url).id(previewID)
        } else {
            VStack {
                Spacer()
                Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.gray.opacity(0.4)).padding(.bottom, 8)
                Text("파일을 선택하세요").font(.system(size: 14)).foregroundColor(.gray)
                Spacer()
            }
        }
    }

    private func resolveFileURL() -> URL? {
        if let url = fileURL {
            if url.startAccessingSecurityScopedResource() { return url }
        }
        if let data = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                if isStale {
                    bookmarkData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                }
                fileURL = url
                return url
            }
        }
        return nil
    }

    private func iconForFile(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "rectangle.stack"
        case "txt", "rtf": return "doc.plaintext"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo"
        case "csv": return "tablecells"
        default: return "doc"
        }
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController(); c.dataSource = context.coordinator; return c
    }
    func updateUIViewController(_ c: QLPreviewController, context: Context) {
        context.coordinator.url = url; c.reloadData()
    }
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as QLPreviewItem }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .plainText, .rtf, .spreadsheet, .presentation, .image, .data])
        picker.delegate = context.coordinator; picker.allowsMultipleSelection = false; return picker
    }
    func updateUIViewController(_ c: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { _ = url.startAccessingSecurityScopedResource(); onPick(url) }
        }
    }
}

// MARK: - 웹 브라우저 패널

struct WebBrowserPanel: View {
    @State private var urlText: String = ""
    @State private var currentURL: URL? = nil
    @State private var customLinks: [(String, String)] = []
    @State private var showAddLink = false
    @State private var newLinkTitle = ""
    @State private var newLinkURL = ""

    private let defaultLinks: [(String, String, String)] = [
        ("🔍", "Google", "https://www.google.com"),
        ("📗", "N사전", "https://m.dict.naver.com"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            urlInputBar
            quickLinkBar

            if let url = currentURL {
                WebBrowserWebView(url: url)
            } else {
                emptyWebView
            }
        }
    }

    private var urlInputBar: some View {
        HStack(spacing: 6) {
            TextField("URL 입력", text: $urlText)
                .font(.system(size: 12))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit { loadURL() }
            Button { loadURL() } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var quickLinkBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 기본 바로가기
            ForEach(defaultLinks, id: \.1) { emoji, title, url in
                Button {
                    urlText = url
                    currentURL = URL(string: url)
                } label: {
                    HStack(spacing: 4) {
                        Text(emoji).font(.system(size: 11))
                        Text(title).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }

            // 커스텀 바로가기
            ForEach(customLinks.indices, id: \.self) { i in
                Button {
                    let raw = customLinks[i].1
                    let url = raw.hasPrefix("http") ? raw : "https://" + raw
                    urlText = url
                    currentURL = URL(string: url)
                } label: {
                    HStack(spacing: 4) {
                        Text("🔗").font(.system(size: 11))
                        Text(customLinks[i].0).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        customLinks.remove(at: i)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }

            // + 추가 버튼
            Button {
                newLinkTitle = ""
                newLinkURL = ""
                showAddLink = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                    Text("추가").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("바로가기 추가", isPresented: $showAddLink) {
            TextField("이름", text: $newLinkTitle)
            TextField("URL (예: google.com)", text: $newLinkURL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("추가") {
                let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty && !url.isEmpty {
                    customLinks.append((title, url))
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private var emptyWebView: some View {
        VStack {
            Spacer()
            Image(systemName: "globe").font(.system(size: 32)).foregroundColor(.gray.opacity(0.4)).padding(.bottom, 8)
            Text("URL을 입력하세요").font(.system(size: 14)).foregroundColor(.gray)
            Spacer()
        }
    }

    private func loadURL() {
        var input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if !input.hasPrefix("http://") && !input.hasPrefix("https://") { input = "https://" + input }
        if let url = URL(string: input) { currentURL = url }
    }
}

struct WebBrowserWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(); w.allowsBackForwardNavigationGestures = true
        w.scrollView.keyboardDismissMode = .onDrag; w.load(URLRequest(url: url)); return w
    }
    func updateUIView(_ w: WKWebView, context: Context) {
        if w.url?.absoluteString != url.absoluteString { w.load(URLRequest(url: url)) }
    }
}

// MARK: - Glow Button Style

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed
                          ? Color.blue.opacity(0.15)
                          : Color.clear)
                    .blur(radius: configuration.isPressed ? 4 : 0)
            )
            .shadow(
                color: configuration.isPressed ? Color.blue.opacity(0.5) : Color.clear,
                radius: configuration.isPressed ? 8 : 0
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
