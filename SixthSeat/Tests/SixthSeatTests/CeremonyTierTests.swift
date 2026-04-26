import Testing
@testable import SixthSeat

@Suite("CeremonyTier classification")
struct CeremonyTierTests {

    @Test("High card maps to .standard")
    func highCardIsStandard() {
        #expect(HandRank.highCard.ceremonyTier == .standard)
    }

    @Test("Pair maps to .standard")
    func pairIsStandard() {
        #expect(HandRank.pair.ceremonyTier == .standard)
    }

    @Test("Two pair maps to .standard")
    func twoPairIsStandard() {
        #expect(HandRank.twoPair.ceremonyTier == .standard)
    }

    @Test("Three of a kind maps to .notable")
    func threeOfAKindIsNotable() {
        #expect(HandRank.threeOfAKind.ceremonyTier == .notable)
    }

    @Test("Straight maps to .notable")
    func straightIsNotable() {
        #expect(HandRank.straight.ceremonyTier == .notable)
    }

    @Test("Flush maps to .big")
    func flushIsBig() {
        #expect(HandRank.flush.ceremonyTier == .big)
    }

    @Test("Full house maps to .big")
    func fullHouseIsBig() {
        #expect(HandRank.fullHouse.ceremonyTier == .big)
    }

    @Test("Four of a kind maps to .big")
    func fourOfAKindIsBig() {
        #expect(HandRank.fourOfAKind.ceremonyTier == .big)
    }

    @Test("Straight flush maps to .jackpot")
    func straightFlushIsJackpot() {
        #expect(HandRank.straightFlush.ceremonyTier == .jackpot)
    }

    @Test("Royal flush maps to .jackpot")
    func royalFlushIsJackpot() {
        #expect(HandRank.royalFlush.ceremonyTier == .jackpot)
    }

    @Test("Tier ordering: standard < notable < big < jackpot")
    func tierOrdering() {
        #expect(CeremonyTier.standard < CeremonyTier.notable)
        #expect(CeremonyTier.notable < CeremonyTier.big)
        #expect(CeremonyTier.big < CeremonyTier.jackpot)
    }

    @Test("Every HandRank maps to a defined tier")
    func everyRankCovered() {
        // Iterates the full enum and asserts each case has a tier — guards
        // against new HandRank cases being added without a tier mapping.
        for rank in HandRank.allCases {
            let tier = rank.ceremonyTier
            #expect((1...4).contains(tier.rawValue))
        }
    }
}
