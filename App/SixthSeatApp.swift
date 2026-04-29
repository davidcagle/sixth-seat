import SwiftUI
import SixthSeat

@main
struct SixthSeatApp: App {

    /// One persistence boundary for the entire app. Menu and game
    /// read from and write to the same store, so bankroll survives
    /// menu↔game transitions and process relaunches.
    @State private var chipStore: UserDefaultsChipStore

    /// One IAP service for the entire app. Owns the long-running
    /// `Transaction.updates` listener — started here at launch so
    /// purchases that complete outside the active session (Family
    /// Sharing, retried network calls, interrupted flows) credit chips
    /// the next time the process is alive.
    @State private var iapService: StoreKitIAPService

    init() {
        let store = UserDefaultsChipStore()
        let iap = StoreKitIAPService(chipStore: store)
        iap.startTransactionListener()
        _chipStore = State(initialValue: store)
        _iapService = State(initialValue: iap)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(chipStore: chipStore, iapService: iapService)
        }
    }
}
