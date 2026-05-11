import Foundation
import Testing
@testable import SixthSeat
@testable import SixthSeatApp

@Suite("AudioService (Session 19a)")
struct AudioServiceTests {

    private static func freshDefaults(
        suite: String = "com.sixthseat.test.audio.\(UUID().uuidString)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - SoundEffect catalog

    @Test("All 10 V1 SFX slots are present and their raw values match the bundled CAF filenames")
    func soundEffectRawValuesMatchBundle() {
        // Lock the asset names. A typo here would make the SFX silently
        // fail to load — production logs but does not crash. Tests are
        // the only place this contract is enforced.
        #expect(SoundEffect.cardDeal.rawValue == "card_deal")
        #expect(SoundEffect.cardPlace.rawValue == "card_place")
        #expect(SoundEffect.cardFlip.rawValue == "card_flip")
        #expect(SoundEffect.chipPlace.rawValue == "chip-_place")
        #expect(SoundEffect.chipStackHandle.rawValue == "chips-handle-6")
        #expect(SoundEffect.chipPayoff.rawValue == "chip_payoff")
        #expect(SoundEffect.fold.rawValue == "fold")
        #expect(SoundEffect.winSmall.rawValue == "win_small")
        #expect(SoundEffect.winBig.rawValue == "win_big")
        #expect(SoundEffect.loss.rawValue == "loss")
        #expect(SoundEffect.allCases.count == 10)
        #expect(SoundEffect.fileExtension == "caf")
        #expect(SoundEffect.bundleSubdirectory == "Audio")
    }

    // MARK: - InMemoryAudioService

    @Test("InMemoryAudioService records each play() in order; setSFXEnabled(false) drops subsequent plays")
    func inMemoryAudioRecordsAndGates() {
        let audio = InMemoryAudioService()
        audio.play(.cardDeal)
        audio.play(.cardDeal)
        audio.play(.cardFlip)

        audio.setSFXEnabled(false)
        audio.play(.winBig) // dropped

        audio.setSFXEnabled(true)
        audio.play(.loss)

        #expect(audio.playLog == [.cardDeal, .cardDeal, .cardFlip, .loss])
        #expect(audio.enabledLog == [false, true])
        #expect(audio.sfxEnabled == true)
    }

    // MARK: - AVAudioService gating against UserDefaults

    @Test("AVAudioService.setSFXEnabled round-trips through PersistenceKeys.settingsSFXEnabled")
    func avAudioServicePersistsToggle() {
        // The Settings toggle reads/writes the same UserDefaults key
        // via @AppStorage. The service must use the same key so a
        // toggle flip in Settings takes effect on the next play
        // without re-instantiating the service.
        let defaults = Self.freshDefaults()
        let audio = AVAudioService(defaults: defaults)

        audio.setSFXEnabled(false)
        #expect(defaults.bool(forKey: PersistenceKeys.settingsSFXEnabled) == false)

        audio.setSFXEnabled(true)
        #expect(defaults.bool(forKey: PersistenceKeys.settingsSFXEnabled) == true)
    }
}
