import SwiftUI
import UniformTypeIdentifiers

struct GlossaryView: View {
    @ObservedObject var glossaryStore: GlossaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var newSource = ""
    @State private var newTarget = ""
    @State private var newSynonyms = "" // 유의어 입력 상태 추가
    @State private var searchText = ""

    @State private var showDeleteAllAlert = false
    @State private var showImporter = false
    @State private var showExporter = false

    @State private var selectedEntry: GlossaryStore.GlossaryEntry?
    @State private var editSource = ""
    @State private var editTarget = ""
    @State private var editSynonyms = "" // 유의어 수정 상태 추가
    @State private var showEditSheet = false
    @State private var showDeleteEntryAlert = false

    private var filteredEntries: [GlossaryStore.GlossaryEntry] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return glossaryStore.entries
        }

        return glossaryStore.entries.filter {
            $0.source.localizedCaseInsensitiveContains(searchText) ||
            $0.target.localizedCaseInsensitiveContains(searchText) ||
            $0.synonyms.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addSection
                searchSection
                countSection
                listSection
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

                        if !glossaryStore.entries.isEmpty {
                            Divider()

                            Button(role: .destructive) {
                                showDeleteAllAlert = true
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
            .alert("전체 삭제", isPresented: $showDeleteAllAlert) {
                Button("삭제", role: .destructive) {
                    glossaryStore.deleteAll()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("글로서리 항목을 모두 삭제하시겠습니까?")
            }
            .alert("항목 삭제", isPresented: $showDeleteEntryAlert) {
                Button("삭제", role: .destructive) {
                    deleteSelectedEntry()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("이 항목을 삭제하시겠습니까?")
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                if case .success(let url) = result {
                    glossaryStore.importCSV(from: url)
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: CSVDocument(entries: glossaryStore.entries),
                contentType: .commaSeparatedText,
                defaultFilename: "glossary.csv"
            ) { _ in }
            .sheet(isPresented: $showEditSheet) {
                editSheet
            }
        }
    }

    private var addSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField("원어", text: $newSource)
                    .textFieldStyle(.roundedBorder)

                TextField("번역/설명", text: $newTarget)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addEntry()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            TextField("유의어 (콤마로 구분: AI, A.I.)", text: $newSynonyms)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
        .padding()
    }

    private var searchSection: some View {
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
    }

    private var countSection: some View {
        HStack {
            Text("\(filteredEntries.count)개 항목")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var listSection: some View {
        List {
            ForEach(filteredEntries) { entry in
                Button {
                    openEditSheet(for: entry)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.source)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Spacer()

                            Text(entry.target)
                                .foregroundColor(.gray)
                        }
                        
                        if !entry.synonyms.isEmpty {
                            Text(entry.synonyms.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.blue.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onDelete { offsets in
                let entriesToDelete = offsets.map { filteredEntries[$0] }
                for entry in entriesToDelete {
                    deleteEntry(id: entry.id)
                }
            }
        }
    }

    private var editSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("원어").font(.caption).foregroundColor(.gray)
                    TextField("원어", text: $editSource)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("번역/설명").font(.caption).foregroundColor(.gray)
                    TextField("번역/설명", text: $editTarget)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("유의어 (콤마로 구분)").font(.caption).foregroundColor(.gray)
                    TextField("유의어", text: $editSynonyms)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("글로서리 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteEntryAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }

                    Button {
                        saveEditedEntry()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    private func addEntry() {
        let source = newSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = newTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let synonymsArray = newSynonyms.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !source.isEmpty, !target.isEmpty else { return }

        glossaryStore.add(source: source, target: target, synonyms: synonymsArray)
        newSource = ""
        newTarget = ""
        newSynonyms = ""
    }

    private func openEditSheet(for entry: GlossaryStore.GlossaryEntry) {
        selectedEntry = entry
        editSource = entry.source
        editTarget = entry.target
        editSynonyms = entry.synonyms.joined(separator: ", ")
        showEditSheet = true
    }

    private func saveEditedEntry() {
        guard let selectedEntry else { return }

        let source = editSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = editTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let synonymsArray = editSynonyms.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !source.isEmpty, !target.isEmpty else { return }

        guard let index = glossaryStore.entries.firstIndex(where: { $0.id == selectedEntry.id }) else {
            showEditSheet = false
            return
        }

        glossaryStore.entries[index].source = source
        glossaryStore.entries[index].target = target
        glossaryStore.entries[index].synonyms = synonymsArray
        glossaryStore.save()
        showEditSheet = false
    }

    private func deleteSelectedEntry() {
        guard let selectedEntry else { return }
        deleteEntry(id: selectedEntry.id)
        showEditSheet = false
    }

    private func deleteEntry(id: UUID) {
        glossaryStore.entries.removeAll { $0.id == id }
        glossaryStore.save()
    }
}

// MARK: - CSV Document Export logic
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
        // 유의어까지 내보내기 위해 헤더 수정
        var csv = "source,target,synonyms\n"

        for entry in entries {
            let source = entry.source.replacingOccurrences(of: ",", with: "，")
            let target = entry.target.replacingOccurrences(of: ",", with: "，")
            // 유의어는 세미콜론(;)으로 구분하여 저장 (CSV 파싱 오류 방지)
            let synonyms = entry.synonyms.joined(separator: ";").replacingOccurrences(of: ",", with: "，")
            csv += "\(source),\(target),\(synonyms)\n"
        }

        return FileWrapper(regularFileWithContents: Data(csv.utf8))
    }
}
