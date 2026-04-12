import SwiftUI

struct GMView: View {
    @ObservedObject var gmStore: GMStore
    @ObservedObject var glossaryStore: GlossaryStore
    var hideHeader: Bool = false

    @State private var selectedWord: String = ""
    @State private var showAddSheet = false
    @State private var showDeleteAllAlert = false

    var body: some View {
        VStack(spacing: 0) {

            // hideHeader가 false일 때만 헤더 표시
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
                // hideHeader일 때 쓰레기통을 리스트 위 우측에 배치
                if hideHeader && !gmStore.entries.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            showDeleteAllAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.6))
                                .padding(8)
                        }
                    }
                    .padding(.trailing, 4)
                }

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
            Button("취소", role: .cancel) {}
        } message: {
            Text("검색 기록을 모두 삭제하시겠습니까?")
        }
        .sheet(isPresented: $showAddSheet) {
            AddToGlossarySheet(
                word: selectedWord,
                glossaryStore: glossaryStore,
                isPresented: $showAddSheet
            )
        }
    }

    private func isInGlossary(_ word: String) -> Bool {
        glossaryStore.entries.contains {
            $0.source.lowercased() == word.lowercased() ||
            $0.target.lowercased() == word.lowercased()
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
    @Binding var isPresented: Bool

    @State private var sourceText: String = ""
    @State private var targetText: String = ""

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
                    Button("취소") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        if !sourceText.isEmpty && !targetText.isEmpty {
                            let entry = GlossaryStore.GlossaryEntry(
                                source: sourceText,
                                target: targetText
                            )
                            glossaryStore.entries.append(entry)
                            glossaryStore.save()
                        }
                        isPresented = false
                    }
                    .disabled(sourceText.isEmpty || targetText.isEmpty)
                }
            }
            .onAppear {
                sourceText = word
            }
        }
    }
}
