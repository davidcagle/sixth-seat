import SwiftUI

/// Placeholder betting zone. Shows a label and the current wager amount
/// (or "—" if empty). Tappable — forwards the intent back via `onTap`.
struct BetZoneView: View {
    let label: String
    let amount: Int
    var isActive: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let content = VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(1)
            Text(amount > 0 ? "$\(amount)" : "—")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(amount > 0 ? Color.yellow : .white.opacity(0.6))
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(8)
        .background(
            Circle()
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            Circle()
                .strokeBorder(
                    isActive ? Color.yellow : Color.white.opacity(0.5),
                    lineWidth: isActive ? 2 : 1
                )
        )

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        BetZoneView(label: "TRIPS", amount: 0)
        BetZoneView(label: "ANTE",  amount: 10, isActive: true)
        BetZoneView(label: "BLIND", amount: 10)
        BetZoneView(label: "PLAY",  amount: 40)
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
