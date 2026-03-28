import SwiftUI
import QuickLook
import UniformTypeIdentifiers
import UIKit

struct FileViewerView: View {
    @State private var selectedURL: URL?
    @State private var isDownloading = false
    @State private var showAlert = false
    @State private var alertMessage = false ? "" : ""
    @State private var pickerDelegate: DocumentPickerDelegate?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                            Spacer()
                            Button(action: { pickFile() }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                            .padding(6)
                        }

            if let url = selectedURL {
                QuickLookPreview(url: url)
            } else {
                VStack {
                    Spacer()
                    Text("파일을 선택하세요")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .alert("파일 열기 실패", isPresented: $showAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
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

        if isUbiquitous(url) && !isDownloaded(url) {
            isDownloading = true

            downloadFromiCloud(url) { success in
                DispatchQueue.main.async {
                    self.isDownloading = false

                    if success {
                        self.selectedURL = url
                    } else {
                        url.stopAccessingSecurityScopedResource()
                        self.showError("파일을 다운로드할 수 없습니다.\nFiles 앱에서 먼저 열어주세요.")
                    }
                }
            }
        } else {
            selectedURL = url
        }
    }

    private func isUbiquitous(_ url: URL) -> Bool {
        FileManager.default.isUbiquitousItem(at: url)
    }

    private func isDownloaded(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        return values?.ubiquitousItemDownloadingStatus == .current
    }

    private func downloadFromiCloud(_ url: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)

                for _ in 0..<30 {
                    Thread.sleep(forTimeInterval: 0.3)

                    if self.isDownloaded(url) {
                        completion(true)
                        return
                    }
                }

                completion(false)
            } catch {
                completion(false)
            }
        }
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

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
