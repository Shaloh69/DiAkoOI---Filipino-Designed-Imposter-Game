/// The frame target, in **one place**.
///
/// `06-TESTING-STRATEGY.md` §8a: the reference panel is 120Hz and Flutter
/// renders at the display refresh rate by default, so the real budget is 8.3ms
/// — not the 16.6ms a 60fps assumption would give. Getting this wrong is not a
/// rounding error; it is a factor of two on every animation decision in
/// Phase 5.
///
/// **This value is PROVISIONAL.** The 120Hz-vs-60Hz decision is a human one and
/// is still open (`BLOCKED.md`). It is deliberately a single constant rather
/// than a number repeated across animation code, so changing it is one edit
/// rather than an archaeology exercise.
///
/// The evidence that decision is waiting on is in
/// `docs/adr/0008-hold-to-reveal-technique.md` — and is itself waiting on the
/// physical handset.
library;

/// A frame-rate target and the per-frame budget it implies.
enum FrameTarget {
  /// The reference panel's native rate. Provisional default.
  hz120(120, 8.3),

  /// The §8a fallback: legitimate if the reveal blur cannot hold 8.3ms, but a
  /// capped app on a 120Hz panel reads as noticeably less premium.
  hz60(60, 16.6);

  const FrameTarget(this.hz, this.budgetMs);

  final int hz;

  /// Milliseconds available per frame. A frame over this janks visibly.
  final double budgetMs;

  Duration get budget => Duration(microseconds: (budgetMs * 1000).round());
}

/// The active frame target.
abstract final class FrameBudget {
  /// **Provisional.** Defaults to the panel's native 120Hz per §8a's
  /// recommendation; a party game passed hand to hand is judged almost
  /// entirely on feel.
  ///
  /// Change here and nowhere else.
  static const FrameTarget target = FrameTarget.hz120;

  /// Whether the target is still awaiting the human decision.
  ///
  /// Surfaced so a performance report can say so rather than presenting a
  /// provisional budget as settled.
  static const bool isProvisional = true;

  static double get budgetMs => target.budgetMs;

  static Duration get budget => target.budget;
}
