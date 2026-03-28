import SwiftUI

struct MemoView: View {
    @State private var memoText = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $memoText)
                .font(.body)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.systemBackground))

            Image(systemName: "note.text")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.4))
                .padding(8)
        }
    }
}
