import SwiftUI
import OSLog
import SixthSeat

private let smokeLog = Logger(subsystem: "com.sixthseat.uth", category: "smoke")

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("6th Seat")
                .font(.largeTitle)
                .bold()
            Text("Ultimate Texas Hold'em")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Deal Hand", action: dealSmokeTestHand)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            // Headless verification hook: when launched with the env var
            // SIXTHSEAT_SMOKE_TEST=1, fire the same action the button does.
            // Lets CI / session-end verification confirm the engine runs at
            // runtime without needing to synthesize a UI tap.
            if ProcessInfo.processInfo.environment["SIXTHSEAT_SMOKE_TEST"] == "1" {
                dealSmokeTestHand()
            }
        }
    }

    private func dealSmokeTestHand() {
        let store = InMemoryChipStore(chipBalance: 1_000)
        let game = GameState(chipStore: store)

        _ = game.perform(.placeAnte(amount: 10))
        _ = game.perform(.deal)
        _ = game.perform(.checkPreFlop)
        _ = game.perform(.checkPostFlop)
        _ = game.perform(.betPostRiver)

        if let result = game.lastHandResult {
            let hand = result.playerHand
            let tiebreakers = hand.tiebreakers.map(String.init).joined(separator: ",")
            let message = "Deal Hand -> \(hand.rank) [tiebreakers: \(tiebreakers)] | chipBalance=\(game.chipBalance)"
            print(message)
            smokeLog.notice("\(message, privacy: .public)")
        } else {
            let message = "Deal Hand -> no result (phase=\(game.phase))"
            print(message)
            smokeLog.notice("\(message, privacy: .public)")
        }
    }
}

#Preview {
    ContentView()
}
