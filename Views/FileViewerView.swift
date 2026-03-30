import SwiftUI
import WebKit
import QuickLook
import UniformTypeIdentifiers
import UIKit

struct FileViewerView: View {

    // MARK: - State

    @State private var selectedURL: URL?
    @State private var loadedImage: UIImage?
    @State private var fileType: FileType = .none
    @State private var isDownloading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var pickerDelegate: DocumentPickerDelegate?
    @State private var fileKey = UUID()

    enum FileType {
        case none, webviewable, image, other
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            switch fileType {
            case .none:
                Button(action: { pickFile() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.35))
                }
                .buttonStyle(.plain)

            case .webviewable:
                if let url = selectedURL {
                    WebDocumentView(url: url)
                        .id(fileKey)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .image:
                if let image = loadedImage {
                    ZoomableImageView(image: image)
                        .id(fileKey)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .other:
                if let url = selectedURL {
                    QuickLookFallback(url: url)
                        .id(fileKey)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground).opacity(0.8))
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

    // MARK: - File Picker

    private func pickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true

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

    // MARK: - File Handling

    private func handlePickedFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError("파일 접근 권한이 없습니다.")
            return
        }

        let fm = FileManager.default

        // iCloud 파일 다운로드
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
                                self.processFile(url)
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
            processFile(url)
        }
    }

    private func processFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        // 이미지: 보안 접근 중 바로 메모리 로드
        if isImageExtension(ext) {
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                url.stopAccessingSecurityScopedResource()
                loadedImage = image
                fileType = .image
                selectedURL = url
                fileKey = UUID()
                return
            }
            // 실패 시 복사 후 재시도
            if let localURL = copyToTemp(url) {
                if let data = try? Data(contentsOf: localURL),
                   let image = UIImage(data: data) {
                    loadedImage = image
                    fileType = .image
                    selectedURL = localURL
                    fileKey = UUID()
                    return
                }
            }
            url.stopAccessingSecurityScopedResource()
            showError("이미지를 열 수 없습니다.")
            return
        }

        // 문서 파일: 복사 후 열기
        if let localURL = copyToTemp(url) {
            openFile(localURL)
        } else {
            // 복사 실패 시 원본으로 시도
            openFile(url)
        }
    }

    private func copyToTemp(_ url: URL) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(url.lastPathComponent)

        try? FileManager.default.removeItem(at: localURL)

        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            url.stopAccessingSecurityScopedResource()
            return localURL
        } catch {
            return nil
        }
    }

    private func openFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        if isWebViewExtension(ext) {
            fileType = .webviewable
        } else if isImageExtension(ext) {
            fileType = .image
        } else {
            fileType = .other
        }

        selectedURL = url
        fileKey = UUID()
    }

    // MARK: - Extension Check

    private func isImageExtension(_ ext: String) -> Bool {
        ["jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp", "svg"].contains(ext)
    }

    private func isWebViewExtension(_ ext: String) -> Bool {
        ["pdf", "ppt", "pptx", "doc", "docx", "xls", "xlsx", "hwp", "hwpx",
         "csv", "txt", "rtf", "html", "htm", "xml", "json"].contains(ext)
    }

    // MARK: - Helpers

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

// MARK: - WebView 문서 뷰어

struct WebDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.minimumZoomScale = 0.3
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.bouncesZoom = true

        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - 핀치 줌 이미지 뷰어

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.1
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        DispatchQueue.main.async {
            context.coordinator.fitImage(in: scrollView)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        imageView.image = image

        DispatchQueue.main.async {
            context.coordinator.fitImage(in: scrollView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        private var lastBounds: CGRect = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        func fitImage(in scrollView: UIScrollView) {
            guard let imageView = imageView, let image = imageView.image else { return }
            guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
            guard scrollView.bounds != lastBounds else { return }
            lastBounds = scrollView.bounds

            let boundsSize = scrollView.bounds.size
            let imageSize = image.size

            let widthScale = boundsSize.width / imageSize.width
            let heightScale = boundsSize.height / imageSize.height
            let minScale = min(widthScale, heightScale)

            scrollView.minimumZoomScale = minScale * 0.5
            scrollView.maximumZoomScale = max(minScale * 5, 3.0)
            scrollView.zoomScale = minScale

            imageView.frame = CGRect(
                x: 0, y: 0,
                width: imageSize.width * minScale,
                height: imageSize.height * minScale
            )

            scrollView.contentSize = imageView.frame.size
            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            frameToCenter.origin.x = frameToCenter.size.width < boundsSize.width
                ? (boundsSize.width - frameToCenter.size.width) / 2 : 0
            frameToCenter.origin.y = frameToCenter.size.height < boundsSize.height
                ? (boundsSize.height - frameToCenter.size.height) / 2 : 0

            imageView.frame = frameToCenter
        }
    }
}

// MARK: - QuickLook 폴백

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
