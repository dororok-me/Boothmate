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

    @State private var horizontalSplitDragStart: CGFloat?
    @State private var leftVerticalSplitDragStart: CGFloat?
    @State private var rightVerticalSplitDragStart: CGFloat?

    private let dividerHitThickness: CGFloat = 28
    private let visibleDividerThickness: CGFloat = 1

    private let minPaneWidth: CGFloat = 90
    private let minPaneHeight: CGFloat = 28
    private let topBarHeight: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height

            let safeTop = geo.safeAreaInsets.top
            let safeLeading = geo.safeAreaInsets.leading

            let isLandscape = totalWidth > totalHeight

            // 다이나믹 아일랜드/노치 회피용 내부 여백
            let leftDangerInset: CGFloat = isLandscape ? max(safeLeading, 44) : 0

            let topSafeSpacing = safeTop + 8

            // 좌우 분할 계산은 전체 폭 기준으로 유지
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
                VStack(spacing: 0) {
                    topBar(leftDangerInset: leftDangerInset)
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
                                    let newSplit = start + delta

                                    withTransaction(Transaction(animation: nil)) {
                                        leftVerticalSplit = clamp(
                                            value: newSplit,
                                            minValue: minPaneHeight / leftContentHeight,
                                            maxValue: 1 - (minPaneHeight / leftContentHeight)
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    leftVerticalSplitDragStart = nil
                                }
                        )

                    MemoView()
                        .frame(width: leftWidth, height: leftBottomHeight)
                        .background(Color(.systemBackground))
                }

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
                                let newSplit = start + delta

                                withTransaction(Transaction(animation: nil)) {
                                    horizontalSplit = clamp(
                                        value: newSplit,
                                        minValue: minPaneWidth / (totalWidth - dividerHitThickness),
                                        maxValue: 1 - (minPaneWidth / (totalWidth - dividerHitThickness))
                                    )
                                }
                            }
                            .onEnded { _ in
                                horizontalSplitDragStart = nil
                            }
                    )

                VStack(spacing: 0) {
                    FileViewerView()
                        .frame(width: rightWidth, height: rightTopHeight)
                        .background(Color(.systemBackground))

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
                                    let newSplit = start + delta

                                    withTransaction(Transaction(animation: nil)) {
                                        rightVerticalSplit = clamp(
                                            value: newSplit,
                                            minValue: minPaneHeight / rightContentHeight,
                                            maxValue: 1 - (minPaneHeight / rightContentHeight)
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    rightVerticalSplitDragStart = nil
                                }
                        )

                    DictionaryView()
                        .frame(width: rightWidth, height: rightBottomHeight)
                        .background(Color(.systemBackground))
                }
            }
            .frame(width: totalWidth, height: totalHeight)
        }
        .ignoresSafeArea()
        .onAppear {
            speechManager.requestPermissions()
            speechManager.glossaryStore = glossaryStore
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(glossaryStore: glossaryStore)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(speechManager: speechManager)
        }
    }

    private func topBar(leftDangerInset: CGFloat) -> some View {
        HStack(spacing: 8) {
            Spacer()

            toolbarIconButton(systemName: "text.book.closed") {
                showGlossary = true
            }

            toolbarIconButton(systemName: "arrow.counterclockwise") {
                speechManager.clearSubtitles()
            }

            toolbarIconButton(systemName: "keyboard.chevron.compact.down") {
                dismissKeyboard()
            }

            toolbarIconButton(systemName: "gearshape") {
                showSettings = true
            }

            fontSizeButton

            toolbarIconButton(systemName: "keyboard.chevron.compact.down") {
                dismissKeyboard()
            }

            languageToggle

            recordButton
        }
        .padding(.leading, 10 + leftDangerInset)
        .padding(.trailing, 10)
        .background(Color.clear)
    }

    private var languageToggle: some View {
        HStack(spacing: 0) {
            Button {
                speechManager.selectedLanguage = "en-US"
            } label: {
                Text("EN")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 42, height: 32)
                    .background(
                        speechManager.selectedLanguage == "en-US" ? Color.blue : Color.clear
                    )
                    .foregroundColor(
                        speechManager.selectedLanguage == "en-US" ? .white : .primary
                    )
            }

            Button {
                speechManager.selectedLanguage = "ko-KR"
            } label: {
                Text("KR")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 42, height: 32)
                    .background(
                        speechManager.selectedLanguage == "ko-KR" ? Color.blue : Color.clear
                    )
                    .foregroundColor(
                        speechManager.selectedLanguage == "ko-KR" ? .white : .primary
                    )
            }
        }
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private var fontSizeButton: some View {
        Button {
            speechManager.cycleFontSize()
        } label: {
            HStack(spacing: 1) {
                Text("a")
                    .font(.system(size: 12, weight: .medium))
                Text("A")
                    .font(.system(size: 21, weight: .bold))
            }
            .foregroundColor(.primary)
            .frame(width: 38, height: 32)
        }
        .buttonStyle(.plain)
    }

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
                    .fill(speechManager.isRecording ? Color.red : Color.red.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(speechManager.isRecording ? .white : .red)
            }
        }
        .buttonStyle(.plain)
    }

    private func toolbarIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private func subtitleArea(leftDangerInset: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: speechManager.currentText) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: speechManager.subtitles.count) { _ in
                scrollToBottom(proxy)
            }
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        }
    }

    private func subtitleBlock(text: String, opacity: Double, leftDangerInset: CGFloat) -> some View {
        SubtitleTextView(
            text: text,
            fontSize: speechManager.fontSize,
            textColor: speechManager.selectedTheme.textColor.opacity(opacity),
            glossaryStore: glossaryStore
        ) { word in
            NotificationCenter.default.post(
                name: Notification.Name.searchDictionary,
                object: word,
                userInfo: nil
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20 + leftDangerInset)
        .padding(.trailing, 20)
    }

    private var verticalDragHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            Rectangle()
                .fill(Color.gray.opacity(0.14))
                .frame(width: visibleDividerThickness)

            Capsule()
                .fill(Color.gray.opacity(0.55))
                .frame(width: 4, height: 34)
        }
        .contentShape(Rectangle())
    }

    private var horizontalDragHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            Rectangle()
                .fill(Color.gray.opacity(0.14))
                .frame(height: visibleDividerThickness)

            Capsule()
                .fill(Color.gray.opacity(0.55))
                .frame(width: 34, height: 4)
        }
        .contentShape(Rectangle())
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func clamp(value: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}
