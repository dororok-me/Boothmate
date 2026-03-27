import SwiftUI
import QuickLook
import UniformTypeIdentifiers

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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .presentation, .image, .plainText, .rtf, .data]
        ) { result in
            switch result {
            case .success(let url):
                let didAccess = url.startAccessingSecurityScopedResource()
                selectedFileURL = url
                if didAccess {
                    defer { url.stopAccessingSecurityScopedResource() }
                }
            case .failure:
                break
            }
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

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
