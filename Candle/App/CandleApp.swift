import SwiftData
import SwiftUI

@main
struct CandleApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.hub)
                .environment(environment.settings)
                .environment(environment.trading)
                .modelContainer(environment.container)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
