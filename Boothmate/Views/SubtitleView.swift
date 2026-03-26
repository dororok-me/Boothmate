import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // 상단 컨트롤 바
            HStack {
                Button {
                    showMenu.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Spacer()

                // 언어 토글 (EN/KR)
                HStack(spacing: 0) {
                    Button {
                        speechManager.selectedLanguage = "en-US"
                    } label: {
                        Text("EN")
                            .font(.subheadline.bold())
                            .foregroundColor(speechManager.selectedLanguage == "en-US" ? .white : .gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(speechManager.selectedLanguage == "en-US" ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }

                    Button {
                        speechManager.selectedLanguage = "ko-KR"
                    } label: {
                        Text("KR")
                            .font(.subheadline.bold())
                            .foregroundColor(speechManager.selectedLanguage == "ko-KR" ? .white : .gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(speechManager.selectedLanguage == "ko-KR" ? Color.orange : Color.clear)
                            .cornerRadius(8)
                    }
                }
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                
                Spacer()

                Button {
                    speechManager.clearSubtitles()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                }

                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                    } else {
                        speechManager.startRecording()
                    }
                } label: {
                    Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(speechManager.isRecording ? .red : .green)
                }
            }
            .padding(.leading, 60)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(Color.black)

            // 자막 영역
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. 확정된 자막들
                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .foregroundColor(.white) // 흰색 고정
                                .font(.system(size: speechManager.fontSize))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 2. 현재 인식 중인 자막 (노란색에서 흰색으로 변경)
                        if !speechManager.currentText.isEmpty {
                            Text(speechManager.currentText)
                                .foregroundColor(.white) // 요청하신 대로 흰색 적용
                                .font(.system(size: speechManager.fontSize).bold())
                                .multilineTextAlignment(.leading)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("CURRENT_TEXT_NODE")
                        }

                        // 3. 하단 여백용 앵커 (한 줄 더 남기기 위해 높이 150)
                        Color.clear
                            .frame(height: 150)
                            .id("SCROLL_BOTTOM_ANCHOR")
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 50)
                    .padding(.top, 20)
                }
                .onChange(of: speechManager.currentText) { _ in
                    proxy.scrollTo("SCROLL_BOTTOM_ANCHOR", anchor: .bottom)
                }
                .onChange(of: speechManager.subtitles.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("SCROLL_BOTTOM_ANCHOR", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.black)
        .safeAreaPadding(.top)
        .onAppear {
            speechManager.requestPermissions()
        }
        .sheet(isPresented: $showMenu) {
            SubtitleMenuView(speechManager: speechManager)
        }
    }
}

// MARK: - 설정 메뉴 뷰
struct SubtitleMenuView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("음성인식 설정") {
                    HStack {
                        Text("인식 언어")
                        Spacer()
                        Text(speechManager.selectedLanguage == "ko-KR" ? "한국어" : "English")
                            .foregroundColor(.gray)
                    }
                }
                
                Section("디스플레이 설정") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("폰트 크기")
                            Spacer()
                            Text("\(Int(speechManager.fontSize)) pt")
                                .foregroundColor(.blue)
                                .bold()
                        }
                        
                        // 폰트 크기 조절 슬라이더 (14 ~ 60)
                        Slider(value: $speechManager.fontSize, in: 14...60, step: 1) {
                            Text("FontSize")
                        } minimumValueLabel: {
                            Text("A").font(.footnote)
                        } maximumValueLabel: {
                            Text("A").font(.title)
                        }
                    }
                    .padding(.vertical, 8)
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
