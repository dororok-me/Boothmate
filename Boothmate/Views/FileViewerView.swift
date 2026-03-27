import SwiftUI
import QuickLook

struct FileViewerView: View {
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?

    var body: some View {
        ZStack {
            if let url = selectedFileURL {
                QuickLookPreview(url: url)
            } else {
                Color(UIColor.systemBackground)
            }

            // 오른쪽 상단 + 버튼
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .background(Color.white.clipShape(Circle()))
                    }
                    .padding(8)
                }
                Spacer()
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .presentation, .image, .plainText, .rtf, .data]) { result in
            if case .success(let url) = result {
                if url.startAccessingSecurityScopedResource() {
                    selectedFileURL = url
                }
            }
        }
    }
}

// QuickLook으로 파일 미리보기
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}
