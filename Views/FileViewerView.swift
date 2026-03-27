import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct FileViewerView: View {
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var importErrorMessage: String?

    var body: some View {
        ZStack {
            if let url = selectedFileURL {
                QuickLookPreview(url: url)
            } else {
                Color(.systemBackground)

                Text("No file selected")
                    .foregroundColor(.secondary)
            }

            if let message = importErrorMessage {
                VStack {
                    Spacer()

                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 12)
                }
            }

            VStack {
                HStack {
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding(10)

                    Spacer()
                }

                Spacer()
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importErrorMessage = nil
                selectedFileURL = url

            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [
            .pdf,
            .image,
            .png,
            .jpeg,
            .heic,
            .tiff,
            .plainText,
            .rtf,
            .text,
            .commaSeparatedText,
            .json,
            .xml,
            .spreadsheet,
            .presentation,
            .data,
            .content
        ]

        ["docx", "xlsx", "pptx", "pages", "numbers", "key"].forEach { ext in
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }

        return types
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

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
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
