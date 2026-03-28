import SwiftUI
import WebKit
import QuickLook
import UniformTypeIdentifiers
import UIKit

struct FileViewerView: View {
    @State private var selectedURL: URL?
    @State private var fileType: FileType = .none
    @State private var isDownloading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var pickerDelegate: DocumentPickerDelegate?

    enum FileType {
        case none, webviewable, image, other
    }

    var body: some View {
        ZStack {
            switch fileType {
            case .none:
                Color(UIColor.systemBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .webviewable:
                if let url = selectedURL {
                    WebDocumentView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .image:
                if let url = selectedURL,
                   let data = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: data) {
                    ZoomableImageView(image: uiImage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .other:
                if let url = selectedURL {
                    QuickLookFallback(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if isDownloading {
                VStack {
                    ProgressView()
                    Text("다운로드 중...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
            }
        }
        .clipped()
        .alert("파일 열기 실패", isPresented: $showAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            pickFile()
        }
    }

    private func pickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.allowsMultipleSelection = false

        let delegate = DocumentPickerDelegate { url in
            handlePickedFile(url)
        }

        picker.delegate = delegate
        pickerDelegate = delegate

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            showError("파일 선택 창을 열 수 없습니다.")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(picker, animated: true)
    }

    private func handlePickedFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError("파일 접근 권한이 없습니다.")
            return
        }

        let fm = FileManager.default

        if fm.isUbiquitousItem(at: url) && !isFileDownloaded(url) {
            isDownloading = true

            DispatchQueue.global().async {
                do {
                    try fm.startDownloadingUbiquitousItem(at: url)

                    for _ in 0..<120 {
                        Thread.sleep(forTimeInterval: 0.5)
                        if self.isFileDownloaded(url) {
                            Thread.sleep(forTimeInterval: 0.5)
                            DispatchQueue.main.async {
                                self.isDownloading = false
                                self.copyAndOpen(url)
                            }
                            return
                        }
                    }

                    DispatchQueue.main.async {
                        self.isDownloading = false
                        url.stopAccessingSecurityScopedResource()
                        self.showError("iCloud에서 다운로드할 수 없습니다.\nFiles 앱에서 먼저 열어주세요.")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        url.stopAccessingSecurityScopedResource()
                        self.showError("다운로드 오류: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            copyAndOpen(url)
        }
    }

    private func copyAndOpen(_ url: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(url.lastPathComponent)

        try? FileManager.default.removeItem(at: localURL)

        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            url.stopAccessingSecurityScopedResource()
            openFile(localURL)
        } catch {
            openFile(url)
        }
    }

    private func openFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf", "ppt", "pptx", "doc", "docx", "xls", "xlsx", "hwp", "hwpx":
            fileType = .webviewable
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff":
            fileType = .image
        default:
            fileType = .other
        }

        selectedURL = url
    }

    private func isFileDownloaded(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if values?.ubiquitousItemDownloadingStatus == .current {
            return true
        }
        if FileManager.default.fileExists(atPath: url.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int ?? 0
            return size > 0
        }
        return false
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - WebView로 문서 열기 (PDF, PPT, DOCX, HWP, Excel)

struct WebDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.minimumZoomScale = 0.5
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.bouncesZoom = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - 핀치 줌 가능한 이미지 뷰어

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        imageView.frame = scrollView.bounds
        imageView.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }
    }
}

// MARK: - QuickLook 폴백 (기타 파일)

struct QuickLookFallback: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator

        let container = UIViewController()
        container.addChild(controller)
        container.view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: container.view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor)
        ])
        controller.didMove(toParent: container)

        return container
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: - Document Picker Delegate

final class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let onPick: (URL) -> Void

    init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick(url)
    }
}
