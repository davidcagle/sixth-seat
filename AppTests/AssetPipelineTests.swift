import SwiftUI
import Testing
import UIKit
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
@Suite("ChipView + ChipStackView rendering (Session 25 offset-stacked single-chip art)")
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

    @Test("ChipStackView renders single-chip art N times for a single-denomination chunk")
    func singleDenominationChunkRendersNChips() {
        let assets = InMemoryAssetService()
        // $75 → three $25 chips
        let chunks = ChipDecomposition.decompose(amount: 75)
        renderToImage(
            ChipStackView(chunks: chunks)
                .environment(\.assets, assets)
        )
        expectChipRequestPattern(assets, [25, 25, 25])
        #expect(assets.stackRequests.isEmpty,
                "Session 25: bet-zone chip stacks render single-chip art, not pre-rendered stack imagesets")
    }

    @Test("ChipStackView renders multi-denomination chunks largest-first (bottom of stack)")
    func multiDenominationChunksRenderLargestFirst() {
        let assets = InMemoryAssetService()
        // $125 → ($100, 1) + ($25, 1). Largest denomination first means
        // the $100 chip is requested before the $25 — bottom-of-stack
        // rendering order, with the $25 chip stacked on top.
        let chunks = ChipDecomposition.decompose(amount: 125)
        renderToImage(
            ChipStackView(chunks: chunks)
                .environment(\.assets, assets)
        )
        expectChipRequestPattern(assets, [100, 25])
        #expect(assets.stackRequests.isEmpty)
    }

    @Test("ChipStackView with empty chunks requests no chip art")
    func emptyChunksRequestNothing() {
        let assets = InMemoryAssetService()
        renderToImage(
            ChipStackView(chunks: [])
                .environment(\.assets, assets)
        )
        #expect(assets.chipRequests.isEmpty)
        #expect(assets.stackRequests.isEmpty)
    }
}

@MainActor
@Suite("BetZoneView chip-stack rendering (Session 25 offset-stacked single-chip art)")
struct BetZoneViewChipStackTests {

    @Test("Zero bet renders no chip art — the empty-circle path stays")
    func zeroBetRendersNothing() {
        let assets = InMemoryAssetService()
        renderToImage(
            BetZoneView(label: "TRIPS", amount: 0)
                .environment(\.assets, assets)
        )
        #expect(assets.chipRequests.isEmpty)
        #expect(assets.stackRequests.isEmpty,
                "Session 25: bet-zone no longer routes through stack imagesets")
    }

    @Test("Single-denomination bet renders N copies of the single-chip art")
    func singleDenominationBetRendersOffsetStack() {
        let assets = InMemoryAssetService()
        // $10 → ($5, 2). Two $5 chip-art requests, no stack-art requests.
        renderToImage(
            BetZoneView(label: "ANTE", amount: 10)
                .environment(\.assets, assets)
        )
        expectChipRequestPattern(assets, [5, 5])
        #expect(assets.stackRequests.isEmpty)
    }

    @Test("Single-chip bet at a higher denomination renders that one chip")
    func singleHigherDenominationChipRequest() {
        let assets = InMemoryAssetService()
        // $100 → one $100 chip.
        renderToImage(
            BetZoneView(label: "PLAY", amount: 100)
                .environment(\.assets, assets)
        )
        expectChipRequestPattern(assets, [100])
        #expect(assets.stackRequests.isEmpty)
    }

    @Test("Multi-denomination bet renders chunks largest-first (bottom of the stack)")
    func multiDenominationBetRendersLargestFirst() {
        let assets = InMemoryAssetService()
        // $125 → ($100, 1) + ($25, 1). $100 chip art is requested before
        // $25 — bottom-of-stack rendering order.
        renderToImage(
            BetZoneView(label: "PLAY", amount: 125)
                .environment(\.assets, assets)
        )
        expectChipRequestPattern(assets, [100, 25])
    }

    @Test("Mixed bet with all five denominations renders chunks in descending order")
    func mixedBetWithAllDenominations() {
        let assets = InMemoryAssetService()
        // $1235 → ($1000, 1) + ($100, 2) + ($25, 1) + ($5, 2).
        // Worst-case-shape V1 amount: pins the chunk-order invariant
        // end-to-end through the view.
        renderToImage(
            BetZoneView(label: "PLAY", amount: 1235)
                .environment(\.assets, assets)
        )
        expectChipRequestPattern(assets, [1000, 100, 100, 25, 5, 5])
    }
}

@MainActor
@Suite("Chip art delivery dimensions (Session 22)")
struct ChipArtDimensionsTests {

    // Session 22: Fiverr delivered stack_5_h1.png and chip_5.png at
    // 3661×1909 with the chip stamped in a corner; the other denoms came
    // tight-cropped at ~800×740. After a 40×40 fit, the broken art
    // rendered as an ~8px speck. We recrop in place; this guard catches
    // any future redelivery from drifting back into oversized-canvas
    // territory.
    private static let chipDenominations = [5, 25, 100, 500, 1000]
    private static let aspectTolerance: ClosedRange<CGFloat> = 0.7...1.3

    @Test("Every chip_<denom> asset has near-square aspect (guards against canvas-padding redeliveries)")
    func chipArtAspectStaysSquareish() {
        for denom in Self.chipDenominations {
            let name = "chip_\(denom)"
            guard let img = UIImage(named: name) else {
                Issue.record("Missing chip asset: \(name)")
                continue
            }
            let aspect = img.size.width / img.size.height
            #expect(
                Self.aspectTolerance.contains(aspect),
                "\(name) aspect \(aspect) outside \(Self.aspectTolerance) — likely oversized canvas with corner-stamped art"
            )
        }
    }

    @Test("Every stack_<denom>_h1 asset has near-square aspect")
    func h1StackArtAspectStaysSquareish() {
        for denom in Self.chipDenominations {
            let name = "stack_\(denom)_h1"
            guard let img = UIImage(named: name) else {
                Issue.record("Missing stack asset: \(name)")
                continue
            }
            let aspect = img.size.width / img.size.height
            #expect(
                Self.aspectTolerance.contains(aspect),
                "\(name) aspect \(aspect) outside \(Self.aspectTolerance) — likely oversized canvas with corner-stamped art"
            )
        }
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

/// Asserts the chip-request log matches `expected`, tolerant of SwiftUI's
/// multi-pass ForEach evaluation under `ImageRenderer`. Session 25's
/// `ChipStackView` uses a `ForEach` to lay out N single-chip Images, and
/// the renderer evaluates the body more than once during the measure/draw
/// passes — so the recorded request log is the expected sequence repeated
/// an integer number of times. Asserting on the first cycle plus the
/// length-is-a-multiple invariant pins the rendering contract without
/// coupling to SwiftUI's internal pass count.
@MainActor
private func expectChipRequestPattern(
    _ assets: InMemoryAssetService,
    _ expected: [Int],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let log = assets.chipRequests
    if expected.isEmpty {
        #expect(log.isEmpty, sourceLocation: sourceLocation)
        return
    }
    #expect(
        !log.isEmpty && log.count % expected.count == 0,
        "request log length \(log.count) not a positive multiple of pattern length \(expected.count)",
        sourceLocation: sourceLocation
    )
    let firstCycle = Array(log.prefix(expected.count))
    #expect(
        firstCycle == expected,
        "first \(expected.count) requests \(firstCycle) ≠ expected \(expected); full log: \(log)",
        sourceLocation: sourceLocation
    )
}
