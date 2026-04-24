import SwiftUI
import OSLog
import SixthSeat

private let smokeLog = Logger(subsystem: "com.sixthseat.uth", category: "smoke")

struct ContentView: View {
    @State private var viewModel = GameTableViewModel()

    var body: some View {
        GameTableView(viewModel: viewModel)
            .onAppear {
                // Headless verification hook: when launched with the env var
                // SIXTHSEAT_SMOKE_TEST=1, run one full hand through the
                // view model so CI / session-end checks can confirm the
                // engine + view-model pipeline works at runtime.
                if ProcessInfo.processInfo.environment["SIXTHSEAT_SMOKE_TEST"] == "1" {
                    runSmokeTestHand()
                }
            }
    }

    private func runSmokeTestHand() {
        viewModel.placeAnte(amount: 10)
        viewModel.deal()
        viewModel.checkPreFlop()
        viewModel.checkPostFlop()
        viewModel.betPostRiver()

        if let result = viewModel.lastHandResult {
            let message = "Smoke -> player=\(result.playerHand.rank) balance=\(viewModel.chipBalance)"
            print(message)
            smokeLog.notice("\(message, privacy: .public)")
        }
    }
}

#Preview {
    ContentView()
}
