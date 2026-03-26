import SwiftUI

struct SubtitleView: View {
    var body: some View {
        VStack {
            HStack {
                Text("실시간 자막")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                Text("여기에 실시간 자막이 표시됩니다...")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Spacer()
        }
        .background(Color.black)
    }
}
