import Testing
@testable import SixthSeat

/// Smoke tests for the app target — verifies the SixthSeat package
/// is linked and its types are reachable at runtime in the app.
@Suite("App smoke tests")
struct SmokeTests {

    @Test("GameState completes a full hand using InMemoryChipStore")
    func fullHandCompletes() {
        let store = InMemoryChipStore(chipBalance: 1_000)
        let game = GameState(chipStore: store)

        #expect(game.perform(.placeAnte(amount: 10)).isSuccess)
        #expect(game.perform(.deal).isSuccess)
        #expect(game.perform(.checkPreFlop).isSuccess)
        #expect(game.perform(.checkPostFlop).isSuccess)
        #expect(game.perform(.betPostRiver).isSuccess)

        #expect(game.phase == .handComplete)
        #expect(game.lastHandResult != nil)
    }
}

private extension Result where Success == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
