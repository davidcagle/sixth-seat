import Foundation

/// Single source of truth for the five V1 chip bundles. Both the
/// production `StoreKitIAPService` and the in-memory test double read
/// the catalog from here, and the Chip Shop UI iterates `all` to render
/// tiles — no inline literals in the view layer.
///
/// The `localizedPrice` strings here are placeholders used until
/// `IAPService.loadProducts()` returns with the real `Product.displayPrice`
/// values. They mirror the reference USD prices the catalog was designed
/// around so the shop renders sensibly in offline / preview / test
/// contexts where StoreKit is unreachable.
///
/// Product IDs MUST match App Store Connect exactly. See the Open Items
/// section of `HANDOFF.md` for the manual App Store Connect setup that
/// makes these resolvable in sandbox/TestFlight.
public enum ChipBundleCatalog {

    public static let pocketChange = ChipBundle(
        id: "com.sixthseat.uth.chips.pocketchange",
        displayName: "Pocket Change",
        chipAmount: 5_000,
        localizedPrice: "$0.99"
    )

    public static let starter = ChipBundle(
        id: "com.sixthseat.uth.chips.starter",
        displayName: "Starter Stack",
        chipAmount: 25_000,
        localizedPrice: "$1.99"
    )

    public static let tableStakes = ChipBundle(
        id: "com.sixthseat.uth.chips.tablestakes",
        displayName: "Table Stakes",
        chipAmount: 75_000,
        localizedPrice: "$4.99",
        badge: .mostPopular
    )

    public static let highRoller = ChipBundle(
        id: "com.sixthseat.uth.chips.highroller",
        displayName: "High Roller",
        chipAmount: 250_000,
        localizedPrice: "$9.99"
    )

    public static let deepStack = ChipBundle(
        id: "com.sixthseat.uth.chips.deepstack",
        displayName: "Deep Stack",
        chipAmount: 750_000,
        localizedPrice: "$19.99",
        badge: .bestValue
    )

    /// Display order for the shop, smallest to largest.
    public static let all: [ChipBundle] = [
        pocketChange, starter, tableStakes, highRoller, deepStack
    ]

    public static let allProductIDs: Set<String> = Set(all.map(\.id))

    public static func bundle(forID id: String) -> ChipBundle? {
        all.first { $0.id == id }
    }
}
