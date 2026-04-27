import UIKit

/// Production haptics. Wraps `UIImpactFeedbackGenerator` and
/// `UINotificationFeedbackGenerator`. Haptics only fire on physical
/// devices — simulator runs are silent.
///
/// Both methods are nonisolated and dispatch to the MainActor internally
/// because `UIFeedbackGenerator` requires MainActor for `impactOccurred()`
/// / `notificationOccurred(_:)`. Construction is nonisolated so the default
/// `init()` is callable from any context (e.g. the view model's init).
public final class SystemHapticsService: HapticsService {
    public init() {}

    public func impact(_ style: ImpactStyle) {
        let mapped: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:  mapped = .light
        case .medium: mapped = .medium
        case .heavy:  mapped = .heavy
        case .soft:   mapped = .soft
        case .rigid:  mapped = .rigid
        }
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: mapped)
            generator.impactOccurred()
        }
    }

    public func notification(_ type: NotificationType) {
        let mapped: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success: mapped = .success
        case .warning: mapped = .warning
        case .error:   mapped = .error
        }
        Task { @MainActor in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(mapped)
        }
    }
}
