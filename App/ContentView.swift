import SwiftUI
import OSLog
import SixthSeat

private let smokeLog = Logger(subsystem: "com.sixthseat.uth", category: "smoke")

/// Top-level shell. Hosts the menu inside a `NavigationStack` and
/// owns the route table for pushing into the game and stub
/// destinations. The `chipStore` reference is passed down so menu
/// and game share one persistence boundary — the same instance
/// across every navigation.
struct ContentView: View {

    let chipStore: ChipStoreProtocol

    @State private var path: [MenuDestination] = []
    @State private var didRunSmokeTest = false

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuView(chipStore: chipStore, path: $path)
                .onAppear { runSmokeTestIfRequested() }
                .navigationDestination(for: MenuDestination.self) { destination in
                    switch destination {
                    case .game:
                        GameDestinationView(chipStore: chipStore)
                    case .chipShop:
                        ChipShopView()
                    case .settings:
                        SettingsView()
                    case .howToPlay:
                        HowToPlayView()
                    }
                }
        }
    }

    private func runSmokeTestIfRequested() {
        guard !didRunSmokeTest else { return }
        guard ProcessInfo.processInfo.environment["SIXTHSEAT_SMOKE_TEST"] == "1" else { return }
        didRunSmokeTest = true
        let vm = GameTableViewModel(chipStore: chipStore)
        vm.placeAnte(amount: 10)
        vm.deal()
        vm.checkPreFlop()
        vm.checkPostFlop()
        vm.betPostRiver()
        if let result = vm.lastHandResult {
            let message = "Smoke -> player=\(result.playerHand.rank) balance=\(vm.chipBalance)"
            print(message)
            smokeLog.notice("\(message, privacy: .public)")
        }
    }
}

/// Wraps `GameTableView` with a `@State`-owned view model so
/// `navigationDestination` re-evaluation doesn't recreate engine
/// state mid-hand. The view model is constructed once when this
/// destination is pushed and torn down with the view on pop.
private struct GameDestinationView: View {

    @State private var viewModel: GameTableViewModel

    init(chipStore: ChipStoreProtocol) {
        _viewModel = State(initialValue: GameTableViewModel(chipStore: chipStore))
    }

    var body: some View {
        GameTableView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(chipStore: InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true))
}
