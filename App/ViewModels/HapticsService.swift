import Foundation

/// Neutral abstraction over UIKit's haptic feedback generators. Production
/// uses `SystemHapticsService` (real haptics on a physical device); tests
/// use `NoopHapticsService` (silent) or `RecordingHapticsService` (captures
/// the call sequence for assertion).
///
/// The enums are deliberately UIKit-free so this protocol can be referenced
/// from the engine module and from test contexts without dragging UIKit in.
public protocol HapticsService: Sendable {
    func impact(_ style: ImpactStyle)
    func notification(_ type: NotificationType)
}

public enum ImpactStyle: Sendable {
    case light, medium, heavy, soft, rigid
}

public enum NotificationType: Sendable {
    case success, warning, error
}

public struct NoopHapticsService: HapticsService {
    public init() {}
    public func impact(_ style: ImpactStyle) {}
    public func notification(_ type: NotificationType) {}
}

/// Records every haptic call in order so tests can assert against the
/// expected trigger map (card flips fire `.light`, ceremony tier wins fire
/// `.success` + chained impacts, etc.).
public final class RecordingHapticsService: HapticsService, @unchecked Sendable {
    public enum Event: Equatable, Sendable {
        case impact(ImpactStyle)
        case notification(NotificationType)
    }

    public private(set) var events: [Event] = []

    public init() {}

    public func impact(_ style: ImpactStyle) {
        events.append(.impact(style))
    }

    public func notification(_ type: NotificationType) {
        events.append(.notification(type))
    }

    public func clear() {
        events.removeAll()
    }
}
