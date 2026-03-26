import SwiftUI

struct ContentView: View {
    @State private var horizontalSplit: CGFloat = 0.5
    @State private var verticalSplit: CGFloat = 0.5
    @State private var showSettings = false

    @State private var dragStartH: CGFloat = 0.5
    @State private var dragStartV: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let handleWidth: CGFloat = 8
            let leftWidth = (geo.size.width - handleWidth) * horizontalSplit
            let rightWidth = geo.size.width - leftWidth - handleWidth
            let topHeight = (geo.size.height - handleWidth) * verticalSplit
            
            HStack(spacing: 0) {
                // 왼쪽: 실시간 자막
                SubtitleView()
                    .frame(width: leftWidth)
                    .clipped()

                // 좌우 드래그 핸들
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: handleWidth)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray)
                            .frame(width: 3, height: 30)
                    )
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let new = value.location.x / geo.size.width
                                horizontalSplit = min(max(new, 0.2), 0.8)
                            }
                    )

                // 오른쪽: 파일뷰어 + 사전
                VStack(spacing: 0) {
                    FileViewerView()
                        .frame(width: rightWidth, height: topHeight)
                        .clipped()

                    // 상하 드래그 핸들
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: handleWidth)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray)
                                .frame(width: 30, height: 3)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { value in
                                    let new = value.location.y / geo.size.height
                                    verticalSplit = min(max(new, 0.2), 0.8)
                                }
                        )

                    DictionaryView()
                        .frame(width: rightWidth)
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
            }
        }
        .ignoresSafeArea()
        .transaction { t in
            t.animation = nil
        }
    }
}

#Preview {
    ContentView()
}
