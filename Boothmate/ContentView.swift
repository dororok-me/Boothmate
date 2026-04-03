import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()

    @State private var horizontalSplit: CGFloat = 0.42
    @State private var leftVerticalSplit: CGFloat = 0.62
    @State private var rightVerticalSplit: CGFloat = 0.50

    @State private var showSettings = false
    @State private var showGlossary = false
    @State private var menuExpanded = false
    @State private var isDraggingBar = false
    @State private var showLanguageAlert = false

    @State private var floatingBarOffset: CGSize = .zero
    @State private var floatingBarDragOffset: CGSize = .zero

    @State private var horizontalSplitDragStart: CGFloat?
    @State private var leftVerticalSplitDragStart: CGFloat?
    @State private var rightVerticalSplitDragStart: CGFloat?

    private let dividerHitThickness: CGFloat = 28
    private let visibleDividerThickness: CGFloat = 1
    private let minPaneWidth: CGFloat = 90
    private let minPaneHeight: CGFloat = 28
    private let topBarHeight: CGFloat = 50

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let totalHeight = geo.size.height
                let safeTop = geo.safeAreaInsets.top
                let safeLeading = geo.safeAreaInsets.leading
                let isLandscape = totalWidth > totalHeight
                let leftDangerInset: CGFloat = isLandscape ? max(safeLeading, 44) : 0
                let topSafeSpacing = safeTop + 8

                let leftWidth = clamp(
                    value: (totalWidth - dividerHitThickness) * horizontalSplit,
                    minValue: minPaneWidth,
                    maxValue: totalWidth - dividerHitThickness - minPaneWidth
                )
                let rightWidth = totalWidth - leftWidth - dividerHitThickness

                let leftContentHeight = totalHeight - topSafeSpacing - topBarHeight - dividerHitThickness
                let rightContentHeight = totalHeight - dividerHitThickness

                let leftTopHeight = clamp(
                    value: leftContentHeight * leftVerticalSplit,
                    minValue: minPaneHeight,
                    maxValue: leftContentHeight - minPaneHeight
                )
                let leftBottomHeight = leftContentHeight - leftTopHeight

                let rightTopHeight = clamp(
                    value: rightContentHeight * rightVerticalSplit,
                    minValue: minPaneHeight,
                    maxValue: rightContentHeight - minPaneHeight
                )
                let rightBottomHeight = rightContentHeight - rightTopHeight

                HStack(spacing: 0) {
                    // MARK: - 왼쪽: 자막 + 메모
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: topBarHeight)
                            .padding(.top, topSafeSpacing)

                        subtitleArea(leftDangerInset: leftDangerInset)
                            .frame(width: leftWidth, height: leftTopHeight)
                            .background(speechManager.selectedTheme.backgroundColor)

                        horizontalDragHandle
                            .frame(width: leftWidth, height: dividerHitThickness)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                    .onChanged { value in
                                        if leftVerticalSplitDragStart == nil {
                                            leftVerticalSplitDragStart = leftVerticalSplit
                                        }
                                        guard let start = leftVerticalSplitDragStart else { return }
                                        let delta = value.translation.height / leftContentHeight
                                        withTransaction(Transaction(animation: nil)) {
                                            leftVerticalSplit = clamp(
                                                value: start + delta,
                                                minValue: minPaneHeight / leftContentHeight,
                                                maxValue: 1 - (minPaneHeight / leftContentHeight)
                                            )
                                        }
                                    }
                                    .onEnded { _ in leftVerticalSplitDragStart = nil }
                            )

                        MemoView()
                            .frame(width: leftWidth, height: leftBottomHeight)
                            .background(Color(.systemBackground))
                    }

                    // MARK: - 좌우 드래그 핸들
                    verticalDragHandle
                        .frame(width: dividerHitThickness, height: totalHeight)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { value in
                                    if horizontalSplitDragStart == nil {
                                        horizontalSplitDragStart = horizontalSplit
                                    }
                                    guard let start = horizontalSplitDragStart else { return }
                                    let delta = value.translation.width / (totalWidth - dividerHitThickness)
                                    withTransaction(Transaction(animation: nil)) {
                                        horizontalSplit = clamp(
                                            value: start + delta,
                                            minValue: minPaneWidth / (totalWidth - dividerHitThickness),
                                            maxValue: 1 - (minPaneWidth / (totalWidth - dividerHitThickness))
                                        )
                                    }
                                }
                                .onEnded { _ in horizontalSplitDragStart = nil }
                        )

                    // MARK: - 오른쪽: 파일뷰어 + 사전
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottomLeading) { // 좌측 하단 정렬
                            FileViewerView()
                                .frame(width: rightWidth, height: rightTopHeight)
                                .background(Color(.systemBackground))

                            // 추가된 파일 열기(+) 버튼
                            Button {
                                pickFileFromFloating()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(Color.white)) // 가독성을 위해 흰색 배경 추가
                                    .shadow(radius: 2)
                            }
                            .padding(.leading, 12)  // 좌측 여백
                            .padding(.bottom, 12)   // 하단 여백(드래그 핸들과 겹치지 않게 조절)
                            .buttonStyle(.plain)
                        }

                        horizontalDragHandle
                            .frame(width: rightWidth, height: dividerHitThickness)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                    .onChanged { value in
                                        if rightVerticalSplitDragStart == nil {
                                            rightVerticalSplitDragStart = rightVerticalSplit
                                        }
                                        guard let start = rightVerticalSplitDragStart else { return }
                                        let delta = value.translation.height / rightContentHeight
                                        withTransaction(Transaction(animation: nil)) {
                                            rightVerticalSplit = clamp(
                                                value: start + delta,
                                                minValue: minPaneHeight / rightContentHeight,
                                                maxValue: 1 - (minPaneHeight / rightContentHeight)
                                            )
                                        }
                                    }
                                    .onEnded { _ in rightVerticalSplitDragStart = nil }
                            )

                        DictionaryView()
                            .frame(width: rightWidth, height: rightBottomHeight)
                            .background(Color(.systemBackground))
                    }
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
            .onAppear {
                speechManager.requestPermissions()
                speechManager.glossaryStore = glossaryStore
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(speechManager: speechManager)
            }
            .sheet(isPresented: $showGlossary) {
                GlossaryView(glossaryStore: glossaryStore)
            }

            // MARK: - 플로팅 메뉴바
            floatingMenuBar

            // 언어 경고 alert (ZStack 최상위, sheet와 분리)
            Color.clear
                .frame(width: 0, height: 0)
                .alert("언어 변경", isPresented: $showLanguageAlert) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text("녹음을 정지한 후 언어를 변경해 주세요")
                }
        }
    }

    // MARK: - Floating Menu Bar

    private var floatingMenuBar: some View {
        let totalOffset = CGSize(
            width: floatingBarOffset.width + floatingBarDragOffset.width,
            height: floatingBarOffset.height + floatingBarDragOffset.height
        )

        return HStack(spacing: 8) {
            Group {
                // Boothmate 로고
                VStack(spacing: 0) {
                    Text("Boothmate")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Text("v1.0")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                }

                // 1. Start/Stop
                recordButton

                // 2. 언어 토글
                languageToggle

                // 3. 지우기
                Button {
                    speechManager.clearSubtitles()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                // 4. 글로서리
                Button { showGlossary = true } label: {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                // 5. 확장 화살표
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        menuExpanded.toggle()
                    }
                } label: {
                    Image(systemName: menuExpanded ? "chevron.left" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 32)
                }
                .buttonStyle(.plain)

                // 확장 메뉴
                if menuExpanded {
                    // 6. 폰트 크기
                    Button { speechManager.cycleFontSize() } label: {
                        HStack(spacing: 0) {
                            Text("A").font(.system(size: 13, weight: .medium))
                            Text("A").font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.primary)
                        .frame(width: 38, height: 32)
                    }
                    .buttonStyle(.plain)

                    // 7. 설정
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .allowsHitTesting(!isDraggingBar)
            .opacity(isDraggingBar ? 0.4 : 1.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .offset(x: totalOffset.width, y: totalOffset.height)
        .transaction { t in t.animation = nil }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    isDraggingBar = true
                    floatingBarDragOffset = CGSize(
                        width: value.translation.width,
                        height: value.translation.height
                    )
                }
                .onEnded { value in
                    floatingBarOffset = CGSize(
                        width: floatingBarOffset.width + value.translation.width,
                        height: floatingBarOffset.height + value.translation.height
                    )
                    floatingBarDragOffset = .zero
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isDraggingBar = false
                    }
                }
        )
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
                        .background(speechManager.selectedLanguage == code ? Color.blue : Color.clear)
                        .foregroundColor(speechManager.selectedLanguage == code ? .white : .primary)
                }
            }
        }
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(speechManager.isRecording ? 0.4 : 1.0)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            if speechManager.isRecording {
                speechManager.stopRecording()
            } else {
                speechManager.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(speechManager.isRecording ? Color.red : Color.green)
                    .frame(width: 36, height: 36)

                if speechManager.isRecording {
                    VStack(spacing: 0) {
                        Text(String(format: "%02d:", speechManager.elapsedSeconds / 60))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(String(format: "%02d", speechManager.elapsedSeconds % 60))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtitle Area

    private func subtitleArea(leftDangerInset: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: speechManager.lineSpacing) {
                    ForEach(speechManager.subtitles.indices, id: \.self) { index in
                        subtitleBlock(
                            text: speechManager.subtitles[index],
                            opacity: 1.0,
                            leftDangerInset: leftDangerInset
                        )
                        .id(index)
                    }

                    if !speechManager.currentText.isEmpty {
                        subtitleBlock(
                            text: speechManager.currentText,
                            opacity: 0.65,
                            leftDangerInset: leftDangerInset
                        )
                        .id("current")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .onAppear { scrollToBottom(proxy) }
            .onChange(of: speechManager.currentText) { _ in scrollToBottom(proxy) }
            .onChange(of: speechManager.subtitles.count) { _ in scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("bottomAnchor", anchor: .bottom)
    }

    // MARK: - Subtitle Block
        private func subtitleBlock(text: String, opacity: Double, leftDangerInset: CGFloat) -> some View {
            TappableText(
                text: text,
                fontSize: speechManager.fontSize,
                textColor: speechManager.selectedTheme.textColor.opacity(opacity),
                // 순서 변경: glossaryColor와 lineSpacing을 먼저 씁니다.
                glossaryColor: speechManager.glossaryEnabled
                    ? speechManager.glossaryColor.color
                    : speechManager.selectedTheme.textColor.opacity(opacity),
                lineSpacing: speechManager.lineSpacing,
                glossaryStore: glossaryStore  // glossaryStore를 뒤로 보냈습니다.
            ) { word in
                NotificationCenter.default.post(
                    name: .searchDictionary,
                    object: word,
                    userInfo: ["language": speechManager.selectedLanguage]
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20 + leftDangerInset)
            .padding(.trailing, 20)
        }

    // MARK: - Drag Handles

    private var verticalDragHandle: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle().fill(Color.gray.opacity(0.14)).frame(width: visibleDividerThickness)
            Capsule().fill(Color.gray.opacity(0.55)).frame(width: 4, height: 34)
        }
        .contentShape(Rectangle())
    }

    private var horizontalDragHandle: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle().fill(Color.gray.opacity(0.14)).frame(height: visibleDividerThickness)
            Capsule().fill(Color.gray.opacity(0.55)).frame(width: 34, height: 4)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func pickFileFromFloating() {
        NotificationCenter.default.post(name: .openFilePicker, object: nil)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func clamp(value: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}
