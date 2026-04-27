import SwiftUI
import SixthSeat

@main
struct SixthSeatApp: App {

    /// One persistence boundary for the entire app. Menu and game
    /// read from and write to the same store, so bankroll survives
    /// menu↔game transitions and process relaunches.
    @State private var chipStore = UserDefaultsChipStore()

    var body: some Scene {
        WindowGroup {
            ContentView(chipStore: chipStore)
        }
    }
}
