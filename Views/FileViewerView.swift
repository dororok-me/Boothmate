import SwiftUI
import QuickLook
import UniformTypeIdentifiers
import UIKit

struct FileViewerView: View {
    @State private var selectedURL: URL?
    @State private var isDownloading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var pickerDelegate: DocumentPickerDelegate?

    var body: some View {
            ZStack {
                if let url = selectedURL {
                    QuickLookPreview(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color(UIColor.systemBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
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

        rootVC.present(picker, animated: true)
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
            selectedURL = localURL
        } catch {
            selectedURL = url
        }
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

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: controller)
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }

    func updateUIViewController(_ nav: UINavigationController, context: Context) {
        nav.setNavigationBarHidden(true, animated: false)
    }

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
