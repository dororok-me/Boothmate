import SwiftUI

struct MemoView: View {
    @State private var memoText = ""

    var body: some View {
        TextEditor(text: $memoText)
            .font(.body)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
    }
}
