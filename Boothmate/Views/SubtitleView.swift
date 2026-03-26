import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // 상단 컨트롤 바
            HStack {
                // Claude 스타일의 설정(톱니바퀴) 버튼
                Button {
                    showMenu.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.trailing, 10)
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

                // 우측 버튼들
                HStack(spacing: 20) {
                    Button {
                        speechManager.clearSubtitles()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }

                    Button {
                        if speechManager.isRecording {
                            speechManager.stopRecording()
                        } else {
                            speechManager.startRecording()
                        }
                    } label: {
                        // 에러 해결: .title1 대신 .title 사용
                        Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title)
                            .foregroundColor(speechManager.isRecording ? .red : .green)
                    }
                }
            }
            .padding(.leading, 60)
            .padding(.trailing, 20)
            .padding(.vertical, 10)
            .background(Color.black)

            // 자막 영역 (스크롤 및 레이아웃 고정)
            // SubtitleView.swift 내의 ScrollView 영역 수정

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. 확정된 자막들
                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .foregroundColor(.white)
                                .font(.system(size: speechManager.fontSize))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 2. 현재 인식 중인 실시간 자막
                        if !speechManager.currentText.isEmpty {
                            Text(speechManager.currentText)
                                .foregroundColor(.white)
                                .font(.system(size: speechManager.fontSize).bold())
                                .multilineTextAlignment(.leading)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 3. 하단 여백용 고정 앵커
                        // 높이를 200px 이상으로 늘려 자막 아래에 확실하게 한 줄 이상의 빈 공간을 확보합니다.
                        Color.clear
                            .frame(height: 50)
                            .id("SCROLL_BOTTOM_ANCHOR")
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 50)
                    .padding(.top, 20)
                }
                // 실시간 텍스트 업데이트 시 즉시 하단 앵커 추적
                .onChange(of: speechManager.currentText) { _ in
                    proxy.scrollTo("SCROLL_BOTTOM_ANCHOR", anchor: .bottom)
                }
                // 문장이 확정될 때 부드럽게 스크롤
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
                Section("디스플레이 설정") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("폰트 크기")
                            Spacer()
                            Text("\(Int(speechManager.fontSize)) pt")
                                .foregroundColor(.blue)
                                .bold()
                        }
                        
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
