import Foundation
import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("DisclosureModalView (Apple 4.3 first-launch disclosure)")
struct DisclosureModalViewTests {

    /// Builds an isolated `UserDefaults` so tests can drive the persisted
    /// `hasSeenDisclosure` flag without leaking into other tests or the
    /// real user's defaults database.
    private static func freshDefaults(
        suite: String = "com.sixthseat.test.disclosure.\(UUID().uuidString)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Persisted flag drives modal presentation

    @Test("Modal would present on first launch (flag absent → defaults to false)")
    func modalPresentsWhenFlagIsAbsent() {
        let defaults = Self.freshDefaults()

        // The unset key reads as false from UserDefaults; the disclosure
        // modal presentation is gated on the flag being false. ContentView
        // initializes `showDisclosure = !defaults.bool(forKey: ...)`, so
        // an absent flag means the modal would present.
        let shouldShow = !defaults.bool(forKey: PersistenceKeys.hasSeenDisclosure)
        #expect(shouldShow == true)
    }

    @Test("Modal would not present once the flag has been set to true")
    func modalDoesNotPresentWhenFlagIsTrue() {
        let defaults = Self.freshDefaults()
        defaults.set(true, forKey: PersistenceKeys.hasSeenDisclosure)

        let shouldShow = !defaults.bool(forKey: PersistenceKeys.hasSeenDisclosure)
        #expect(shouldShow == false)
    }

    // MARK: - Acknowledgment writes the flag

    @Test("Setting hasSeenDisclosure persists across UserDefaults instances on the same suite")
    func flagPersistsAcrossInstances() {
        let suite = "com.sixthseat.test.disclosure.persist.\(UUID().uuidString)"
        let firstDefaults = UserDefaults(suiteName: suite)!
        firstDefaults.removePersistentDomain(forName: suite)

        firstDefaults.set(true, forKey: PersistenceKeys.hasSeenDisclosure)

        // A new UserDefaults instance bound to the same suite must observe
        // the persisted flag — this is the contract that the first-launch
        // modal does not re-fire after the user has acknowledged it.
        let secondDefaults = UserDefaults(suiteName: suite)!
        #expect(secondDefaults.bool(forKey: PersistenceKeys.hasSeenDisclosure) == true)
    }

    @Test("PersistenceKeys.hasSeenDisclosure is the namespaced key string")
    func keyIsNamespaced() {
        // The key is a stable string that ships in every UserDefaults
        // write — locking it pins the contract. Changing this string
        // would silently re-fire the disclosure modal for every existing
        // user on the next app version.
        #expect(PersistenceKeys.hasSeenDisclosure == "com.sixthseat.uth.hasSeenDisclosure")
    }

    // MARK: - View instantiation

    @Test("DisclosureModalView instantiates with a binding")
    func viewInstantiates() {
        var presented = true
        let binding = Binding<Bool>(get: { presented }, set: { presented = $0 })
        _ = DisclosureModalView(isPresented: binding)
    }

    // MARK: - Copy is centralized

    @Test("Disclosure copy contains the entertainment-only message and the no-cash-value message")
    func copyContainsKeyDisclosures() {
        // Apple 4.3 reviewers want unambiguous language in the disclosure.
        // Lock the substring contract here so a future copy edit can't
        // silently drop one of the two required statements.
        #expect(DisclosureCopy.title.contains("entertainment only"))
        #expect(DisclosureCopy.body.contains("does not offer real-money gambling"))
        #expect(DisclosureCopy.body.contains("no cash value"))
        #expect(DisclosureCopy.body.contains("does not imply future success"))
    }
}
