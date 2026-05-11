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

    /// One audio service for the entire app. Configures
    /// `AVAudioSession` for `.ambient` + `.mixWithOthers` on
    /// construction (iOS only) so SFX coexist with the player's
    /// background music. Caches one `AVAudioPlayer` per SFX so
    /// repeated plays don't pay disk-load cost. (Session 19a)
    private let audioService: AudioService

    init() {
        let store = UserDefaultsChipStore()
        let iap = StoreKitIAPService(chipStore: store)
        iap.startTransactionListener()
        _chipStore = State(initialValue: store)
        _iapService = State(initialValue: iap)
        audioService = AVAudioService()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                chipStore: chipStore,
                iapService: iapService,
                audioService: audioService
            )
            .environment(\.audio, audioService)
        }
    }
}
