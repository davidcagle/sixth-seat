import SwiftUI
import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("AssetNames (Session 17 asset pipeline)")
struct AssetNamesTests {

    // MARK: - Card names

    @Test("Card name follows card_<suit>_<rank> with lowercase suit token")
    func cardNameShape() {
        #expect(AssetNames.card(Card(rank: .ace,   suit: .hearts))   == "card_hearts_ace")
        #expect(AssetNames.card(Card(rank: .king,  suit: .spades))   == "card_spades_king")
        #expect(AssetNames.card(Card(rank: .queen, suit: .diamonds)) == "card_diamonds_queen")
        #expect(AssetNames.card(Card(rank: .jack,  suit: .clubs))    == "card_clubs_jack")
    }

    @Test("Numeric rank tokens use digits, not Rank.display letters")
    func numericRankTokens() {
        #expect(AssetNames.card(Card(rank: .two,   suit: .hearts)) == "card_hearts_2")
        #expect(AssetNames.card(Card(rank: .ten,   suit: .hearts)) == "card_hearts_10")
        #expect(AssetNames.card(Card(rank: .seven, suit: .clubs))  == "card_clubs_7")
    }

    @Test("Card back name is a constant slot")
    func cardBackName() {
        #expect(AssetNames.cardBack == "card_back")
    }

    // MARK: - Chip + stack names

    @Test("Chip name is chip_<denomination>")
    func chipName() {
        #expect(AssetNames.chip(5)    == "chip_5")
        #expect(AssetNames.chip(25)   == "chip_25")
        #expect(AssetNames.chip(100)  == "chip_100")
        #expect(AssetNames.chip(500)  == "chip_500")
        #expect(AssetNames.chip(1000) == "chip_1000")
    }

    @Test("Stack name is stack_<denomination>_h<height>")
    func stackName() {
        #expect(AssetNames.stack(denomination: 5,    height: .h1)  == "stack_5_h1")
        #expect(AssetNames.stack(denomination: 25,   height: .h5)  == "stack_25_h5")
        #expect(AssetNames.stack(denomination: 100,  height: .h10) == "stack_100_h10")
        #expect(AssetNames.stack(denomination: 1000, height: .h20) == "stack_1000_h20")
    }
}

@MainActor
@Suite("InMemoryAssetService (Session 17)")
struct InMemoryAssetServiceTests {

    @Test("Card requests are recorded in order")
    func recordsCardRequests() {
        let assets = InMemoryAssetService()
        _ = assets.cardImage(for: Card(rank: .ace, suit: .hearts))
        _ = assets.cardImage(for: Card(rank: .king, suit: .clubs))

        #expect(assets.cardRequests == [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .clubs)
        ])
        #expect(assets.lastCardName == "card_clubs_king")
    }

    @Test("Card back requests increment the count")
    func recordsCardBackRequests() {
        let assets = InMemoryAssetService()
        _ = assets.cardBack()
        _ = assets.cardBack()
        _ = assets.cardBack()
        #expect(assets.cardBackRequestCount == 3)
    }

    @Test("Chip requests record both denomination and resolved name")
    func recordsChipRequests() {
        let assets = InMemoryAssetService()
        _ = assets.chipImage(for: 25)
        _ = assets.chipImage(for: 500)
        #expect(assets.chipRequests == [25, 500])
        #expect(assets.lastChipName == "chip_500")
    }

    @Test("Stack requests record denomination + height + resolved name")
    func recordsStackRequests() {
        let assets = InMemoryAssetService()
        _ = assets.chipStackImage(denomination: 100, height: .h10)
        _ = assets.chipStackImage(denomination: 5, height: .h1)

        #expect(assets.stackRequests == [
            .init(denomination: 100, height: .h10),
            .init(denomination: 5,   height: .h1)
        ])
        #expect(assets.lastStackName == "stack_5_h1")
    }

    @Test("reset() clears every recorded request")
    func resetClearsState() {
        let assets = InMemoryAssetService()
        _ = assets.cardImage(for: Card(rank: .ace, suit: .hearts))
        _ = assets.cardBack()
        _ = assets.chipImage(for: 25)
        _ = assets.chipStackImage(denomination: 100, height: .h5)

        assets.reset()

        #expect(assets.cardRequests.isEmpty)
        #expect(assets.cardBackRequestCount == 0)
        #expect(assets.chipRequests.isEmpty)
        #expect(assets.stackRequests.isEmpty)
        #expect(assets.lastCardName == nil)
        #expect(assets.lastChipName == nil)
        #expect(assets.lastStackName == nil)
    }

    @Test("Distinct cards produce distinct resolved names")
    func distinctCardNames() {
        let assets = InMemoryAssetService()
        var seen: Set<String> = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                _ = assets.cardImage(for: Card(rank: rank, suit: suit))
                if let name = assets.lastCardName {
                    seen.insert(name)
                }
            }
        }
        // 4 suits * 13 ranks = 52 distinct card slot names.
        #expect(seen.count == 52)
    }
}

@MainActor
@Suite("CardView rendering (Session 17)")
struct CardViewRenderingTests {

    @Test("Face-up CardView requests both face and back so the flip can animate")
    func faceUpRequestsBothImages() {
        let assets = InMemoryAssetService()
        let card = Card(rank: .ace, suit: .hearts)
        renderToImage(
            CardView(card: card, faceUp: true)
                .environment(\.assets, assets)
        )
        #expect(assets.cardRequests.contains(card))
        #expect(assets.cardBackRequestCount >= 1)
    }

    @Test("Face-down CardView still requests both face and back so the flip can animate")
    func faceDownRequestsBothImages() {
        let assets = InMemoryAssetService()
        let card = Card(rank: .king, suit: .clubs)
        renderToImage(
            CardView(card: card, faceUp: false)
                .environment(\.assets, assets)
        )
        #expect(assets.cardRequests.contains(card))
        #expect(assets.cardBackRequestCount >= 1)
    }

    @Test("Empty-slot CardView (nil card) requests no card or back asset")
    func emptySlotRequestsNothing() {
        let assets = InMemoryAssetService()
        renderToImage(
            CardView(card: nil)
                .environment(\.assets, assets)
        )
        #expect(assets.cardRequests.isEmpty)
        #expect(assets.cardBackRequestCount == 0)
    }
}

@MainActor
@Suite("ChipView + ChipStackView rendering (Session 17)")
struct ChipViewRenderingTests {

    @Test("ChipView requests the asset for its denomination")
    func chipViewRequestsDenomination() {
        let assets = InMemoryAssetService()
        renderToImage(
            ChipView(denomination: 100)
                .environment(\.assets, assets)
        )
        #expect(assets.chipRequests == [100])
        #expect(assets.lastChipName == "chip_100")
    }

    @Test("ChipStackView routes count through StackHeight.bestFit")
    func stackViewPicksBestFit() {
        let assets = InMemoryAssetService()
        renderToImage(
            ChipStackView(denomination: 25, count: 7)
                .environment(\.assets, assets)
        )
        // 7 chips → h5 variant (rounded down)
        #expect(assets.stackRequests == [.init(denomination: 25, height: .h5)])
        #expect(assets.lastStackName == "stack_25_h5")
    }

    @Test("ChipStackView clamps a count above 20 to the h20 variant")
    func stackViewClampsAtMax() {
        let assets = InMemoryAssetService()
        renderToImage(
            ChipStackView(denomination: 1000, count: 200)
                .environment(\.assets, assets)
        )
        #expect(assets.stackRequests == [.init(denomination: 1000, height: .h20)])
    }
}

// MARK: - Test helpers

@MainActor
private func renderToImage<V: View>(_ view: V) {
    // ImageRenderer is the cleanest way to force SwiftUI to evaluate
    // a view's body in a unit test — `cgImage` walks the layout pass
    // and triggers our environment-backed AssetService calls.
    let renderer = ImageRenderer(content: view)
    _ = renderer.cgImage
}
