import SwiftUI
import SixthSeat

/// Slot-based card renderer. Front and back images are loaded through
/// `AssetService` — production resolves them from `Assets.xcassets`
/// (`card_<suit>_<rank>.png` / `card_back.png`); tests inject an
/// in-memory service that records the request.
///
/// States:
/// - `card == nil`: empty slot (dashed outline).
/// - `card != nil, faceUp == false`: card back image.
/// - `card != nil, faceUp == true`: card face image.
///
/// When `faceUp` toggles from `false` to `true` under an animated
/// state change, the card performs a Y-axis 3D flip — the back and
/// face cross-fade at the 90° midpoint of the rotation.
struct CardView: View {
    let card: Card?
    var faceUp: Bool = true
    var width: CGFloat = 60
    var height: CGFloat = 84

    @Environment(\.assets) private var assets

    var body: some View {
        Group {
            if let card {
                ZStack {
                    // Card back: rotated 0° when face-down, 180° when face-up
                    // (so the back rotates "out of view" as the front rotates in).
                    backBody
                        .rotation3DEffect(
                            .degrees(faceUp ? 180 : 0),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                        .opacity(faceUp ? 0 : 1)

                    faceBody(card: card)
                        .rotation3DEffect(
                            .degrees(faceUp ? 0 : -180),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                        .opacity(faceUp ? 1 : 0)
                }
            } else {
                emptySlot
            }
        }
        .frame(width: width, height: height)
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
                Color.white.opacity(0.4),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.15))
            )
    }

    private var backBody: some View {
        assets.cardBack()
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
    }

    private func faceBody(card: Card) -> some View {
        assets.cardImage(for: card)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    HStack(spacing: 10) {
        CardView(card: nil)
        CardView(card: Card(rank: .ace, suit: .spades), faceUp: false)
        CardView(card: Card(rank: .king, suit: .hearts))
        CardView(card: Card(rank: .ten, suit: .diamonds))
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
