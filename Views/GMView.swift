import SwiftUI

// MARK: - sheet(item:)용 Identifiable 래퍼

struct SelectedWordItem: Identifiable {
    let id = UUID()
    let word: String
}

struct GMView: View {
    @ObservedObject var gmStore: GMStore
    @ObservedObject var glossaryStore: GlossaryStore
    var hideHeader: Bool = false
    var toolbarHeight: CGFloat = 32

    @State private var selectedItem: SelectedWordItem? = nil
    @State private var showDeleteAllAlert = false

    var body: some View {
        VStack(spacing: 0) {

            if !hideHeader {
                HStack {
                    Text("검색 기록")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !gmStore.entries.isEmpty {
                        Button {
                            showDeleteAllAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.06))
            }

            if gmStore.entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("단어를 탭하면\n검색 기록이 저장됩니다")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                if hideHeader && !gmStore.entries.isEmpty {
                    HStack {
                        Button {
                            showDeleteAllAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.6))
                                .frame(width: 28, height: 28)
                        }
                        .padding(.leading, 8)
                        Spacer()
                    }
                    .frame(height: toolbarHeight)
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle().frame(height: 0.5).foregroundColor(Color(.systemGray5)),
                        alignment: .bottom
                    )
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(gmStore.entries) { entry in
                            GMEntryRow(
                                entry: entry,
                                isInGlossary: isInGlossary(entry.word),
                                onAdd: {
                                    selectedItem = SelectedWordItem(word: entry.word)
                                },
                                onDelete: {
                                    if let idx = gmStore.entries.firstIndex(where: { $0.id == entry.id }) {
                                        gmStore.delete(at: IndexSet(integer: idx))
                                    }
                                }
                            )
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .alert("기록 전체 삭제", isPresented: $showDeleteAllAlert) {
            Button("삭제", role: .destructive) { gmStore.deleteAll() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("검색 기록을 모두 삭제하시겠습니까?")
        }
        .sheet(item: $selectedItem) { item in
            AddToGlossarySheet(
                word: item.word,
                glossaryStore: glossaryStore,
                onDismiss: { selectedItem = nil }
            )
        }
    }

    private func isInGlossary(_ word: String) -> Bool {
        glossaryStore.entries.contains {
            $0.source.lowercased() == word.lowercased() ||
            $0.target.lowercased() == word.lowercased()
        }
    }
}

// MARK: - 개별 행

struct GMEntryRow: View {
    let entry: GMStore.GMEntry
    let isInGlossary: Bool
    let onAdd: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isInGlossary {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green.opacity(0.7))
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.word)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(timeAgo(entry.addedAt))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "방금 전" }
        if diff < 3600 { return "\(Int(diff/60))분 전" }
        if diff < 86400 { return "\(Int(diff/3600))시간 전" }
        return "\(Int(diff/86400))일 전"
    }
}

// MARK: - 글로서리 추가 Sheet

struct AddToGlossarySheet: View {
    let word: String
    @ObservedObject var glossaryStore: GlossaryStore
    let onDismiss: () -> Void

    // State 없이 word를 직접 TextField에 바인딩
    @State private var sourceText: String
    @State private var targetText: String = ""

    init(word: String, glossaryStore: GlossaryStore, onDismiss: @escaping () -> Void) {
        self.word = word
        self.glossaryStore = glossaryStore
        self.onDismiss = onDismiss
        // _sourceText를 init에서 word로 초기화 — sheet(item:)이 매번 새 인스턴스를 만들어서 안전
        self._sourceText = State(initialValue: word)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("원어") {
                    TextField("원어", text: $sourceText)
                }
                Section("번역") {
                    TextField("번역어", text: $targetText)
                }
            }
            .navigationTitle("글로서리 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        if !sourceText.isEmpty && !targetText.isEmpty {
                            glossaryStore.entries.append(
                                GlossaryStore.GlossaryEntry(
                                    source: sourceText,
                                    target: targetText
                                )
                            )
                            glossaryStore.save()
                        }
                        onDismiss()
                    }
                    .disabled(sourceText.isEmpty || targetText.isEmpty)
                }
            }
        }
    }
}
