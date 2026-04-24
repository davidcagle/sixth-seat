import SwiftUI
import SixthSeat

/// Placeholder card renderer used until Fiverr art is delivered.
///
/// States:
/// - `card == nil`: empty slot (dashed outline)
/// - `card != nil`, `faceDown == true`: dark back with "?" symbol
/// - `card != nil`, `faceDown == false`: white face with rank + suit
struct CardView: View {
    let card: Card?
    var faceDown: Bool = false
    var width: CGFloat = 60
    var height: CGFloat = 84

    var body: some View {
        Group {
            if let card {
                if faceDown {
                    faceDownBody
                } else {
                    faceUpBody(card: card)
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

    private var faceDownBody: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(red: 0.15, green: 0.25, blue: 0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "questionmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            )
    }

    @ViewBuilder
    private func faceUpBody(card: Card) -> some View {
        let color = suitColor(card.suit)
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                VStack {
                    HStack {
                        Text(card.rank.display)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(color)
                        Spacer()
                    }
                    Spacer()
                    Image(systemName: suitSymbolName(card.suit))
                        .font(.system(size: 22))
                        .foregroundStyle(color)
                    Spacer()
                    HStack {
                        Spacer()
                        Text(card.rank.display)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(color)
                            .rotationEffect(.degrees(180))
                    }
                }
                .padding(5)
            )
    }

    private func suitColor(_ suit: Suit) -> Color {
        switch suit {
        case .hearts, .diamonds: return .red
        case .clubs, .spades:    return .black
        }
    }

    private func suitSymbolName(_ suit: Suit) -> String {
        switch suit {
        case .clubs:    return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        case .hearts:   return "suit.heart.fill"
        case .spades:   return "suit.spade.fill"
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        CardView(card: nil)
        CardView(card: Card(rank: .ace, suit: .spades), faceDown: true)
        CardView(card: Card(rank: .king, suit: .hearts))
        CardView(card: Card(rank: .ten, suit: .diamonds))
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
