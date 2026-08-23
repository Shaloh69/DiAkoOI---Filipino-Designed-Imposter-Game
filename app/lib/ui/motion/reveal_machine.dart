import 'package:diakooi/theme/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Where a reveal card is (01-DESIGN.md §5, §6b).
///
/// Four states, and the transitions between them are not symmetric — which is
/// the whole reason this is a state machine rather than one controller run
/// forwards and backwards. **Closing is instant.** A card that eases shut
/// is a card the next player can read on the way down, and at a table that is
/// the normal way this game leaks.
enum RevealState {
  /// Face down. Nothing legible.
  idle,

  /// A thumb is on it and the blur is clearing.
  holding,

  /// Fully clear, thumb still down.
  revealed,

  /// Thumb lifted. Snaps, does not ease.
  closing,
}

/// Drives [RevealState] and exposes the values a reveal renders from.
///
/// ## On Rive
///
/// `08-PROMPTS.md` §6 names Rive for this card specifically, and it is the
/// right tool for a state machine with a crew/imposter axis on top of a motion
/// axis. It is **not** used here, for two reasons that are worth stating rather
/// than leaving as an omission:
///
/// 1. **ADR 0008 put Rive third in a fallback ladder, not first.** The spike
///    chose `prerenderedCrossFade` and said explicitly that reaching for Rive
///    to de-risk a cost nobody has measured inverts the order. That measurement
///    still needs the handset. Applying the spike's conclusion is what this
///    phase was told to do.
/// 2. **A Rive state machine needs a `.riv` artefact, and none exists.**
///    Committing a hand-stubbed one into an art pipeline is the same mistake as
///    a fake silent `.ogg` in a licence-audited folder: something pretending to
///    be a real asset, which then hides the absence of the real one.
///
/// So the state machine is real and lives here, in Dart, driving the technique
/// ADR 0008 selected. It is deliberately shaped so a Rive artefact can be
/// dropped in behind the same four states without touching a caller: the states
/// are named, the progress is a single 0..1 value, and the role and motion axes
/// are inputs rather than branches in the widget tree.
class RevealMachine extends ChangeNotifier {
  RevealMachine({
    required TickerProvider vsync,
    required this.beats,
    required this.spring,
    required this.reduceMotion,
  }) {
    _controller = AnimationController(vsync: vsync, duration: beats.snapIn)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
  }

  final VibeBeats beats;
  final SpringDescription spring;
  final bool reduceMotion;

  late final AnimationController _controller;

  RevealState _state = RevealState.idle;
  RevealState get state => _state;

  /// 0 obscured, 1 clear. The single value a renderer needs.
  double get progress => _controller.value;

  /// True once the card has actually been legible, which is what gates the
  /// Continue button — a player must not be able to pass the phone on without
  /// having looked.
  ///
  /// Threshold, not completion. A spring settles asymptotically and a slow pack
  /// takes visibly longer to finish than a fast one, so gating on the animation
  /// *ending* would make Tahimik demand a longer press than Sayaw for the same
  /// amount of reading. [legibleAt] is where the word is readable; past that,
  /// it has been read.
  bool get hasBeenRead => _hasBeenRead;
  bool _hasBeenRead = false;

  /// Progress at which the word is legible enough to count as read.
  static const legibleAt = 0.9;

  void _onTick() {
    if (!_hasBeenRead && _controller.value >= legibleAt) {
      _hasBeenRead = true;
      _set(RevealState.revealed);
    }
    notifyListeners();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _state == RevealState.holding) {
      _set(RevealState.revealed);
      _hasBeenRead = true;
    }
  }

  void _set(RevealState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  /// Thumb down.
  void hold() {
    if (_state == RevealState.revealed || _state == RevealState.holding) return;
    _set(RevealState.holding);
    if (reduceMotion) {
      // A fade, not a spring. The palette still applies; only the motion is
      // collapsed (03-VIBE-SYSTEM.md §6).
      _controller.animateTo(1, duration: beats.snapIn);
    } else {
      // Springs from wherever it currently is, so a re-press mid-close picks up
      // the value rather than restarting — that is what makes it interruptible.
      _controller.animateWith(
        SpringSimulation(spring, _controller.value, 1, 0),
      );
    }
  }

  /// Thumb up. **Instant**, on every pack and in every motion setting.
  ///
  /// This is the one place in the game that ignores the pack's tempo, and it
  /// does so deliberately: a slow pack must not mean a slower leak.
  void release() {
    if (_state == RevealState.idle) return;
    _set(RevealState.closing);
    _controller
      ..stop()
      ..value = 0;
    _set(RevealState.idle);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }
}
