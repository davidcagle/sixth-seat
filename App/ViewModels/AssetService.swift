import SwiftUI
import SixthSeat

/// External boundary for the visual-asset bundle. Production conforms
/// via `BundleAssetService` (loads from `Assets.xcassets` by named
/// imageset); tests conform via `InMemoryAssetService` (records every
/// request and returns deterministic SF Symbol placeholders so view
/// assertions can verify the right slot was asked for without bundle
/// dependencies).
///
/// Slot-based by design: when the Phase 1 designer ships
/// `card_hearts_ace.png` etc., the only integration work is dropping
/// the file into the matching imageset — no code changes needed.
protocol AssetService: AnyObject, Sendable {
    func cardImage(for card: Card) -> Image
    func cardBack() -> Image
    func chipImage(for denomination: Int) -> Image
    func chipStackImage(denomination: Int, height: StackHeight) -> Image
}

// MARK: - Asset name helpers

/// Pure, testable name derivation. Lives outside the protocol so both
/// implementations resolve names through the same code path and the
/// engine's `Card` model stays asset-naming-free.
enum AssetNames {

    static func card(_ card: Card) -> String {
        "card_\(suitToken(card.suit))_\(rankToken(card.rank))"
    }

    static let cardBack = "card_back"

    static func chip(_ denomination: Int) -> String {
        "chip_\(denomination)"
    }

    static func stack(denomination: Int, height: StackHeight) -> String {
        "stack_\(denomination)_h\(height.rawValue)"
    }

    static func suitToken(_ suit: Suit) -> String {
        suit.rawValue // Suit raw values are already lowercase tokens.
    }

    /// Asset-friendly rank token: "2"…"10", "jack", "queen", "king", "ace".
    /// Distinct from `Rank.display`, which uses "J/Q/K/A".
    static func rankToken(_ rank: Rank) -> String {
        switch rank {
        case .two:   return "2"
        case .three: return "3"
        case .four:  return "4"
        case .five:  return "5"
        case .six:   return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine:  return "9"
        case .ten:   return "10"
        case .jack:  return "jack"
        case .queen: return "queen"
        case .king:  return "king"
        case .ace:   return "ace"
        }
    }
}

// MARK: - Production

/// Loads each asset from `Assets.xcassets` by named imageset. A
/// missing asset surfaces as SwiftUI's broken-image marker — the
/// asset-pipeline scaffolding (Session 17) creates a placeholder
/// imageset for every slot so this only fires if a designer drop is
/// incomplete.
final class BundleAssetService: AssetService {

    init() {}

    func cardImage(for card: Card) -> Image {
        Image(AssetNames.card(card))
    }

    func cardBack() -> Image {
        Image(AssetNames.cardBack)
    }

    func chipImage(for denomination: Int) -> Image {
        Image(AssetNames.chip(denomination))
    }

    func chipStackImage(denomination: Int, height: StackHeight) -> Image {
        Image(AssetNames.stack(denomination: denomination, height: height))
    }
}

// MARK: - Test double

/// Records every asset request so view tests can assert the right
/// slot was asked for. The returned `Image` is a deterministic SF
/// Symbol per family — view tests do not compare Images directly;
/// they assert against the recorded request log.
///
/// `@unchecked Sendable` mirrors `RecordingHapticsService` — tests are
/// serial and the mutable state is only touched from the test thread.
final class InMemoryAssetService: AssetService, @unchecked Sendable {

    private(set) var cardRequests: [Card] = []
    private(set) var cardBackRequestCount: Int = 0
    private(set) var chipRequests: [Int] = []
    private(set) var stackRequests: [StackRequest] = []

    /// Last-resolved asset name per family. Tests assert on this to
    /// verify the production name-mapping path is being walked.
    private(set) var lastCardName: String?
    private(set) var lastChipName: String?
    private(set) var lastStackName: String?

    struct StackRequest: Equatable {
        let denomination: Int
        let height: StackHeight
    }

    init() {}

    func reset() {
        cardRequests.removeAll()
        cardBackRequestCount = 0
        chipRequests.removeAll()
        stackRequests.removeAll()
        lastCardName = nil
        lastChipName = nil
        lastStackName = nil
    }

    func cardImage(for card: Card) -> Image {
        cardRequests.append(card)
        lastCardName = AssetNames.card(card)
        return Image(systemName: "rectangle.portrait")
    }

    func cardBack() -> Image {
        cardBackRequestCount += 1
        return Image(systemName: "rectangle.portrait.fill")
    }

    func chipImage(for denomination: Int) -> Image {
        chipRequests.append(denomination)
        lastChipName = AssetNames.chip(denomination)
        return Image(systemName: "circle.fill")
    }

    func chipStackImage(denomination: Int, height: StackHeight) -> Image {
        stackRequests.append(StackRequest(denomination: denomination, height: height))
        lastStackName = AssetNames.stack(denomination: denomination, height: height)
        return Image(systemName: "square.stack.fill")
    }
}

// MARK: - Environment plumbing

private struct AssetServiceKey: EnvironmentKey {
    static let defaultValue: AssetService = BundleAssetService()
}

extension EnvironmentValues {
    /// SwiftUI environment slot for the asset service. Production
    /// reads the bundle catalog by default; tests inject an
    /// `InMemoryAssetService` via `.environment(\.assets, ...)`.
    var assets: AssetService {
        get { self[AssetServiceKey.self] }
        set { self[AssetServiceKey.self] = newValue }
    }
}
