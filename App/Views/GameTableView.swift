import SwiftUI
import SixthSeat

/// Portrait heads-up UTH game table. First-pass layout using placeholder
/// graphics — real art drops in later without layout changes.
struct GameTableView: View {
    @Bindable var viewModel: GameTableViewModel

    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()

            VStack(spacing: 14) {
                statusBar
                dealerZone
                communityZone
                betZones
                playerZone
                Spacer(minLength: 0)
                errorBanner
                actionBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BALANCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                Text(viewModel.formattedBalance)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(viewModel.phaseLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.35)))
        }
    }

    // MARK: - Dealer zone

    private var dealerZone: some View {
        VStack(spacing: 6) {
            Text("DEALER")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))

            HStack(spacing: 8) {
                cardSlot(at: 0, cards: viewModel.dealerHoleCards, faceDown: viewModel.dealerCardsFaceDown)
                cardSlot(at: 1, cards: viewModel.dealerHoleCards, faceDown: viewModel.dealerCardsFaceDown)
            }

            if let result = viewModel.lastHandResult, viewModel.phase == .handComplete {
                Text("Dealer: \(rankName(result.dealerHand.rank))\(result.dealerQualifies ? "" : " (no qualify)")")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Community zone

    private var communityZone: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                communitySlot(index: 0, label: "FLOP")
                communitySlot(index: 1, label: "FLOP")
                communitySlot(index: 2, label: "FLOP")
                communitySlot(index: 3, label: "TURN")
                communitySlot(index: 4, label: "RIVER")
            }
        }
    }

    @ViewBuilder
    private func communitySlot(index: Int, label: String) -> some View {
        VStack(spacing: 3) {
            CardView(
                card: index < viewModel.communityCards.count ? viewModel.communityCards[index] : nil,
                width: 52, height: 72
            )
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Bet zones

    private var betZones: some View {
        HStack(spacing: 12) {
            BetZoneView(
                label: "TRIPS",
                amount: viewModel.displayedTripsBet,
                isActive: viewModel.isTripsZoneInteractive,
                onTap: viewModel.isTripsZoneInteractive ? { viewModel.cycleTripsBet() } : nil
            )
            BetZoneView(label: "ANTE",  amount: viewModel.anteBet > 0 ? viewModel.anteBet : viewModel.stagedAnte,
                        isActive: viewModel.phase == .awaitingBets)
            BetZoneView(label: "BLIND", amount: viewModel.blindBet > 0 ? viewModel.blindBet : viewModel.stagedAnte)
            BetZoneView(label: "PLAY",  amount: viewModel.playBet)
        }
    }

    // MARK: - Player zone

    private var playerZone: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                cardSlot(at: 0, cards: viewModel.playerHoleCards, faceDown: false)
                cardSlot(at: 1, cards: viewModel.playerHoleCards, faceDown: false)
            }
            Text("YOU")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))

            if let result = viewModel.lastHandResult, viewModel.phase == .handComplete {
                Text("Your hand: \(rankName(result.playerHand.rank))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    // MARK: - Error banner

    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.errorMessage {
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.85)))
        }
    }

    // MARK: - Action bar

    @ViewBuilder
    private var actionBar: some View {
        switch viewModel.phase {
        case .awaitingBets:   stakeSelectorBar
        case .preFlopDecision: preFlopBar
        case .postFlopDecision: postFlopBar
        case .postRiverDecision: postRiverBar
        case .resolving:      EmptyView()
        case .handComplete:   resultBar
        }
    }

    private var stakeSelectorBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                tapButton(symbol: "minus.circle.fill", enabled: viewModel.stagedAnte > (viewModel.anteSteps.first ?? 5)) {
                    viewModel.decrementStagedAnte()
                }
                VStack(spacing: 2) {
                    Text("ANTE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("$\(viewModel.stagedAnte)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                .frame(minWidth: 90)
                tapButton(symbol: "plus.circle.fill", enabled: viewModel.stagedAnte < (viewModel.anteSteps.last ?? 1000)) {
                    viewModel.incrementStagedAnte()
                }
            }

            primaryButton(
                "DEAL",
                enabled: viewModel.chipBalance >= viewModel.stagedAnte * 2
            ) {
                viewModel.deal()
            }
        }
    }

    private var preFlopBar: some View {
        HStack(spacing: 10) {
            secondaryButton("CHECK") { viewModel.checkPreFlop() }
            primaryButton("BET 3×", enabled: viewModel.chipBalance >= viewModel.anteBet * 3) {
                viewModel.betPreFlop(multiplier: 3)
            }
            primaryButton("BET 4×", enabled: viewModel.chipBalance >= viewModel.anteBet * 4) {
                viewModel.betPreFlop(multiplier: 4)
            }
        }
    }

    private var postFlopBar: some View {
        HStack(spacing: 10) {
            secondaryButton("CHECK") { viewModel.checkPostFlop() }
            primaryButton("BET 2×", enabled: viewModel.chipBalance >= viewModel.anteBet * 2) {
                viewModel.betPostFlop()
            }
        }
    }

    private var postRiverBar: some View {
        HStack(spacing: 10) {
            secondaryButton("FOLD") { viewModel.fold() }
            primaryButton("BET 1×", enabled: viewModel.chipBalance >= viewModel.anteBet) {
                viewModel.betPostRiver()
            }
        }
    }

    private var resultBar: some View {
        VStack(spacing: 8) {
            if let result = viewModel.lastHandResult {
                let net = Int(result.totalNet.rounded())
                Text(net > 0 ? "+$\(net)" : (net < 0 ? "-$\(-net)" : "Push"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(net > 0 ? .green : (net < 0 ? .red : .yellow))
            }
            if viewModel.canRebet {
                primaryButton("REBET", enabled: true) { viewModel.rebet() }
            }
            mutedButton("NEW HAND") { viewModel.newHand() }
        }
    }

    // MARK: - Button primitives

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? .black : .black.opacity(0.4))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(enabled ? Color.yellow : Color.gray.opacity(0.4))
                )
        }
        .disabled(!enabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                )
        }
    }

    private func mutedButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private func tapButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(enabled ? .white : .white.opacity(0.3))
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func cardSlot(at index: Int, cards: [Card], faceDown: Bool) -> some View {
        CardView(
            card: index < cards.count ? cards[index] : nil,
            faceDown: index < cards.count && faceDown
        )
    }

    private func rankName(_ rank: HandRank) -> String {
        switch rank {
        case .highCard:      return "High Card"
        case .pair:          return "Pair"
        case .twoPair:       return "Two Pair"
        case .threeOfAKind:  return "Three of a Kind"
        case .straight:      return "Straight"
        case .flush:         return "Flush"
        case .fullHouse:     return "Full House"
        case .fourOfAKind:   return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush:    return "Royal Flush"
        }
    }
}

#Preview {
    GameTableView(viewModel: GameTableViewModel())
}
