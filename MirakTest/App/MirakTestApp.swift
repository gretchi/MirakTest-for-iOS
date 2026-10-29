import SwiftUI

@main
struct MirakTestApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.player)
        }
    }
}
