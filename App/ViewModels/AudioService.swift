import Foundation
import SwiftUI
import AVFoundation
import SixthSeat

/// External boundary for SFX playback. Production conforms via
/// `AVAudioService` (loads CAF files from the bundle, plays through
/// cached `AVAudioPlayer` instances); tests conform via
/// `InMemoryAudioService` (records every request, no playback).
///
/// SFX gating is read at the call site (UserDefaults
/// `PersistenceKeys.settingsSFXEnabled`, default-on) so flipping the
/// toggle in Settings takes effect on the next play call — mirrors
/// the `GatedHapticsService` pattern from Session 15a. Calling
/// `setSFXEnabled(_:)` writes through to the same key so the
/// production service and the SwiftUI `@AppStorage` binding observe
/// one source of truth.
///
/// Music infrastructure is deliberately absent for V1: no music
/// asset was sourced, so there's nothing to play and nothing to
/// gate. Music returns as a V2 candidate.
protocol AudioService: AnyObject, Sendable {
    func play(_ sfx: SoundEffect)
    func setSFXEnabled(_ enabled: Bool)
}

/// Every SFX slot in V1. Raw values match the CAF filenames in
/// `App/Resources/Audio/` (without extension). `chipPlace` keeps the
/// designer's `chip-_place` filename verbatim — the underscore-after-
/// dash is intentional; we don't rename designer-delivered files.
enum SoundEffect: String, CaseIterable, Sendable {
    case cardDeal = "card_deal"
    case cardPlace = "card_place"
    case cardFlip = "card_flip"
    case chipPlace = "chip-_place"
    case chipStackHandle = "chips-handle-6"
    case chipPayoff = "chip_payoff"
    case fold
    case winSmall = "win_small"
    case winBig = "win_big"
    case loss

    /// Bundled audio file extension. CAF is what the designer shipped;
    /// switching format requires bundling a new file at the matching name.
    static let fileExtension = "caf"

    /// Folder under which CAF files live inside the bundle. Folder
    /// references preserve directory structure, so a `subdirectory:`
    /// argument to `Bundle.url(forResource:...)` is required.
    static let bundleSubdirectory = "Audio"
}

// MARK: - Production

/// Production audio service. Caches one `AVAudioPlayer` per
/// `SoundEffect` so repeat plays don't pay the disk-load cost.
/// Configures the shared `AVAudioSession` (iOS only) for `.ambient`
/// + `.mixWithOthers` so the game's SFX coexist with the player's
/// background music without taking an exclusive lock — the standard
/// casino/casual-game pattern.
///
/// `@unchecked Sendable` is acceptable here because the player cache
/// is guarded by an internal lock and `AVAudioPlayer` itself routes
/// its work through the audio render thread.
final class AVAudioService: AudioService, @unchecked Sendable {

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cache: [SoundEffect: AVAudioPlayer] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configureAudioSession()
    }

    /// `.ambient` respects the silent switch; `.mixWithOthers` lets
    /// the player's background audio (Spotify, podcasts) keep playing
    /// alongside our SFX. macOS has no `AVAudioSession` API — the call
    /// is a no-op there.
    private func configureAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal: SFX will silently fail to play if the session
            // can't activate. Surfaced via OSLog for diagnostics rather
            // than crashing the app on launch.
            NSLog("AVAudioService: audio session config failed: %@", "\(error)")
        }
        #endif
    }

    /// True when the user has not explicitly disabled SFX. Defaults
    /// to on — `UserDefaults.bool(forKey:)` returns false for an unset
    /// key, but the user-facing default for SFX is "enabled".
    private var enabled: Bool {
        defaults.object(forKey: PersistenceKeys.settingsSFXEnabled) as? Bool ?? true
    }

    func play(_ sfx: SoundEffect) {
        guard enabled else { return }
        guard let player = player(for: sfx) else { return }
        // Restart-from-zero on repeat so rapid-fire deals chain
        // crisply rather than stacking partially-played instances.
        player.currentTime = 0
        player.play()
    }

    func setSFXEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: PersistenceKeys.settingsSFXEnabled)
    }

    private func player(for sfx: SoundEffect) -> AVAudioPlayer? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[sfx] { return cached }
        // Prefer the bundled `Audio/` subdirectory (folder-reference
        // layout) and fall back to the bundle root in case future
        // bundling flattens the structure.
        let url = Bundle.main.url(
            forResource: sfx.rawValue,
            withExtension: SoundEffect.fileExtension,
            subdirectory: SoundEffect.bundleSubdirectory
        ) ?? Bundle.main.url(
            forResource: sfx.rawValue,
            withExtension: SoundEffect.fileExtension
        )
        guard let url else {
            NSLog("AVAudioService: missing asset for SFX %@", sfx.rawValue)
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            cache[sfx] = player
            return player
        } catch {
            NSLog("AVAudioService: failed to load %@: %@", sfx.rawValue, "\(error)")
            return nil
        }
    }
}

// MARK: - Test double

/// Records every SFX request without performing playback. Tests
/// assert against `playLog` to verify the right SFX fired for a
/// given game event. `@unchecked Sendable` mirrors
/// `RecordingHapticsService` — tests are serial and the mutable
/// state is only touched from the test thread.
final class InMemoryAudioService: AudioService, @unchecked Sendable {

    private(set) var playLog: [SoundEffect] = []
    private(set) var enabledLog: [Bool] = []
    private(set) var sfxEnabled: Bool = true

    init() {}

    func reset() {
        playLog.removeAll()
        enabledLog.removeAll()
        sfxEnabled = true
    }

    func play(_ sfx: SoundEffect) {
        guard sfxEnabled else { return }
        playLog.append(sfx)
    }

    func setSFXEnabled(_ enabled: Bool) {
        sfxEnabled = enabled
        enabledLog.append(enabled)
    }
}

// MARK: - Environment plumbing

private struct AudioServiceKey: EnvironmentKey {
    static let defaultValue: AudioService = AVAudioService()
}

extension EnvironmentValues {
    /// SwiftUI environment slot for the audio service. Production
    /// reads the bundled CAF files by default; tests inject an
    /// `InMemoryAudioService` via `.environment(\.audio, ...)`.
    var audio: AudioService {
        get { self[AudioServiceKey.self] }
        set { self[AudioServiceKey.self] = newValue }
    }
}
