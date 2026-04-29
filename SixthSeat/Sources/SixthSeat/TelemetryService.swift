import Foundation
import OSLog

/// Telemetry call sites for the IAP flow. Session 16 ships only the
/// no-op + console-logging implementations; Session 17 wires this up
/// to TelemetryDeck (or whichever provider David picks). Defining the
/// protocol now keeps the IAP service from painting itself into a
/// corner — Session 17 can swap the production impl without touching
/// the call sites.
public protocol TelemetryService: Sendable {
    func purchaseInitiated(productID: String)
    func purchaseSucceeded(productID: String, isFirstPurchase: Bool)
    func purchaseFailed(productID: String, reason: String)
    func restoreInitiated()
    func restoreCompleted(count: Int)
}

/// Production stand-in until Session 17. Writes to the unified log so
/// the events show up in Console.app during sandbox testing without
/// requiring a network round-trip.
public struct LoggingTelemetryService: TelemetryService {

    private let logger: Logger

    public init(subsystem: String = "com.sixthseat.uth", category: String = "iap") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func purchaseInitiated(productID: String) {
        logger.notice("purchase_initiated product=\(productID, privacy: .public)")
    }

    public func purchaseSucceeded(productID: String, isFirstPurchase: Bool) {
        logger.notice("purchase_succeeded product=\(productID, privacy: .public) firstPurchase=\(isFirstPurchase, privacy: .public)")
    }

    public func purchaseFailed(productID: String, reason: String) {
        logger.error("purchase_failed product=\(productID, privacy: .public) reason=\(reason, privacy: .public)")
    }

    public func restoreInitiated() {
        logger.notice("restore_initiated")
    }

    public func restoreCompleted(count: Int) {
        logger.notice("restore_completed count=\(count, privacy: .public)")
    }
}

/// In-memory test double — captures every call so tests can assert the
/// IAP service is hitting the expected telemetry hooks at the right
/// moments. Thread-safe via a serial queue because the StoreKit
/// listener fires from a background task.
public final class RecordingTelemetryService: TelemetryService, @unchecked Sendable {

    public enum Event: Equatable, Sendable {
        case purchaseInitiated(productID: String)
        case purchaseSucceeded(productID: String, isFirstPurchase: Bool)
        case purchaseFailed(productID: String, reason: String)
        case restoreInitiated
        case restoreCompleted(count: Int)
    }

    private let lock = NSLock()
    private var _events: [Event] = []

    public init() {}

    public var events: [Event] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _events.removeAll()
    }

    private func append(_ event: Event) {
        lock.lock()
        _events.append(event)
        lock.unlock()
    }

    public func purchaseInitiated(productID: String) {
        append(.purchaseInitiated(productID: productID))
    }

    public func purchaseSucceeded(productID: String, isFirstPurchase: Bool) {
        append(.purchaseSucceeded(productID: productID, isFirstPurchase: isFirstPurchase))
    }

    public func purchaseFailed(productID: String, reason: String) {
        append(.purchaseFailed(productID: productID, reason: reason))
    }

    public func restoreInitiated() {
        append(.restoreInitiated)
    }

    public func restoreCompleted(count: Int) {
        append(.restoreCompleted(count: count))
    }
}
