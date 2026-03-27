import SwiftUI

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()

    @State private var horizontalSplit: CGFloat = 0.5
    @State private var verticalSplit: CGFloat = 0.5
    @State private var memoSplit: CGFloat = 0.85
    @State private var showSettings = false
    @State private var showGlossary = false

    var body: some View {
        GeometryReader { geo in
            let handleWidth: CGFloat = 8
            let leftWidth = (geo.size.width - handleWidth) * horizontalSplit
            let rightWidth = geo.size.width - leftWidth - handleWidth
            let topHeight = (geo.size.height - handleWidth) * verticalSplit
            let menuHeight: CGFloat = 60 + geo.safeAreaInsets.top
            let leftContentHeight = geo.size.height - menuHeight
            let subtitleHeight = leftContentHeight * memoSplit

            HStack(spacing: 0) {
                // MARK: - 왼쪽 자막 창
                VStack(spacing: 0) {
                    // 상단 메뉴바 (오른쪽 정렬)
                    HStack(spacing: 15) {
                        Spacer()

                        // 1. 글로서리
                        Button(action: { showGlossary = true }) {
                            Image(systemName: "text.book.closed")
                                .font(.title3).foregroundColor(.gray)
                        }

                        // 2. 새로고침 (자막 지우기)
                        Button(action: { speechManager.clearSubtitles() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3).foregroundColor(.gray)
                        }

                        // 3. EN/KR
                        HStack(spacing: 0) {
                            Button(action: { speechManager.selectedLanguage = "en-US" }) {
                                Text("EN").font(.caption2).bold()
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(speechManager.selectedLanguage == "en-US" ? Color.blue : Color.gray.opacity(0.1))
                                    .foregroundColor(speechManager.selectedLanguage == "en-US" ? .white : .primary)
                                    .cornerRadius(5)
                            }
                            Button(action: { speechManager.selectedLanguage = "ko-KR" }) {
                                Text("KR").font(.caption2).bold()
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(speechManager.selectedLanguage == "ko-KR" ? Color.blue : Color.gray.opacity(0.1))
                                    .foregroundColor(speechManager.selectedLanguage == "ko-KR" ? .white : .primary)
                                    .cornerRadius(5)
                            }
                        }
                        .background(Color.gray.opacity(0.1)).cornerRadius(5)

                        // 4. 설정
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.title3).foregroundColor(.gray)
                        }

                        // 5. Start/Stop
                        Button(action: {
                            speechManager.isRecording ? speechManager.stopRecording() : speechManager.startRecording()
                        }) {
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                                .foregroundColor(speechManager.isRecording ? .red : .blue)
                        }

                        // 6. 폰트 크기 순환
                                                Button {
                                                    speechManager.cycleFontSize()
                                                } label: {
                                                    Text("A")
                                                        .font(.title3).bold()
                                                        .foregroundColor(.gray)
                                                }
                        
                                                // 8. 키보드 내리기
                                                Button(action: {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                }) {
                                                    Image(systemName: "keyboard.chevron.compact.down")
                                                        .font(.title3).foregroundColor(.gray)
                                                }
                    }
                    .padding(.leading, max(geo.safeAreaInsets.leading, 60))
                    .padding(.trailing, 20)
                    .padding(.top, max(geo.safeAreaInsets.top, 10))
                    .padding(.bottom, 15)
                    .background(Color.secondary.opacity(0.05))

                    Divider()

                    // 자막 스크롤 영역
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, subtitle in
                                    Text(subtitle)
                                        .font(.system(size: speechManager.fontSize, weight: .medium))
                                        .foregroundColor(speechManager.selectedTheme.textColor)
                                        .lineSpacing(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, max(geo.safeAreaInsets.leading, 60))
                                        .padding(.trailing, 20)
                                        .id(index)
                                }

                                if !speechManager.currentText.isEmpty {
                                    Text(speechManager.currentText)
                                        .font(.system(size: speechManager.fontSize, weight: .medium))
                                        .foregroundColor(speechManager.selectedTheme.textColor.opacity(0.6))
                                        .lineSpacing(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, max(geo.safeAreaInsets.leading, 60))
                                        .padding(.trailing, 20)
                                        .id("current")
                                }

                                Color.clear.frame(height: 10).id("bottom")
                            }
                            .padding(.vertical, 20)
                        }
                        .background(speechManager.selectedTheme.backgroundColor)
                        .onChange(of: speechManager.currentText) {
                            proxy.scrollTo("bottom")
                        }
                        .onChange(of: speechManager.subtitles.count) {
                            proxy.scrollTo("bottom")
                        }
                    }
                    .frame(height: subtitleHeight)

                    // 자막-메모 드래그 핸들
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: handleWidth)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray)
                                .frame(width: 30, height: 3)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { value in
                                    let relativeY = value.location.y - menuHeight
                                    let new = relativeY / leftContentHeight
                                    memoSplit = min(max(new, 0.3), 0.95)
                                }
                        )

                    // 하단 메모장
                    MemoView()
                        .frame(maxHeight: .infinity)
                }
                .frame(width: leftWidth)
                .background(speechManager.selectedTheme.backgroundColor)
                .clipped()

                // 좌우 드래그 핸들
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: handleWidth)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray)
                            .frame(width: 3, height: 30)
                    )
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let new = value.location.x / geo.size.width
                                horizontalSplit = min(max(new, 0.2), 0.8)
                            }
                    )

                // MARK: - 오른쪽 파일 뷰어 + 사전
                VStack(spacing: 0) {
                    FileViewerView()
                        .frame(maxWidth: .infinity, maxHeight: topHeight)
                        .background(Color(UIColor.systemBackground))
                        .clipped()

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: handleWidth)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray)
                                .frame(width: 30, height: 3)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { value in
                                    let new = value.location.y / geo.size.height
                                    verticalSplit = min(max(new, 0.2), 0.8)
                                }
                        )

                    DictionaryView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipped()
                }
                .frame(width: rightWidth)
            }
        }
        .ignoresSafeArea()
        .transaction { t in
            t.animation = nil
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(glossaryStore: glossaryStore)
        }
        .sheet(isPresented: $showSettings) {
            SubtitleMenuView(speechManager: speechManager)
        }
    }
}
