import SwiftUI
import SixthSeat

/// V1 Settings screen. Three sections:
///
/// 1. Audio & Haptics — toggles for SFX and haptics. SFX gates the
///    `AVAudioService` at the call site via
///    `PersistenceKeys.settingsSFXEnabled` (Session 19a); haptics
///    gates via `GatedHapticsService` (Session 15a). The Music
///    toggle was removed in Session 19a — no music asset was
///    sourced for V1, so a third audio toggle would be
///    non-functional.
/// 2. Legal & Disclosures — Apple 4.3 informational copy plus links to
///    the hosted privacy policy and terms of service.
/// 3. About — app version and build number from the bundle.
///
/// Reachable from the Main Menu only — no mid-game gear icon in V1.
struct SettingsView: View {

    @AppStorage(PersistenceKeys.settingsSFXEnabled) private var sfxEnabled: Bool = true
    @AppStorage(PersistenceKeys.settingsHapticsEnabled) private var hapticsEnabled: Bool = true

    var body: some View {
        Form {
            Section("Audio & Haptics") {
                Toggle("Sound Effects", isOn: $sfxEnabled)
                    .accessibilityIdentifier("Settings.SFXToggle")
                Toggle("Haptics", isOn: $hapticsEnabled)
                    .accessibilityIdentifier("Settings.HapticsToggle")
            }

            Section("Legal & Disclosures") {
                Text(DisclosureCopy.body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("Settings.DisclosureBody")

                Link("Privacy Policy", destination: SettingsLinks.privacyPolicyURL)
                    .accessibilityIdentifier("Settings.PrivacyPolicy")

                Link("Terms of Service", destination: SettingsLinks.termsOfServiceURL)
                    .accessibilityIdentifier("Settings.TermsOfService")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(SettingsLinks.versionString)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("Settings.VersionLabel")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Constants surfaced to the Settings screen and to tests. Hosted-doc URLs
/// are stable GitHub Pages URLs that are referenced in App Store Connect.
enum SettingsLinks {
    static let privacyPolicyURL = URL(string: "https://davidcagle.github.io/sixth-seat/privacy.html")!
    static let termsOfServiceURL = URL(string: "https://davidcagle.github.io/sixth-seat/terms.html")!

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (Build \(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
