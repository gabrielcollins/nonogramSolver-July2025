import SwiftUI

struct SplashView: View {
    @State private var manager: GameManager?

    var body: some View {
        Group {
            if let manager = manager {
                ContentView(manager: manager)
            } else {
                ProgressView("Loading...")
                    .task {
                        manager = await GameManagerBuilder().build()
                    }
            }
        }
    }
}

#Preview {
    SplashView()
}
