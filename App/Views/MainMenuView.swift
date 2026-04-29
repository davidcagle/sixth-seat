import SwiftUI
import SixthSeat

/// Routes the main menu can push onto the navigation stack.
enum MenuDestination: Hashable {
    /// Launch the game directly at a specific table. Carries the
    /// `TableConfig.id` (not the config itself) so the route stays
    /// `Hashable` and survives `NavigationPath` round-tripping. The
    /// destination view resolves the id via `TableConfig.table(forID:)`.
    case game(tableID: String)
    case tableSelect
    case chipShop
    case settings
    case howToPlay
}

/// Pure helpers backing `MainMenuView`'s decision logic. Extracted so
/// the rules (Play enabled state, second-chance bonus trigger,
/// busted-message visibility) are unit-testable without instantiating
/// the SwiftUI view hierarchy.
enum MainMenuLogic {

    /// V1 default table minimum stake. Mirrors the engine's smallest
    /// chip denomination so the menu and the bet zones agree on what
    /// "minimum" means.
    static let tableMinimumStake = GameConstants.minimumChipValue

    /// Smallest balance at which a hand is playable: enough to cover
    /// Ante + Blind at the cycle floor. Below this the player is
    /// functionally bust. (Session 12d)
    static let minimumPlayableBalance = GameConstants.minimumPlayableBalance

    /// Play is enabled when the player can afford the minimum playable
    /// balance OR is functionally bust but still has the second-chance
    /// bonus to claim. Sub-threshold non-zero balances (1–9) on a
    /// rescue-spent store are disabled — the bust modal owns that
    /// state and routes to the Chip Shop.
    static func playEnabled(balance: Int, hasUsedSecondChance: Bool) -> Bool {
        if balance >= minimumPlayableBalance { return true }
        if !hasUsedSecondChance { return true }
        return false
    }

    /// "Visit Chip Shop to continue" hint: below the playable threshold
    /// with no rescue left.
    static func showsBustedHint(balance: Int, hasUsedSecondChance: Bool) -> Bool {
        balance < minimumPlayableBalance && hasUsedSecondChance
    }

    /// Apply the second-chance bonus on game-entry if eligible. The
    /// menu is the trigger point — `BonusLogic` itself is unchanged.
    /// Returns whether the player should be allowed to navigate to
    /// the game after this call (i.e. `playEnabled` post-mutation).
    ///
    /// The starter-received gate is critical: on a fresh install the
    /// chip balance is already zero, and without this guard the
    /// second-chance bonus would fire alongside the starter bonus and
    /// stack to 7,500. Second-chance is reserved for the post-bust
    /// path — only after the starter has been awarded does it apply.
    @discardableResult
    static func handlePlayTap(store: ChipStoreProtocol) -> Bool {
        if store.chipBalance < minimumPlayableBalance
            && store.hasReceivedStarterBonus
            && !store.hasReceivedSecondChanceBonus {
            BonusLogic.applySecondChanceBonusIfEligible(store: store)
        }
        return playEnabled(
            balance: store.chipBalance,
            hasUsedSecondChance: store.hasReceivedSecondChanceBonus
        )
    }

    static func formatBalance(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

/// Front-of-app screen. Frames the title, the player's current
/// bankroll, and the four entry points (Play, Chip Shop, Settings,
/// How to Play). Holds local state mirrored from `chipStore` and
/// refreshes on `.onAppear` so the displayed balance updates after
/// returning from the game.
struct MainMenuView: View {

    let chipStore: ChipStoreProtocol
    @Binding var path: [MenuDestination]

    @State private var balance: Int = 0
    @State private var hasUsedSecondChance: Bool = false

    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer().frame(height: 12)
                titleSection
                balanceSection
                Spacer()
                playButton
                if MainMenuLogic.showsBustedHint(balance: balance, hasUsedSecondChance: hasUsedSecondChance) {
                    Text("Visit Chip Shop to continue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .accessibilityIdentifier("MainMenu.BustedHint")
                }
                secondaryButtons
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refresh() }
    }

    private func refresh() {
        balance = chipStore.chipBalance
        hasUsedSecondChance = chipStore.hasReceivedSecondChanceBonus
    }

    private var titleSection: some View {
        VStack(spacing: 2) {
            Text("6th Seat")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Hold'em")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("6th Seat Hold'em")
        .accessibilityIdentifier("MainMenu.Title")
    }

    private var balanceSection: some View {
        VStack(spacing: 4) {
            Text("BALANCE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            Text(MainMenuLogic.formatBalance(balance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .accessibilityIdentifier("MainMenu.Balance")
        }
    }

    private var canPlay: Bool {
        MainMenuLogic.playEnabled(balance: balance, hasUsedSecondChance: hasUsedSecondChance)
    }

    private var playButton: some View {
        Button(action: handlePlayTap) {
            Text("PLAY")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .tracking(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(canPlay ? .black : .white.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canPlay ? Color.yellow : Color.black.opacity(0.4))
                )
        }
        .disabled(!canPlay)
        .accessibilityIdentifier("MainMenu.Play")
    }

    private func handlePlayTap() {
        let shouldNavigate = MainMenuLogic.handlePlayTap(store: chipStore)
        refresh()
        if shouldNavigate {
            // Session 15b: PLAY routes to the table picker instead of
            // straight to the game. The picker reads the last-played id
            // and the affordability map, then pushes `.game(tableID:)`.
            path.append(.tableSelect)
        }
    }

    private var secondaryButtons: some View {
        VStack(spacing: 10) {
            secondaryButton(
                title: "Chip Shop",
                destination: .chipShop,
                highlighted: MainMenuLogic.showsBustedHint(balance: balance, hasUsedSecondChance: hasUsedSecondChance),
                identifier: "MainMenu.ChipShop"
            )
            secondaryButton(title: "Settings", destination: .settings, identifier: "MainMenu.Settings")
            secondaryButton(title: "How to Play", destination: .howToPlay, identifier: "MainMenu.HowToPlay")
        }
    }

    private func secondaryButton(
        title: String,
        destination: MenuDestination,
        highlighted: Bool = false,
        identifier: String
    ) -> some View {
        Button {
            path.append(destination)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(highlighted ? Color.yellow.opacity(0.22) : Color.black.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlighted ? Color.yellow : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    NavigationStack {
        MainMenuView(
            chipStore: InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true),
            path: .constant([])
        )
    }
}
