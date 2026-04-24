import SwiftUI

/// Placeholder chip visual: a colored disc tagged with the amount.
/// The color roughly follows standard casino denomination conventions
/// (red $5, green $25, black $100, purple $500, yellow $1000).
struct ChipStackView: View {
    let amount: Int
    var diameter: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(chipColor(for: amount))
            Circle()
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                .padding(3)
            Text("\(amount)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    private func chipColor(for amount: Int) -> Color {
        switch amount {
        case ..<5:     return Color(red: 0.85, green: 0.85, blue: 0.85) // white $1
        case 5..<25:   return Color(red: 0.80, green: 0.10, blue: 0.10) // red $5
        case 25..<100: return Color(red: 0.10, green: 0.55, blue: 0.25) // green $25
        case 100..<500: return Color(red: 0.10, green: 0.10, blue: 0.10) // black $100
        case 500..<1000: return Color(red: 0.45, green: 0.15, blue: 0.55) // purple $500
        default:       return Color(red: 0.95, green: 0.75, blue: 0.20) // yellow $1000+
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        ChipStackView(amount: 1)
        ChipStackView(amount: 5)
        ChipStackView(amount: 25)
        ChipStackView(amount: 100)
        ChipStackView(amount: 500)
        ChipStackView(amount: 1000)
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
