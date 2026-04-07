import SwiftUI

struct GMView: View {
    @ObservedObject var gmStore: GMStore
    @ObservedObject var glossaryStore: GlossaryStore

    @State private var selectedWord: String = ""
    @State private var showAddSheet = false
    @State private var showDeleteAllAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("글로서리 검색 리스트")
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
                List {
                    ForEach(gmStore.entries) { entry in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.word)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(timeAgo(entry.addedAt))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isInGlossary(entry.word) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green.opacity(0.7))
                            } else {
                                Button {
                                    selectedWord = entry.word
                                    showAddSheet = true
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        gmStore.delete(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("기록 전체 삭제", isPresented: $showDeleteAllAlert) {
            Button("삭제", role: .destructive) { gmStore.deleteAll() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("검색 기록을 모두 삭제하시겠습니까?")
        }
        .sheet(isPresented: $showAddSheet) {
            AddToGlossarySheet(word: selectedWord) { source, target in
                glossaryStore.add(source: source, target: target)
                showAddSheet = false
            } onCancel: {
                showAddSheet = false
            }
            .presentationDetents([.fraction(0.35)])
            .presentationDragIndicator(.visible)
        }
    }

    private func isInGlossary(_ word: String) -> Bool {
        let lower = word.lowercased()
        return glossaryStore.entries.contains(where: {
            $0.source.lowercased() == lower ||
            $0.target.lowercased() == lower ||
            $0.synonyms.contains(where: { $0.lowercased() == lower })
        })
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "방금" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86400 { return "\(seconds / 3600)시간 전" }
        return "\(seconds / 86400)일 전" 
    }
}

// MARK: - 글로서리 추가 시트

struct AddToGlossarySheet: View {
    let word: String
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void

    @State private var sourceText: String = ""
    @State private var targetText: String = ""

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Button("취소") { onCancel() }
                        .foregroundColor(.blue)
                    Spacer()
                    Text("글로서리에 추가")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button("추가") {
                        let s = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let t = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !s.isEmpty, !t.isEmpty else { return }
                        onAdd(s, t)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(canAdd ? .blue : .gray)
                    .disabled(!canAdd)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("원어")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("원어", text: $sourceText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("번역/설명")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("번역 또는 설명 입력", text: $targetText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16))
                    }
                }
                .padding(20)

                Spacer()
            }
        }
        .onAppear {
            sourceText = word
        }
    }

    private var canAdd: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
