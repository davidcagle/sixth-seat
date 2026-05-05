import SwiftUI
import SixthSeat

/// Renders a stack of chips for a given denomination + chip count by
/// picking the right Phase-1 stack variant via `StackHeight.bestFit(for:)`.
/// Production reads `stack_<denomination>_h<height>.png` from the
/// asset catalog; tests inject an `InMemoryAssetService` to assert
/// the right variant was requested.
struct ChipStackView: View {
    let denomination: Int
    let count: Int
    var diameter: CGFloat = 40

    @Environment(\.assets) private var assets

    var body: some View {
        let height = StackHeight.bestFit(for: count)
        return assets.chipStackImage(denomination: denomination, height: height)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: diameter, height: diameter)
    }
}

#Preview {
    HStack(spacing: 10) {
        ChipStackView(denomination: 5, count: 1)
        ChipStackView(denomination: 25, count: 7)
        ChipStackView(denomination: 100, count: 15)
        ChipStackView(denomination: 500, count: 50)
        ChipStackView(denomination: 1000, count: 100)
    }
    .padding()
    .background(Color(red: 0.1, green: 0.4, blue: 0.2))
}
