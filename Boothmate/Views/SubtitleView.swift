import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // 상단 컨트롤 바
            HStack {
                // 메뉴 버튼
                Button {
                    showMenu.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Spacer()

                // 언어 토글
                Picker("언어", selection: $speechManager.selectedLanguage) {
                    ForEach(speechManager.languages, id: \.1) { name, code in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer()

                // 자막 지우기
                Button {
                    speechManager.clearSubtitles()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                }

                // 녹음 시작/중지
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

            // 자막 표시 영역
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
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
                    .padding(.leading, 60)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
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
        }
        .padding(.top, 1)
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
                    Text("글로서리")
                    Text("폰트 크기")
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
