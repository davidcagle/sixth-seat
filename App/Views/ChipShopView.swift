import SwiftUI
import SixthSeat

/// Real Chip Shop. Five tiers with StoreKit-localized prices, a
/// per-install first-purchase doubler banner, restore button, and a
/// no-cash-value reinforcement line. The view is dumb: every behavior
/// (loading, errors, doubler math, balance refresh) lives in
/// `ChipShopViewModel`, and the doubler / strikethrough math comes
/// from engine helpers in `ChipShopLogic`.
struct ChipShopView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChipShopViewModel

    private let feltColor = Color(red: 0.1, green: 0.4, blue: 0.2)

    init(viewModel: ChipShopViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            feltColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    headerSection
                    if viewModel.doublerActive {
                        doublerBanner
                    }
                    bundlesSection
                    restoreSection
                    noCashValueLine
                    backButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Chip Shop")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadProductsIfNeeded() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("BALANCE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            Text(ChipShopLogic.formatChipAmount(viewModel.balance))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .accessibilityIdentifier("ChipShop.Balance")
        }
        .padding(.top, 4)
    }

    private var doublerBanner: some View {
        Text(ChipShopLogic.bannerText)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .tracking(1)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow)
            )
            .accessibilityIdentifier("ChipShop.DoublerBanner")
    }

    private var bundlesSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.bundles) { bundle in
                bundleCard(bundle)
            }
        }
    }

    private var restoreSection: some View {
        VStack(spacing: 6) {
            Button {
                Task { await viewModel.restore() }
            } label: {
                Group {
                    if viewModel.isRestoring {
                        ProgressView().tint(.white)
                    } else {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(viewModel.isRestoring)
            .accessibilityIdentifier("ChipShop.Restore")

            if let message = viewModel.restoreMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .accessibilityIdentifier("ChipShop.RestoreMessage")
            }
        }
        .padding(.top, 4)
    }

    private var noCashValueLine: some View {
        Text("Chips have no cash value and cannot be redeemed for money or prizes.")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("ChipShop.NoCashValue")
    }

    private var backButton: some View {
        Button(action: { dismiss() }) {
            Text("Back to Menu")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityIdentifier("ChipShop.BackToMenu")
    }

    // MARK: - Tier card

    private func bundleCard(_ bundle: ChipBundle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(bundle.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if let badge = bundle.badge {
                    Text(badge.label)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.yellow))
                        .accessibilityIdentifier("ChipShop.Badge.\(bundle.id)")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(ChipShopLogic.formatChipAmount(viewModel.displayAmount(for: bundle))) chips")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("ChipShop.Amount.\(bundle.id)")
                if let strikethrough = viewModel.strikethroughAmount(for: bundle) {
                    Text(ChipShopLogic.formatChipAmount(strikethrough))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .strikethrough(true, color: .white.opacity(0.7))
                        .accessibilityIdentifier("ChipShop.Strikethrough.\(bundle.id)")
                }
            }

            Button {
                Task { await viewModel.purchase(bundle) }
            } label: {
                Group {
                    if viewModel.isLoading(bundle) {
                        ProgressView().tint(.black)
                    } else {
                        Text(bundle.localizedPrice)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.black)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow)
                )
            }
            .disabled(viewModel.loadingBundleID != nil)
            .accessibilityIdentifier("ChipShop.Buy.\(bundle.id)")

            if let error = viewModel.errorMessage(for: bundle) {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red.opacity(0.95))
                    .accessibilityIdentifier("ChipShop.Error.\(bundle.id)")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        ChipShopView(viewModel: ChipShopViewModel(
            iapService: InMemoryIAPService(chipStore: InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true)),
            chipStore: InMemoryChipStore(chipBalance: 5_000, hasReceivedStarterBonus: true),
            haptics: NoopHapticsService()
        ))
    }
}
