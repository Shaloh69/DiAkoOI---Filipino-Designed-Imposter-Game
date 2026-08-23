import 'package:diakooi/audio/vibe_audio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support.dart';

/// The §4 audio behaviour table, enforced rather than listened to.
Future<void> main() async {
  final packs = await loadAllPacks();
  final pack = packs.first;

  group('dB to linear', () {
    test('-6dB is half amplitude, and 0dB is untouched', () {
      expect(linearFromDb(0), 1.0);
      expect(linearFromDb(6), closeTo(0.501, 0.002));
      expect(linearFromDb(12), closeTo(0.251, 0.002));
    });

    test('a negative attenuation never boosts above full', () {
      expect(linearFromDb(-6), 1.0);
    });
  });

  group('§4 transitions', () {
    test('VIBE_ROLL starts the session at full volume', () {
      const initial = VibeAudioState();
      final playing = initial.startSession(pack);

      expect(playing.pack, pack);
      expect(playing.attenuationDb, 0);
      expect(playing.volume, 1.0);
    });

    test('a placeholder pack starts a session but does not play', () {
      final state = const VibeAudioState().startSession(pack);
      expect(
        state.canPlay,
        pack.hasTrack,
        reason:
            'the six launch packs are placeholders with no track, so the '
            'session must still start without pretending to play one',
      );
      expect(state.isPlaying, pack.hasTrack);
    });

    test('holding a reveal ducks by the ~6dB §4 specifies', () {
      final state = const VibeAudioState()
          .startSession(pack)
          .duck(DuckReason.revealHeld);

      expect(state.attenuationDb, 6);
      expect(state.volume, closeTo(0.501, 0.002));

      final released = state.unduck(DuckReason.revealHeld);
      expect(released.volume, 1.0);
    });

    test('the consequence prompt ducks more than a reveal', () {
      final reveal = const VibeAudioState().duck(DuckReason.revealHeld);
      final consequence = const VibeAudioState().duck(
        DuckReason.consequencePrompt,
      );
      expect(
        consequence.volume,
        lessThan(reveal.volume),
        reason: '§4: the room should get quieter',
      );
    });

    test('the game summary swells back to full', () {
      final state = const VibeAudioState()
          .startSession(pack)
          .duck(DuckReason.consequencePrompt)
          .duck(DuckReason.interferenceStinger)
          .swellToFull();
      expect(state.volume, 1.0);
    });
  });

  group('overlapping ducks', () {
    test('the deepest reason wins rather than the sum', () {
      final state = const VibeAudioState()
          .duck(DuckReason.revealHeld)
          .duck(DuckReason.consequencePrompt)
          .duck(DuckReason.interferenceStinger);

      expect(
        state.attenuationDb,
        DuckReason.consequencePrompt.attenuationDb,
        reason:
            'summing three ducks would attenuate to near silence and restore '
            'unpredictably as they cleared',
      );
    });

    test('clearing one reason restores to the next deepest, not to full', () {
      final state = const VibeAudioState()
          .duck(DuckReason.revealHeld)
          .duck(DuckReason.consequencePrompt)
          .unduck(DuckReason.consequencePrompt);

      expect(
        state.attenuationDb,
        DuckReason.revealHeld.attenuationDb,
        reason: 'the reveal is still held; the music must not jump to full',
      );
    });

    test('order of clearing does not change the outcome', () {
      final a = const VibeAudioState()
          .duck(DuckReason.revealHeld)
          .duck(DuckReason.interferenceStinger)
          .unduck(DuckReason.revealHeld)
          .unduck(DuckReason.interferenceStinger);
      final b = const VibeAudioState()
          .duck(DuckReason.revealHeld)
          .duck(DuckReason.interferenceStinger)
          .unduck(DuckReason.interferenceStinger)
          .unduck(DuckReason.revealHeld);

      expect(a.volume, b.volume);
      expect(a.volume, 1.0);
    });

    test('unducking a reason that was never applied is harmless', () {
      final state = const VibeAudioState().unduck(DuckReason.revealHeld);
      expect(state.volume, 1.0);
    });
  });

  group('mute (§4, §5)', () {
    test('silences audio', () {
      final state = const VibeAudioState()
          .startSession(pack)
          .setMuted(muted: true);
      expect(state.volume, 0.0);
    });

    test(
      'KEEPS the watermark visible — attribution is a licence obligation',
      () {
        final muted = const VibeAudioState()
            .startSession(pack)
            .setMuted(muted: true);

        expect(muted.isMuted, isTrue);
        expect(
          muted.watermarkVisible,
          isTrue,
          reason:
              'the watermark is attribution, not an audio feature (§4). Hiding '
              'it on mute would drop a licence obligation on a volume toggle',
        );
      },
    );

    test('unmuting restores the ducked level, not full volume', () {
      final state = const VibeAudioState()
          .startSession(pack)
          .duck(DuckReason.revealHeld)
          .setMuted(muted: true)
          .setMuted(muted: false);

      expect(
        state.volume,
        closeTo(0.501, 0.002),
        reason: 'the reveal is still held underneath the mute',
      );
    });

    test('toggling twice returns to the original state', () {
      final start = const VibeAudioState().startSession(pack);
      expect(start.toggleMute().toggleMute().volume, start.volume);
    });
  });
}
