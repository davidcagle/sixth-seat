import Foundation
import OSLog

/// Telemetry call sites. Session 16 shipped the IAP-flow methods with
/// only no-op + console-logging implementations; Session 19b adds the
/// production `TelemetryDeckTelemetryService` and the `handResolved`
/// call so per-hand outcomes can be analyzed in aggregate. The IAP
/// method signatures are unchanged from Session 16 so the production
/// swap is drop-in for those call sites — chip amounts are derived
/// from `ChipBundleCatalog` inside the TelemetryDeck impl rather than
/// threaded through every site.
public protocol TelemetryService: Sendable {
    func purchaseInitiated(productID: String)
    func purchaseSucceeded(productID: String, isFirstPurchase: Bool)
    func purchaseFailed(productID: String, reason: String)
    func restoreInitiated()
    func restoreCompleted(count: Int)

    /// Hand-resolution event. Fires once per hand at the moment the
    /// engine reaches `.handComplete` (after dealer reveal, before the
    /// player taps NEW HAND / REBET). Carries the table stake, the bet
    /// shape (ante + trips), and the net outcome bucketed into
    /// `win`/`loss`/`push` so we can read the rate at which players are
    /// reaching each result tone without logging raw balance amounts.
    /// (Session 19b)
    func handResolved(
        tableID: String,
        anteAmount: Int,
        tripsAmount: Int,
        resultTone: HandResultTone,
        tripsOutcome: TripsTelemetryOutcome
    )
}

/// Net-outcome bucket reported on the `handResolved` event. Mirrors the
/// player-facing headline tone (`HandResultHeadline.Tone`) but lives in
/// the engine because that's where the telemetry protocol lives.
public enum HandResultTone: String, Sendable, Equatable {
    case win
    case loss
    case push
}

/// Trips side-bet outcome reported on `handResolved`. Distinct from the
/// engine's `BetOutcome` because we want a simple paid/lost/notPlaced
/// split for telemetry rather than the raw multiplier ladder.
public enum TripsTelemetryOutcome: String, Sendable, Equatable {
    case paid
    case lost
    case notPlaced
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

    public func handResolved(
        tableID: String,
        anteAmount: Int,
        tripsAmount: Int,
        resultTone: HandResultTone,
        tripsOutcome: TripsTelemetryOutcome
    ) {
        logger.notice("hand_resolved table=\(tableID, privacy: .public) ante=\(anteAmount, privacy: .public) trips=\(tripsAmount, privacy: .public) tone=\(resultTone.rawValue, privacy: .public) trips_outcome=\(tripsOutcome.rawValue, privacy: .public)")
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
        case handResolved(
            tableID: String,
            anteAmount: Int,
            tripsAmount: Int,
            resultTone: HandResultTone,
            tripsOutcome: TripsTelemetryOutcome
        )
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

    public func handResolved(
        tableID: String,
        anteAmount: Int,
        tripsAmount: Int,
        resultTone: HandResultTone,
        tripsOutcome: TripsTelemetryOutcome
    ) {
        append(.handResolved(
            tableID: tableID,
            anteAmount: anteAmount,
            tripsAmount: tripsAmount,
            resultTone: resultTone,
            tripsOutcome: tripsOutcome
        ))
    }
}
