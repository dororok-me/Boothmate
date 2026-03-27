import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var glossaryStore: GlossaryStore
    @State private var showMenu = false
    @State private var showGlossary = false
    @State private var fontSizeLevel = 1

    private var subtitleFont: Font {
        switch fontSizeLevel {
        case 0: return .body
        case 2: return .largeTitle
        default: return .title3
        }
    }

    private let accent = Color(red: 1.0, green: 0.55, blue: 0.25)

    var body: some View {
        VStack(spacing: 0) {
            // 상단 컨트롤 바 - 중앙 정렬
            HStack(spacing: 0) {
                // 왼쪽: 글로서리 + 언어
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
                        if speechManager.selectedLanguage == "en-US" {
                            speechManager.selectedLanguage = "ko-KR"
                        } else {
                            speechManager.selectedLanguage = "en-US"
                        }
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

                // 오른쪽: 지우기 + 설정
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
            .background(
                Color.black.opacity(0.9)
                    .overlay(accent.opacity(0.06))
            )

            // 확정된 자막
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .foregroundColor(.white)
                                .font(subtitleFont)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .onChange(of: speechManager.subtitles.count) {
                    if let last = speechManager.subtitles.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            // 현재 인식 중 (하단 고정)
            Text(speechManager.currentText.isEmpty ? " " : speechManager.currentText)
                .foregroundColor(.yellow)
                .font(subtitleFont)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.black)
        }
        .background(Color.black)
        .safeAreaPadding(.top)
        .onAppear {
            speechManager.requestPermissions()
        }
        .sheet(isPresented: $showMenu) {
            SubtitleMenuView(speechManager: speechManager)
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(glossaryStore: glossaryStore)
        }
    }
}

struct SubtitleMenuView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("음성인식 엔진") {
                    Text("Apple (기본)")
                }
                Section("설정") {
                    Text("폰트 크기")
                    Text("추가 설정")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}
