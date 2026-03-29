import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var glossaryStore: GlossaryStore
    
    @State private var showMenu = false
    @State private var showGlossary = false
    
    // 강조 색상 (Boothmate 테마)
    private let accent = Color(red: 1.0, green: 0.55, blue: 0.25)

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 컨트롤 바
            HStack(spacing: 0) {
                // 왼쪽: 글로서리 + 언어 전환
                HStack(spacing: 16) {
                    Button {
                        showGlossary.toggle()
                    } label: {
                        Image(systemName: "text.book.closed")
                            .font(.title3)
                            .foregroundColor(accent)
                            .frame(width: 36, height: 36)
                    }

                    Button {
                        speechManager.selectedLanguage = (speechManager.selectedLanguage == "en-US") ? "ko-KR" : "en-US"
                    } label: {
                        HStack(spacing: 0) {
                            Text("EN")
                                .font(.caption2.bold())
                                .foregroundColor(speechManager.selectedLanguage == "en-US" ? .white : accent.opacity(0.4))
                                .frame(width: 30, height: 26)
                                .background(speechManager.selectedLanguage == "en-US" ? accent : Color.clear)
                            Text("KR")
                                .font(.caption2.bold())
                                .foregroundColor(speechManager.selectedLanguage == "ko-KR" ? .white : accent.opacity(0.4))
                                .frame(width: 30, height: 26)
                                .background(speechManager.selectedLanguage == "ko-KR" ? accent : Color.clear)
                        }
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                // 중앙: 녹음 버튼
                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                    } else {
                        speechManager.startRecording()
                    }
                } label: {
                    Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .foregroundColor(speechManager.isRecording ? .white : accent)
                        .frame(width: 48, height: 48)
                        .background(speechManager.isRecording ? accent : accent.opacity(0.15))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(accent.opacity(0.3), lineWidth: speechManager.isRecording ? 0 : 1)
                        )
                }

                // 오른쪽: 초기화 + 설정
                HStack(spacing: 16) {
                    Button {
                        speechManager.clearSubtitles()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .foregroundColor(accent)
                            .frame(width: 36, height: 36)
                    }

                    Button {
                        showMenu.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(accent)
                            .frame(width: 36, height: 36)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.9).overlay(accent.opacity(0.06)))

            // MARK: - 확정된 자막 리스트 (자동 스크롤 적용)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, text in
                            TappableText(
                                text: text,
                                fontSize: speechManager.fontSize,
                                textColor: .white,
                                glossaryColor: speechManager.glossaryColor.color,
                                lineSpacing: speechManager.lineSpacing,
                                glossaryStore: glossaryStore,
                                onTapWord: { word in
                                    NotificationCenter.default.post(name: .searchDictionary, object: word)
                                }
                            )
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .onChange(of: speechManager.subtitles.count) { _ in
                    // 새 자막 추가 시 부드럽게 아래로 스크롤
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(speechManager.subtitles.count - 1, anchor: .bottom)
                    }
                }
            }

            // MARK: - 실시간 인식 중인 텍스트 (하단 고정)
            VStack(spacing: 0) {
                Divider().background(accent.opacity(0.3))
                
                if !speechManager.currentText.isEmpty {
                    TappableText(
                        text: speechManager.currentText,
                        fontSize: speechManager.fontSize,
                        textColor: .yellow, // 인식 중인 텍스트는 노란색
                        glossaryColor: speechManager.glossaryColor.color,
                        lineSpacing: speechManager.lineSpacing,
                        glossaryStore: glossaryStore,
                        onTapWord: { word in
                            NotificationCenter.default.post(name: .searchDictionary, object: word)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.opacity)
                } else {
                    Text("대기 중...")
                        .font(.system(size: speechManager.fontSize))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            speechManager.requestPermissions()
        }
        .sheet(isPresented: $showMenu) {
            SettingsView(speechManager: speechManager)
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(glossaryStore: glossaryStore)
        }
    }
}
