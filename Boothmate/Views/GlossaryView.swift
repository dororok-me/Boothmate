import SwiftUI
import Combine

struct GlossaryView: View {
    @ObservedObject var glossaryStore: GlossaryStore
    @Environment(\.dismiss) var dismiss

    @State private var newSource = ""
    @State private var newTarget = ""
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                List {
                    ForEach(glossaryStore.entries) { entry in
                        HStack {
                            Text(entry.source)
                                .fontWeight(.bold)
                            Spacer()
                            Text(entry.target)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: glossaryStore.delete)
                }
            }
            .navigationTitle("글로서리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !glossaryStore.entries.isEmpty {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Text("전체 삭제")
                                .foregroundColor(.red)
                        }
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
        }
    }
}
