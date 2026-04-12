import SwiftUI

struct RootView: View {
    @State private var splashFinished: Bool = false

    var body: some View {
        ZStack {
            // 메인 앱
            ContentView()
                .opacity(splashFinished ? 1 : 0)

            // 스플래시
            if !splashFinished {
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: splashFinished)
    }
}
