import SwiftUI
import SixthSeat
import TelemetryDeck

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

    /// One telemetry service for the entire app. Held so
    /// `GameTableViewModel` can report `handResolved` events alongside
    /// the IAP service's purchase events. (Session 19b)
    let telemetryService: TelemetryService

    /// TelemetryDeck app ID. Hardcoded placeholder for Session 19b —
    /// David will replace this with the real ID via App Store Connect /
    /// TelemetryDeck dashboard before the first TestFlight upload.
    /// The placeholder ships in the Release binary intentionally so the
    /// `strings $RELEASE_BINARY` sanity-check in HANDOFF picks it up.
    private static let telemetryDeckAppID = "F5C9AE2A-B805-4266-B39D-69F0ADCEEC83"

    init() {
        // Initialize TelemetryDeck FIRST so any IAP-completion telemetry
        // calls from `iap.startTransactionListener()` below dispatch to
        // a live SDK. Background `Transaction.updates` deliveries that
        // race with app launch otherwise risk firing into a deinitialized
        // singleton.
        //
        // DEBUG builds use the console-logging telemetry service so the
        // dev-loop doesn't burn TelemetryDeck quota with noise; Release
        // dispatches to TelemetryDeck. Both conform to the same
        // `TelemetryService` protocol — the IAP service doesn't know
        // which one it has.
        #if DEBUG
        let telemetry: TelemetryService = LoggingTelemetryService()
        #else
        TelemetryDeck.initialize(
            config: TelemetryDeck.Config(appID: Self.telemetryDeckAppID)
        )
        let telemetry: TelemetryService = TelemetryDeckTelemetryService()
        #endif

        let store = UserDefaultsChipStore()
        let iap = StoreKitIAPService(chipStore: store, telemetry: telemetry)
        iap.startTransactionListener()
        _chipStore = State(initialValue: store)
        _iapService = State(initialValue: iap)
        audioService = AVAudioService()
        telemetryService = telemetry
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                chipStore: chipStore,
                iapService: iapService,
                audioService: audioService,
                telemetryService: telemetryService
            )
            .environment(\.audio, audioService)
        }
    }
}
