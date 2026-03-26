import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var showMenu = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 자막 표시 영역 (전체 화면)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // 상단 여백 (메뉴 버튼 가리지 않게)
                        Spacer()
                            .frame(height: 50)

                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .foregroundColor(.white)
                                .font(.title3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }

                        if !speechManager.currentText.isEmpty {
                            Text(speechManager.currentText)
                                .foregroundColor(.yellow)
                                .font(.title3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("current")
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: speechManager.currentText) {
                    withAnimation {
                        proxy.scrollTo("current", anchor: .bottom)
                    }
                }
                .onChange(of: speechManager.subtitles.count) {
                    if let last = speechManager.subtitles.indices.last {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            // 좌측 상단 메뉴 버튼
            HStack {
                Button {
                    showMenu.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }

                Spacer()

                // 녹음 상태 표시 (녹음 중일 때만)
                if speechManager.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color.black)
        .onAppear {
            speechManager.requestPermissions()
        }
        .sheet(isPresented: $showMenu) {
            SubtitleMenuView(speechManager: speechManager)
        }
    }
}

// 메뉴 화면
struct SubtitleMenuView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 녹음 시작/중지
                Section {
                    Button {
                        if speechManager.isRecording {
                            speechManager.stopRecording()
                        } else {
                            speechManager.startRecording()
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundColor(speechManager.isRecording ? .red : .green)
                                .font(.title2)
                            Text(speechManager.isRecording ? "녹음 중지" : "녹음 시작")
                        }
                    }
                }

                // 언어 선택
                Section("언어") {
                    ForEach(speechManager.languages, id: \.1) { name, code in
                        Button {
                            speechManager.selectedLanguage = code
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if speechManager.selectedLanguage == code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                // 자막 지우기
                Section {
                    Button(role: .destructive) {
                        speechManager.clearSubtitles()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("자막 지우기")
                        }
                    }
                }
            }
            .navigationTitle("자막 설정")
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
