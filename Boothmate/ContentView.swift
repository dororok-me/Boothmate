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

    private let dividerThickness: CGFloat = 18
    private let visibleDividerThickness: CGFloat = 1
    private let minPaneWidth: CGFloat = 90
    private let minPaneHeight: CGFloat = 35
    private let topBarHeight: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let rootFrame = geo.frame(in: .global)
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height

            let safeTop = geo.safeAreaInsets.top
            let topSafeSpacing = safeTop + 8

            let leftWidth = clamp(
                value: (totalWidth - dividerThickness) * horizontalSplit,
                minValue: minPaneWidth,
                maxValue: totalWidth - dividerThickness - minPaneWidth
            )

            let rightWidth = totalWidth - leftWidth - dividerThickness

            let leftContentHeight = totalHeight - topSafeSpacing - topBarHeight - dividerThickness
            let rightContentHeight = totalHeight - dividerThickness

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
                    topBar
                        .frame(height: topBarHeight)
                        .padding(.top, topSafeSpacing)

                    subtitleArea
                        .frame(width: leftWidth, height: leftTopHeight)
                        .background(speechManager.selectedTheme.backgroundColor)

                    horizontalDragHandle
                        .frame(width: leftWidth, height: dividerThickness)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { value in
                                    let y = value.location.y - rootFrame.minY - topSafeSpacing - topBarHeight
                                    let split = y / leftContentHeight
                                    leftVerticalSplit = clamp(
                                        value: split,
                                        minValue: minPaneHeight / leftContentHeight,
                                        maxValue: 1 - (minPaneHeight / leftContentHeight)
                                    )
                                }
                        )

                    MemoView()
                        .frame(width: leftWidth, height: leftBottomHeight)
                        .background(Color(.systemBackground))
                }

                verticalDragHandle
                    .frame(width: dividerThickness, height: totalHeight)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let x = value.location.x - rootFrame.minX
                                let split = x / (totalWidth - dividerThickness)
                                horizontalSplit = clamp(
                                    value: split,
                                    minValue: minPaneWidth / (totalWidth - dividerThickness),
                                    maxValue: 1 - (minPaneWidth / (totalWidth - dividerThickness))
                                )
                            }
                    )

                VStack(spacing: 0) {
                    FileViewerView()
                        .frame(width: rightWidth, height: rightTopHeight)
                        .background(Color(.systemBackground))

                    horizontalDragHandle
                        .frame(width: rightWidth, height: dividerThickness)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { value in
                                    let y = value.location.y - rootFrame.minY
                                    let split = y / rightContentHeight
                                    rightVerticalSplit = clamp(
                                        value: split,
                                        minValue: minPaneHeight / rightContentHeight,
                                        maxValue: 1 - (minPaneHeight / rightContentHeight)
                                    )
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

    private var topBar: some View {
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
        .padding(.horizontal, 10)
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

    private var subtitleArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(speechManager.subtitles.indices, id: \.self) { index in
                        subtitleBlock(text: speechManager.subtitles[index], opacity: 1.0)
                            .id(index)
                    }

                    if !speechManager.currentText.isEmpty {
                        subtitleBlock(text: speechManager.currentText, opacity: 0.65)
                            .id("current")
                    }

                    Color.clear
                        .frame(height: 8)
                        .id("bottom")
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .onChange(of: speechManager.currentText) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: speechManager.subtitles.count) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func subtitleBlock(text: String, opacity: Double) -> some View {
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
        .padding(.horizontal, 20)
    }

    private var verticalDragHandle: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle()
                .fill(Color.gray.opacity(0.20))
                .frame(width: visibleDividerThickness)
            Capsule()
                .fill(Color.gray.opacity(0.55))
                .frame(width: 4, height: 34)
        }
        .contentShape(Rectangle())
    }

    private var horizontalDragHandle: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle()
                .fill(Color.gray.opacity(0.20))
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
