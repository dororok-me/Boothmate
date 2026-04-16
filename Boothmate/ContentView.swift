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

// MARK: - 파일 프리뷰 패널

struct FilePreviewPanel: View {
    @Binding var fileURL: URL?
    @Binding var bookmarkData: Data?
    @State private var showFilePicker = false
    @State private var previewID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            fileHeader
            fileContent
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { url in
                if let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    bookmarkData = bookmark
                }
                fileURL = url
                previewID = UUID()
            }
        }
    }

    private var fileHeader: some View {
        HStack {
            if let url = fileURL {
                Image(systemName: iconForFile(url)).font(.system(size: 12)).foregroundColor(.blue)
                Text(url.lastPathComponent).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button { showFilePicker = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder").font(.system(size: 12))
                    Text("파일 열기").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.08))
    }

    @ViewBuilder
    private var fileContent: some View {
        if let url = resolveFileURL() {
            QuickLookPreview(url: url).id(previewID)
        } else {
            VStack {
                Spacer()
                Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.gray.opacity(0.4)).padding(.bottom, 8)
                Text("파일을 선택하세요").font(.system(size: 14)).foregroundColor(.gray)
                Spacer()
            }
        }
    }

    private func resolveFileURL() -> URL? {
        if let url = fileURL {
            if url.startAccessingSecurityScopedResource() { return url }
        }
        if let data = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                if isStale {
                    bookmarkData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                }
                fileURL = url
                return url
            }
        }
        return nil
    }

    private func iconForFile(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "rectangle.stack"
        case "txt", "rtf": return "doc.plaintext"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo"
        case "csv": return "tablecells"
        default: return "doc"
        }
    }
}

// MARK: - QuickLook Preview
// 싱글톤으로 QLPreviewController 인스턴스 유지 → 탭 전환/가로세로 전환해도 페이지 유지

class QLPreviewStore: NSObject, QLPreviewControllerDataSource {
    static let shared = QLPreviewStore()
    var url: URL?
    lazy var controller: QLPreviewController = {
        let c = QLPreviewController()
        c.dataSource = self
        return c
    }()
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { url == nil ? 0 : 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url! as QLPreviewItem
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> ContainerVC {
        let container = ContainerVC()
        return container
    }

    func updateUIViewController(_ container: ContainerVC, context: Context) {
        let store = QLPreviewStore.shared
        if store.url != url {
            store.url = url
            store.controller.reloadData()
        }
        // 아직 추가 안 됐을 때만 addChild
        if store.controller.parent == nil {
            container.embedChild(store.controller)
        } else if store.controller.parent != container {
            // 다른 컨테이너에 붙어 있으면 이동
            store.controller.willMove(toParent: nil)
            store.controller.view.removeFromSuperview()
            store.controller.removeFromParent()
            container.embedChild(store.controller)
        }
    }

    class ContainerVC: UIViewController {
        func embedChild(_ child: UIViewController) {
            addChild(child)
            child.view.frame = view.bounds
            child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(child.view)
            child.didMove(toParent: self)
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate { [weak self] _ in
                guard let self else { return }
                self.children.first?.view.frame = CGRect(origin: .zero, size: size)
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .plainText, .rtf, .spreadsheet, .presentation, .image, .data])
        picker.delegate = context.coordinator; picker.allowsMultipleSelection = false; return picker
    }
    func updateUIViewController(_ c: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { _ = url.startAccessingSecurityScopedResource(); onPick(url) }
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

