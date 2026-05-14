import SwiftUI
import SixthSeat

/// Renders a bet-zone chip stack as N copies of the single-chip art
/// (`chip_<denomination>.png`) offset-stacked, instead of a pre-rendered
/// stack imageset. The bottom chip in the stack sits at the bottom of
/// the bet circle (`alignment: .bottom`); subsequent chips are shifted
/// upward by `offset` so the rim of each chip remains visible on top of
/// the one below — matching the casino convention of mixed chips
/// physically stacked on the felt.
///
/// `chunks` is the output of `ChipDecomposition.decompose(amount:)`,
/// ordered largest denomination first. Rendering walks the chunks in
/// that order, so the largest chip sits on the bottom and smaller
/// denominations stack on top.
///
/// Session 25 supersedes the Session 17/22 stack-art renderer
/// (`stack_<denom>_h<height>.png`). Those stack imagesets are now
/// unreferenced and marked for housekeeping cleanup.
struct ChipStackView: View {
    let chunks: [ChipChunk]
    /// Diameter of a single chip. Session 25 default of 40 pt matches
    /// the standalone `ChipView` default; the bet zone passes its own
    /// value sized to the bet circle.
    var chipDiameter: CGFloat = 40
    /// Vertical shift applied per chip above the bottom one — i.e. how
    /// much of each chip's rim shows above the chip below. Session 25
    /// default is ~20% of `chipDiameter`, which keeps the worst-case V1
    /// bet (5 chips: $750 or $1235) within a reasonable visual envelope.
    var perChipOffset: CGFloat = 8

    @Environment(\.assets) private var assets

    /// Flattened chip sequence, bottom of the stack first. Walking
    /// `chunks` in their natural largest-first order means the bottom
    /// chip is the largest denomination, matching real-felt convention.
    private var stackedDenominations: [Int] {
        chunks.flatMap { chunk in
            Array(repeating: chunk.denomination, count: chunk.count)
        }
    }

    var body: some View {
        let denominations = stackedDenominations
        return ZStack(alignment: .bottom) {
            ForEach(Array(denominations.enumerated()), id: \.offset) { index, denom in
                assets.chipImage(for: denom)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: chipDiameter, height: chipDiameter)
                    .offset(y: -CGFloat(index) * perChipOffset)
            }
        }
        .frame(width: chipDiameter, height: chipDiameter)
    }
}

#Preview {
    HStack(spacing: 16) {
        ChipStackView(chunks: ChipDecomposition.decompose(amount: 5))
        ChipStackView(chunks: ChipDecomposition.decompose(amount: 30))
        ChipStackView(chunks: ChipDecomposition.decompose(amount: 125))
        ChipStackView(chunks: ChipDecomposition.decompose(amount: 750))
        ChipStackView(chunks: ChipDecomposition.decompose(amount: 1235))
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
