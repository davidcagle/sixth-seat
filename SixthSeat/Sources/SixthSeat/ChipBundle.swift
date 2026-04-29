import Foundation

/// One purchasable chip bundle. The `id` mirrors the App Store Connect
/// product identifier exactly — a typo here is a silent failure (the
/// product won't load and the tile will show the placeholder price).
///
/// `localizedPrice` is set by the IAP service after `Product.products(for:)`
/// returns. The catalog ships a placeholder price string so the UI has
/// something to render before StoreKit responds (or in offline tests).
public struct ChipBundle: Equatable, Hashable, Codable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let chipAmount: Int
    public var localizedPrice: String
    public let badge: BundleBadge?

    public init(
        id: String,
        displayName: String,
        chipAmount: Int,
        localizedPrice: String,
        badge: BundleBadge? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.chipAmount = chipAmount
        self.localizedPrice = localizedPrice
        self.badge = badge
    }
}

/// Tile accent for tiers we want to call out in the shop UI. The engine
/// stays SwiftUI-free, so the app layer maps these to colors/styles.
public enum BundleBadge: String, Codable, Sendable, Equatable, Hashable {
    case mostPopular
    case bestValue

    public var label: String {
        switch self {
        case .mostPopular: return "MOST POPULAR"
        case .bestValue:   return "BEST VALUE"
        }
    }
}
