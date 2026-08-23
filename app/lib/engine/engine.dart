/// The DiAkoOi game engine.
///
/// **Pure Dart.** Nothing under `lib/engine/` may import `package:flutter` —
/// see CLAUDE.md §Hard rules. `test/engine/purity_test.dart` enforces it, so
/// the rule fails a build rather than eroding quietly.
///
/// `01-DESIGN.md` is the source of truth for every rule here. Several look
/// wrong until you read the rationale — §7a (the Mayor tie rule), §7b (the
/// damage cap), §9b (why Role Swap is rejected) and §9c (Spread the Blame,
/// Near-Unanimous) especially. Do not "fix" them.
library;

export 'machine/game_machine.dart';
export 'models/content.dart';
export 'models/enums.dart';
export 'models/interference.dart';
export 'models/player.dart';
export 'models/room.dart';
export 'models/round.dart';
export 'models/settings.dart';
export 'resolution/life_check.dart';
export 'resolution/resolve_round.dart';
export 'rng/seeded_rng.dart';
export 'selection/round_setup.dart';
export 'selection/topic_selector.dart';
export 'selection/turn_order.dart';
