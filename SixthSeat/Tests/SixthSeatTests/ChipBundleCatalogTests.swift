import Foundation
import Testing
@testable import SixthSeat

@Suite("ChipBundleCatalog")
struct ChipBundleCatalogTests {

    @Test("Catalog contains exactly five bundles")
    func fiveBundles() {
        #expect(ChipBundleCatalog.all.count == 5)
    }

    @Test("Catalog tiers are listed smallest-to-largest by chip amount")
    func tiersInDisplayOrder() {
        let amounts = ChipBundleCatalog.all.map(\.chipAmount)
        #expect(amounts == [5_000, 25_000, 75_000, 250_000, 750_000])
    }

    @Test("Each tier has the contracted product ID, display name, chip amount, and badge")
    func tierShapes() {
        let pocket = ChipBundleCatalog.pocketChange
        #expect(pocket.id == "com.sixthseat.uth.chips.pocketchange")
        #expect(pocket.displayName == "Pocket Change")
        #expect(pocket.chipAmount == 5_000)
        #expect(pocket.badge == nil)

        let starter = ChipBundleCatalog.starter
        #expect(starter.id == "com.sixthseat.uth.chips.starter")
        #expect(starter.displayName == "Starter Stack")
        #expect(starter.chipAmount == 25_000)
        #expect(starter.badge == nil)

        let table = ChipBundleCatalog.tableStakes
        #expect(table.id == "com.sixthseat.uth.chips.tablestakes")
        #expect(table.displayName == "Table Stakes")
        #expect(table.chipAmount == 75_000)
        #expect(table.badge == .mostPopular)

        let high = ChipBundleCatalog.highRoller
        #expect(high.id == "com.sixthseat.uth.chips.highroller")
        #expect(high.displayName == "High Roller")
        #expect(high.chipAmount == 250_000)
        #expect(high.badge == nil)

        let deep = ChipBundleCatalog.deepStack
        #expect(deep.id == "com.sixthseat.uth.chips.deepstack")
        #expect(deep.displayName == "Deep Stack")
        #expect(deep.chipAmount == 750_000)
        #expect(deep.badge == .bestValue)
    }

    @Test("Exactly one tier carries each badge — Most Popular and Best Value are unique")
    func badgeUniqueness() {
        let mostPopularCount = ChipBundleCatalog.all.filter { $0.badge == .mostPopular }.count
        let bestValueCount   = ChipBundleCatalog.all.filter { $0.badge == .bestValue }.count
        #expect(mostPopularCount == 1)
        #expect(bestValueCount == 1)
    }

    @Test("allProductIDs covers every catalog tier")
    func allProductIDs() {
        #expect(ChipBundleCatalog.allProductIDs.count == 5)
        for bundle in ChipBundleCatalog.all {
            #expect(ChipBundleCatalog.allProductIDs.contains(bundle.id))
        }
    }

    @Test("bundle(forID:) returns the matching tier or nil")
    func bundleLookup() {
        #expect(ChipBundleCatalog.bundle(forID: "com.sixthseat.uth.chips.tablestakes") == ChipBundleCatalog.tableStakes)
        #expect(ChipBundleCatalog.bundle(forID: "nope") == nil)
    }

    @Test("Placeholder localized prices are non-empty so the UI never renders an empty button")
    func placeholderPrices() {
        for bundle in ChipBundleCatalog.all {
            #expect(!bundle.localizedPrice.isEmpty)
        }
    }

    @Test("BundleBadge.label exposes the human-readable accent string")
    func badgeLabels() {
        #expect(BundleBadge.mostPopular.label == "MOST POPULAR")
        #expect(BundleBadge.bestValue.label == "BEST VALUE")
    }
}
