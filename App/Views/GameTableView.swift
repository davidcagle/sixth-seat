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

            ceremonyOverlay
        }
        // Tap anywhere on the felt while animating to snap to the settled
        // state. The gesture sits behind interactive controls — buttons
        // disabled during animation absorb taps over them, but the open
        // felt routes through to skipToSettled.
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                if viewModel.isAnimating {
                    withAnimation(.easeOut(duration: 0.15)) {
                        viewModel.skipToSettled()
                    }
                }
            }
        )
        .animation(.easeInOut(duration: 0.30), value: viewModel.revealedCards)
        .animation(.easeInOut(duration: 0.20), value: viewModel.anteAnimation)
        .animation(.easeInOut(duration: 0.20), value: viewModel.blindAnimation)
        .animation(.easeInOut(duration: 0.20), value: viewModel.playAnimation)
        .animation(.easeInOut(duration: 0.20), value: viewModel.tripsAnimation)
        .animation(.easeInOut(duration: 0.40), value: viewModel.displayedBalance)
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentCeremony)
        .animation(.easeInOut(duration: 0.25), value: viewModel.ceremonyAdvanceEnabled)
    }

    // MARK: - Ceremony overlay

    @ViewBuilder
    private var ceremonyOverlay: some View {
        if let ceremony = viewModel.currentCeremony {
            switch viewModel.animationStage {
            case .jackpotCeremony:
                JackpotCeremonyView(state: ceremony, advanceEnabled: viewModel.ceremonyAdvanceEnabled)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            case .ceremony:
                CeremonyView(state: ceremony, isBigTier: ceremony.effectiveTier == .big)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            default:
                EmptyView()
            }
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
                Text(formattedDisplayedBalance)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
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

    private var formattedDisplayedBalance: String {
        let n = viewModel.displayedBalance
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? "$\(n)"
    }

    // MARK: - Dealer zone

    private var dealerZone: some View {
        VStack(spacing: 6) {
            Text("DEALER")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))

            HStack(spacing: 8) {
                CardView(
                    card: viewModel.dealerHoleCards.indices.contains(0) ? viewModel.dealerHoleCards[0] : nil,
                    faceDown: viewModel.isDealerCardFaceDown(index: 0)
                )
                CardView(
                    card: viewModel.dealerHoleCards.indices.contains(1) ? viewModel.dealerHoleCards[1] : nil,
                    faceDown: viewModel.isDealerCardFaceDown(index: 1)
                )
            }

            if let result = viewModel.lastHandResult, viewModel.phase == .handComplete, !viewModel.isAnimating {
                Text("Dealer: \(rankName(result.dealerHand.rank))\(result.dealerQualifies ? "" : " (no qualify)")")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Community zone

    private var communityZone: some View {
        HStack(spacing: 6) {
            communitySlot(index: 0)
            communitySlot(index: 1)
            communitySlot(index: 2)
            communitySlot(index: 3)
            communitySlot(index: 4)
        }
    }

    @ViewBuilder
    private func communitySlot(index: Int) -> some View {
        CardView(
            card: index < viewModel.communityCards.count ? viewModel.communityCards[index] : nil,
            faceDown: viewModel.isCommunityCardFaceDown(index: index),
            width: 52, height: 72
        )
    }

    // MARK: - Bet zones

    private var betZones: some View {
        HStack(spacing: 12) {
            BetZoneView(
                label: "TRIPS",
                amount: viewModel.displayedTripsBet,
                isActive: viewModel.isTripsZoneInteractive && !viewModel.isAnimating,
                animation: viewModel.tripsAnimation,
                onTap: (viewModel.isTripsZoneInteractive && !viewModel.isAnimating) ? { viewModel.cycleTripsBet() } : nil
            )
            BetZoneView(
                label: "ANTE",
                amount: viewModel.anteBet > 0 ? viewModel.anteBet : viewModel.stagedAnte,
                isActive: viewModel.phase == .awaitingBets && !viewModel.isAnimating,
                animation: viewModel.anteAnimation
            )
            BetZoneView(
                label: "BLIND",
                amount: viewModel.blindBet > 0 ? viewModel.blindBet : viewModel.stagedAnte,
                animation: viewModel.blindAnimation
            )
            BetZoneView(
                label: "PLAY",
                amount: viewModel.playBet,
                animation: viewModel.playAnimation
            )
        }
    }

    // MARK: - Player zone

    private var playerZone: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                CardView(
                    card: viewModel.playerHoleCards.indices.contains(0) ? viewModel.playerHoleCards[0] : nil,
                    faceDown: viewModel.isPlayerCardFaceDown(index: 0)
                )
                .id("player-card-\(viewModel.currentDealId)-0")
                CardView(
                    card: viewModel.playerHoleCards.indices.contains(1) ? viewModel.playerHoleCards[1] : nil,
                    faceDown: viewModel.isPlayerCardFaceDown(index: 1)
                )
                .id("player-card-\(viewModel.currentDealId)-1")
            }
            Text("YOU")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))

            if let result = viewModel.lastHandResult, viewModel.phase == .handComplete, !viewModel.isAnimating {
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
                tapButton(symbol: "minus.circle.fill", enabled: !viewModel.isAnimating && viewModel.stagedAnte > (viewModel.anteSteps.first ?? 5)) {
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
                tapButton(symbol: "plus.circle.fill", enabled: !viewModel.isAnimating && viewModel.stagedAnte < (viewModel.anteSteps.last ?? 1000)) {
                    viewModel.incrementStagedAnte()
                }
            }

            primaryButton(
                "DEAL",
                enabled: !viewModel.isAnimating && viewModel.chipBalance >= viewModel.stagedAnte * 2
            ) {
                viewModel.deal()
            }
        }
    }

    private var preFlopBar: some View {
        HStack(spacing: 10) {
            secondaryButton("CHECK", enabled: !viewModel.isAnimating) { viewModel.checkPreFlop() }
            primaryButton("BET 3×", enabled: !viewModel.isAnimating && viewModel.chipBalance >= viewModel.anteBet * 3) {
                viewModel.betPreFlop(multiplier: 3)
            }
            primaryButton("BET 4×", enabled: !viewModel.isAnimating && viewModel.chipBalance >= viewModel.anteBet * 4) {
                viewModel.betPreFlop(multiplier: 4)
            }
        }
    }

    private var postFlopBar: some View {
        HStack(spacing: 10) {
            secondaryButton("CHECK", enabled: !viewModel.isAnimating) { viewModel.checkPostFlop() }
            primaryButton("BET 2×", enabled: !viewModel.isAnimating && viewModel.chipBalance >= viewModel.anteBet * 2) {
                viewModel.betPostFlop()
            }
        }
    }

    private var postRiverBar: some View {
        HStack(spacing: 10) {
            secondaryButton("FOLD", enabled: !viewModel.isAnimating) { viewModel.fold() }
            primaryButton("BET 1×", enabled: !viewModel.isAnimating && viewModel.chipBalance >= viewModel.anteBet) {
                viewModel.betPostRiver()
            }
        }
    }

    private var resultBar: some View {
        VStack(spacing: 8) {
            if let result = viewModel.lastHandResult, !viewModel.isAnimating {
                let net = Int(result.totalNet.rounded())
                Text(net > 0 ? "+$\(net)" : (net < 0 ? "-$\(-net)" : "Push"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(net > 0 ? .green : (net < 0 ? .red : .yellow))
            }
            if viewModel.canRebet {
                primaryButton("REBET", enabled: !viewModel.isAnimating) { viewModel.rebet() }
            }
            mutedButton("NEW HAND", enabled: !viewModel.isAnimating) { viewModel.newHand() }
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

    private func secondaryButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(enabled ? Color.white.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 1.5)
                )
        }
        .disabled(!enabled)
    }

    private func mutedButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(enabled ? .white.opacity(0.75) : .white.opacity(0.3))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(enabled ? 0.4 : 0.2), lineWidth: 1)
                )
        }
        .disabled(!enabled)
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
