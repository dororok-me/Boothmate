import SwiftUI

struct DictionaryView: View {
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("다음 사전")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack {
                TextField("검색어 입력", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button("검색") {
                    // 나중에 구현
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Rectangle()
                .fill(Color(.systemGroupedBackground))
                .overlay(
                    Text("사전 검색 결과가 여기에 표시됩니다")
                        .foregroundColor(.gray)
                )
        }
    }
}
