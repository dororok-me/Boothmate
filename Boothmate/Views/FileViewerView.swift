import SwiftUI

struct FileViewerView: View {
    var body: some View {
        VStack {
            HStack {
                Text("파일 뷰어")
                    .font(.headline)
                Spacer()
                Button("파일 열기") {
                    // 나중에 구현
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            Text("PPT, DOCX, PDF, JPG 파일을 열 수 있습니다")
                .foregroundColor(.gray)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
