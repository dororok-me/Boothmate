import SwiftUI
import Combine
import UIKit
import Speech
import AVFoundation
import WebKit
import QuickLook
import UniformTypeIdentifiers

// MARK: - 색상 정의

struct AppColors {
    static let menuIcon = Color.primary.opacity(0.9)
    static let boothKR = Color.blue
    static let boothCN = Color.red
    static let boothJP = Color.black
    static let tabDictionary = Color(red: 0.6, green: 0.82, blue: 0.88)
    static let tabFile = Color(red: 0.95, green: 0.78, blue: 0.65)
    static let tabMemo = Color(red: 0.88, green: 0.75, blue: 0.92)
    static let tabGM = Color(red: 0.98, green: 0.85, blue: 0.55)
}

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()
    @StateObject private var currencyConverter = CurrencyConverter()
    @StateObject private var gmStore = GMStore()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showPaywall = false

    var body: some View {
        VerticalContentView(
            speechManager: speechManager,
            glossaryStore: glossaryStore,
            gmStore: gmStore,
            subscriptionManager: subscriptionManager
        )
        .onAppear {
            speechManager.glossaryStore = glossaryStore
            speechManager.currencyConverter = currencyConverter
            subscriptionManager.updateTrialStatus()
            if !subscriptionManager.canUseApp { showPaywall = true }
            Task {
                await subscriptionManager.checkSubscriptionStatus()
                if !subscriptionManager.canUseApp { showPaywall = true }
            }
            DispatchQueue.global(qos: .utility).async {
                SFSpeechRecognizer.requestAuthorization { _ in }
                AVAudioApplication.requestRecordPermission { _ in }
                Task { @MainActor in currencyConverter.fetchRates() }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .interactiveDismissDisabled(!subscriptionManager.canUseApp)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

// MARK: - 메모 패널

struct MemoPanel: View {
    @Binding var text: String
    var hideHeader: Bool = false
    var body: some View {
        VStack(spacing: 0) {
            if !hideHeader {
                HStack {
                    Text("메모").font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                    Spacer()
                    Text("\(text.count)자").font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.08))
            }
            TextEditor(text: $text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 6)
                .padding(.top, 4)
        }
    }
}

// MARK: - 안전한 QuickLook Preview (크래시 방지)

struct SafeQuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        
        // ★ 안전한 부모-자식 관계 설정
        container.addChild(preview)
        container.view.addSubview(preview.view)
        preview.view.frame = container.view.bounds
        preview.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        preview.didMove(toParent: container)
        
        return container
    }
    
    func updateUIViewController(_ container: UIViewController, context: Context) {
        // ★ URL 변경시에만 업데이트
        if context.coordinator.url?.absoluteString != url.absoluteString {
            context.coordinator.url = url
            
            // 안전하게 QLPreviewController 찾아서 reload
            if let preview = container.children.first as? QLPreviewController {
                preview.reloadData()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL?
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return url != nil ? 1 : 0
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url! as QLPreviewItem
        }
    }
}

// MARK: - Document Picker (PPT, PDF, JPG, DOC, 모든 파일 타입 지원)

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,           // PDF 파일
            .jpeg,          // JPG/JPEG 이미지
            .png,           // PNG 이미지
            .image,         // 기타 이미지
            .presentation,  // PPT 파일
            .spreadsheet,   // Excel 파일
            .plainText,     // 텍스트 파일
            .rtf,           // RTF 파일
            .data           // DOC 등 기타 문서
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // 파일 접근 권한 획득
            _ = url.startAccessingSecurityScopedResource()
            
            onPick(url)
        }
    }
}

// MARK: - Glow Button Style

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.15) : Color.clear)
                    .blur(radius: configuration.isPressed ? 4 : 0)
            )
            .shadow(
                color: configuration.isPressed ? Color.blue.opacity(0.5) : Color.clear,
                radius: configuration.isPressed ? 8 : 0
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
