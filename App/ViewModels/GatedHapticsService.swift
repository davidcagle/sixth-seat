import Foundation
import SixthSeat

/// Production wrapper that gates an underlying `HapticsService` on the
/// user's "Haptics" toggle in Settings. The toggle is stored at
/// `PersistenceKeys.settingsHapticsEnabled`; when missing or true the
/// underlying service receives the call, when false the call is a no-op.
///
/// The flag is read at the call site (not cached at init) so flipping
/// the toggle in Settings takes effect on the next haptic without
/// re-instantiating the view model.
public final class GatedHapticsService: HapticsService, @unchecked Sendable {

    private let underlying: HapticsService
    private let defaults: UserDefaults

    public init(underlying: HapticsService, defaults: UserDefaults = .standard) {
        self.underlying = underlying
        self.defaults = defaults
    }

    /// Defaults to true on absence — UserDefaults returns false for an
    /// unset bool, but the user-facing default for haptics is "on".
    private var enabled: Bool {
        defaults.object(forKey: PersistenceKeys.settingsHapticsEnabled) as? Bool ?? true
    }

    public func impact(_ style: ImpactStyle) {
        guard enabled else { return }
        underlying.impact(style)
    }

    public func notification(_ type: NotificationType) {
        guard enabled else { return }
        underlying.notification(type)
    }
}
