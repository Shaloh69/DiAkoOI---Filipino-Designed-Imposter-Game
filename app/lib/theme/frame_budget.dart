/// The frame target, in **one place**.
///
/// `06-TESTING-STRATEGY.md` §8a: the reference panel is 120Hz and Flutter
/// renders at the display refresh rate by default, so the real budget is 8.3ms
/// — not the 16.6ms a 60fps assumption would give. Getting this wrong is not a
/// rounding error; it is a factor of two on every animation decision in
/// Phase 5.
///
/// **Decided 2026-08-23: 120Hz / 8.3ms.** A party game passed hand to hand is
/// judged almost entirely on feel, and 120Hz is why the reference phone feels
/// expensive.
///
/// It stays a single constant so A5 can flip it if real hardware disagrees
/// after the §8b mitigations have been tried — but the default is now a
/// decision, not a placeholder. Never scatter the assumption.
library;

/// A frame-rate target and the per-frame budget it implies.
enum FrameTarget {
  /// The reference panel's native rate. Provisional default.
  hz120(120, 8.3),

  /// The §8a fallback: legitimate if the reveal blur cannot hold 8.3ms on
  /// hardware, but a capped app on a 120Hz panel reads as noticeably less
  /// premium. Not the current target.
  hz60(60, 16.6);

  const FrameTarget(this.hz, this.budgetMs);

  final int hz;

  /// Milliseconds available per frame. A frame over this janks visibly.
  final double budgetMs;

  Duration get budget => Duration(microseconds: (budgetMs * 1000).round());
}

/// The active frame target.
abstract final class FrameBudget {
  /// The panel's native rate. Change here and nowhere else.
  ///
  /// A5 may lower this to [FrameTarget.hz60] if the reveal cannot hold 8.3ms
  /// on hardware after the §8b mitigations — that is the documented escape
  /// hatch, not an expected outcome.
  static const FrameTarget target = FrameTarget.hz120;

  static double get budgetMs => target.budgetMs;

  static Duration get budget => target.budget;
}
