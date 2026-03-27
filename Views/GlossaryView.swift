import SwiftUI
import Combine
import UniformTypeIdentifiers

struct GlossaryView: View {
    @ObservedObject var glossaryStore: GlossaryStore
    @Environment(\.dismiss) var dismiss

    @State private var newSource = ""
    @State private var newTarget = ""
    @State private var searchText = ""
    @State private var showDeleteAlert = false
    @State private var showImporter = false
    @State private var showExporter = false

    var filteredEntries: [GlossaryStore.GlossaryEntry] {
        if searchText.isEmpty {
            return glossaryStore.entries
        }
        return glossaryStore.entries.filter {
            $0.source.localizedCaseInsensitiveContains(searchText) ||
            $0.target.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 새 항목 추가
                HStack {
                    TextField("원어", text: $newSource)
                        .textFieldStyle(.roundedBorder)
                    TextField("번역/설명", text: $newTarget)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard !newSource.isEmpty else { return }
                        glossaryStore.add(source: newSource, target: newTarget)
                        newSource = ""
                        newTarget = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()

                // 검색바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("글로서리 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // 항목 수 표시
                HStack {
                    Text("\(filteredEntries.count)개 항목")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                // 글로서리 목록
                List {
                    ForEach(filteredEntries) { entry in
                        HStack {
                            Text(entry.source)
                                .fontWeight(.bold)
                            Spacer()
                            Text(entry.target)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete { offsets in
                        let entriesToDelete = offsets.map { filteredEntries[$0] }
                        for entry in entriesToDelete {
                            if let index = glossaryStore.entries.firstIndex(where: { $0.id == entry.id }) {
                                glossaryStore.entries.remove(at: index)
                            }
                        }
                        glossaryStore.save()
                    }
                }
            }
            .navigationTitle("글로서리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showImporter = true
                        } label: {
                            Label("CSV 가져오기", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            showExporter = true
                        } label: {
                            Label("CSV 내보내기", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        if !glossaryStore.entries.isEmpty {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("전체 삭제", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert("전체 삭제", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    glossaryStore.deleteAll()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("글로서리를 모두 삭제하시겠습니까?")
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                if case .success(let url) = result {
                    glossaryStore.importCSV(from: url)
                }
            }
            .fileExporter(isPresented: $showExporter, document: CSVDocument(entries: glossaryStore.entries), contentType: .commaSeparatedText, defaultFilename: "glossary.csv") { _ in }
        }
    }
}

// CSV 내보내기용 Document
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var entries: [GlossaryStore.GlossaryEntry]

    init(entries: [GlossaryStore.GlossaryEntry]) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        entries = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var csv = "source,target\n"
        for entry in entries {
            let source = entry.source.replacingOccurrences(of: ",", with: "，")
            let target = entry.target.replacingOccurrences(of: ",", with: "，")
            csv += "\(source),\(target)\n"
        }
        return FileWrapper(regularFileWithContents: csv.data(using: .utf8)!)
    }
}
