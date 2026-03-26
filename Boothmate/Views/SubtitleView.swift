import SwiftUI
import Combine

struct SubtitleView: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // 상단 컨트롤 바 (테마에 따라 색상 변경)
            HStack {
                // 톱니바퀴(설정) 버튼
                Button {
                    showMenu.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        // 🌟 삼항 연산자 대신 테마에 정의된 iconColor를 적용합니다.
                        .foregroundColor(speechManager.selectedTheme.iconColor)
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
                        Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title)
                            .foregroundColor(speechManager.isRecording ? .red : .green)
                    }
                }
            }
            .padding(.leading, 60)
            .padding(.trailing, 20)
            .padding(.vertical, 10)
            .background(speechManager.selectedTheme.backgroundColor) // 상단바 배경도 테마 적용

            // 자막 영역 (스크롤 및 레이아웃 고정)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 1. 확정된 자막들
                        ForEach(Array(speechManager.subtitles.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .foregroundColor(speechManager.selectedTheme.textColor) // 테마 텍스트색
                                .font(.system(size: speechManager.fontSize))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 2. 현재 인식 중인 자막
                        if !speechManager.currentText.isEmpty {
                            Text(speechManager.currentText)
                                .foregroundColor(speechManager.selectedTheme.textColor) // 테마 텍스트색 (Normal 적용)
                                .font(.system(size: speechManager.fontSize))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("CURRENT_TEXT_NODE")
                        }

                        // 3. 하단 여백용 앵커 (한 줄 더 남기고 올라가기 위해 높이 150)
                        Color.clear
                            .frame(height: 40)
                            .id("SCROLL_BOTTOM_ANCHOR")
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 50)
                    .padding(.top, 20)
                }
                // 리걸 패드 테마일 때 줄무늬 배경 추가
                .background(
                    Group {
                        if speechManager.selectedTheme == .legal {
                            LegalPadBackground(lineColor: speechManager.selectedTheme.lineColor)
                        } else {
                            speechManager.selectedTheme.backgroundColor
                        }
                    }
                )
                // 최신 onChange 문법 적용
                .onChange(of: speechManager.currentText) { oldValue, newValue in
                    proxy.scrollTo("SCROLL_BOTTOM_ANCHOR", anchor: .bottom)
                }
                .onChange(of: speechManager.subtitles.count) { oldValue, newValue in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("SCROLL_BOTTOM_ANCHOR", anchor: .bottom)
                    }
                }
            }
        }
        .background(speechManager.selectedTheme.backgroundColor) // 전체 배경 테마 적용
        .safeAreaPadding(.top)
        .onAppear {
            speechManager.requestPermissions()
        }
        .sheet(isPresented: $showMenu) {
            SubtitleMenuView(speechManager: speechManager)
        }
    }
}

// MARK: - 리걸 패드 줄무늬 배경 뷰
struct LegalPadBackground: View {
    var lineColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let ySpacing: CGFloat = 36 // 줄 간격
                let numberOfLines = Int(geometry.size.height / ySpacing)
                
                for i in 1...numberOfLines {
                    let yPosition = CGFloat(i) * ySpacing
                    path.move(to: CGPoint(x: 0, y: yPosition))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: yPosition))
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
        .background(Color(red: 1.0, green: 1.0, blue: 0.8)) // 연노랑 배경
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
                    // 테마 선택 Picker 추가
                    Picker("배경 테마", selection: $speechManager.selectedTheme) {
                        ForEach(SubtitleTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.navigationLink) // 아이패드에서 보기 좋은 스타일
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("폰트 크기")
                            Spacer()
                            Text("\(Int(speechManager.fontSize)) pt")
                                .foregroundColor(.blue)
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
