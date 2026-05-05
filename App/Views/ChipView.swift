import SwiftUI
import SixthSeat

/// Renders a single chip of a given denomination. Production reads
/// `chip_<denomination>.png` from the asset catalog; tests inject an
/// `InMemoryAssetService` to assert the right denomination was
/// requested without needing the real PNG to be bundled.
struct ChipView: View {
    let denomination: Int
    var diameter: CGFloat = 40

    @Environment(\.assets) private var assets

    var body: some View {
        assets.chipImage(for: denomination)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: diameter, height: diameter)
    }
}

#Preview {
    HStack(spacing: 10) {
        ChipView(denomination: 5)
        ChipView(denomination: 25)
        ChipView(denomination: 100)
        ChipView(denomination: 500)
        ChipView(denomination: 1000)
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
