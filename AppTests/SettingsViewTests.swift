import Foundation
import Testing
import SwiftUI
@testable import SixthSeat
@testable import SixthSeatApp

@MainActor
@Suite("SettingsView (Session 15a)")
struct SettingsViewTests {

    private static func freshDefaults(
        suite: String = "com.sixthseat.test.settings.\(UUID().uuidString)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - View instantiation

    @Test("SettingsView instantiates without crashing")
    func viewInstantiates() {
        _ = SettingsView()
    }

    // MARK: - Persistence keys are namespaced

    @Test("Settings persistence keys are namespaced under com.sixthseat.uth.settings")
    func settingsKeysAreNamespaced() {
        // Lock the wire format. Renaming a key would silently reset
        // every existing user's preference back to default.
        #expect(PersistenceKeys.settingsSFXEnabled == "com.sixthseat.uth.settings.sfxEnabled")
        #expect(PersistenceKeys.settingsAmbientEnabled == "com.sixthseat.uth.settings.ambientEnabled")
        #expect(PersistenceKeys.settingsHapticsEnabled == "com.sixthseat.uth.settings.hapticsEnabled")
    }

    // MARK: - Hosted legal URLs

    @Test("Privacy policy URL points to the hosted GitHub Pages document")
    func privacyPolicyURLIsHosted() {
        #expect(SettingsLinks.privacyPolicyURL.absoluteString
                == "https://davidcagle.github.io/sixth-seat/privacy.html")
    }

    @Test("Terms of service URL points to the hosted GitHub Pages document")
    func termsOfServiceURLIsHosted() {
        #expect(SettingsLinks.termsOfServiceURL.absoluteString
                == "https://davidcagle.github.io/sixth-seat/terms.html")
    }

    @Test("Version string formats as 'X.Y (Build Z)'")
    func versionStringFormat() {
        // Bundle metadata depends on the test harness's Info.plist; the
        // format is what we control. Assert the shape contains "Build".
        let s = SettingsLinks.versionString
        #expect(s.contains("Build"))
        #expect(s.contains("("))
        #expect(s.contains(")"))
    }

    // MARK: - Toggle persistence

    @Test("Setting a toggle flag and reading it back returns the same value")
    func togglesPersistViaUserDefaults() {
        let defaults = Self.freshDefaults()

        // Default unset reads as false (UserDefaults default), but the
        // user-facing default for these toggles is true. The view's
        // `@AppStorage(... default: true)` papers over the asymmetry; at
        // the persistence layer we simply round-trip the value.
        defaults.set(false, forKey: PersistenceKeys.settingsSFXEnabled)
        defaults.set(false, forKey: PersistenceKeys.settingsAmbientEnabled)
        defaults.set(false, forKey: PersistenceKeys.settingsHapticsEnabled)

        #expect(defaults.bool(forKey: PersistenceKeys.settingsSFXEnabled) == false)
        #expect(defaults.bool(forKey: PersistenceKeys.settingsAmbientEnabled) == false)
        #expect(defaults.bool(forKey: PersistenceKeys.settingsHapticsEnabled) == false)
    }

    @Test("Setting a toggle flag persists across UserDefaults instances on the same suite")
    func togglesPersistAcrossInstances() {
        let suite = "com.sixthseat.test.settings.persist.\(UUID().uuidString)"
        let firstDefaults = UserDefaults(suiteName: suite)!
        firstDefaults.removePersistentDomain(forName: suite)

        firstDefaults.set(false, forKey: PersistenceKeys.settingsHapticsEnabled)

        let secondDefaults = UserDefaults(suiteName: suite)!
        #expect(secondDefaults.bool(forKey: PersistenceKeys.settingsHapticsEnabled) == false)
    }

    // MARK: - GatedHapticsService gating

    @Test("Haptics calls reach the underlying service when no flag is set (default = on)")
    func hapticsForwardsByDefault() {
        let defaults = Self.freshDefaults()
        let recording = RecordingHapticsService()
        let gated = GatedHapticsService(underlying: recording, defaults: defaults)

        gated.impact(.medium)
        gated.notification(.success)

        #expect(recording.events == [
            .impact(.medium),
            .notification(.success)
        ])
    }

    @Test("Haptics calls reach the underlying service when the flag is true")
    func hapticsForwardsWhenEnabled() {
        let defaults = Self.freshDefaults()
        defaults.set(true, forKey: PersistenceKeys.settingsHapticsEnabled)
        let recording = RecordingHapticsService()
        let gated = GatedHapticsService(underlying: recording, defaults: defaults)

        gated.impact(.heavy)
        gated.notification(.warning)

        #expect(recording.events == [
            .impact(.heavy),
            .notification(.warning)
        ])
    }

    @Test("Haptics calls are dropped when the flag is false")
    func hapticsBlockedWhenDisabled() {
        let defaults = Self.freshDefaults()
        defaults.set(false, forKey: PersistenceKeys.settingsHapticsEnabled)
        let recording = RecordingHapticsService()
        let gated = GatedHapticsService(underlying: recording, defaults: defaults)

        gated.impact(.light)
        gated.impact(.medium)
        gated.impact(.heavy)
        gated.notification(.success)
        gated.notification(.error)

        #expect(recording.events.isEmpty)
    }

    @Test("Haptics gating reads the flag at the call site, so a mid-session flip takes effect immediately")
    func hapticsRespectsLiveFlagFlip() {
        // The GatedHapticsService must NOT cache the flag at init —
        // toggling Settings should affect the very next haptic call.
        let defaults = Self.freshDefaults()
        let recording = RecordingHapticsService()
        let gated = GatedHapticsService(underlying: recording, defaults: defaults)

        gated.impact(.medium) // default = true
        defaults.set(false, forKey: PersistenceKeys.settingsHapticsEnabled)
        gated.impact(.medium) // dropped
        defaults.set(true, forKey: PersistenceKeys.settingsHapticsEnabled)
        gated.impact(.heavy)  // through

        #expect(recording.events == [
            .impact(.medium),
            .impact(.heavy)
        ])
    }
}
