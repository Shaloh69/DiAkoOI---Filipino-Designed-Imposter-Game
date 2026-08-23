import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// How the hold-to-reveal obscuring effect is produced.
///
/// The reveal is the core interaction of the whole game (01-DESIGN.md §6b): a
/// blur clearing under a thumb press. On the reference device that runs on a
/// **Mali-G615 MC2 — a two-core GPU** — driving a 6.77" 1080p panel on LPDDR4X
/// bandwidth, and `BackdropFilter` is among the most expensive things available
/// on a mobile GPU.
///
/// This is an enum rather than a hardcoded choice so switching techniques is a
/// config change, not a rewrite. `06-TESTING-STRATEGY.md` §8b is explicit that
/// discovering the cost in Phase 5 means reworking the interaction the product
/// is built around.
///
/// See `docs/adr/0008-hold-to-reveal-technique.md`.
enum RevealTechnique {
  /// `BackdropFilter` re-blurring the live subtree every frame.
  ///
  /// Highest fidelity and highest cost: it forces a `saveLayer`, reads back the
  /// backdrop, and the whole blur is recomputed on each frame of the hold.
  liveBackdropFilter,

  /// Blur rendered once, then cross-faded to clear.
  ///
  /// `06-TESTING-STRATEGY.md` §8b option 1 — "cheapest fix, visually
  /// near-identical". The expensive filter runs once at build; the animation
  /// only drives opacity, which is close to free.
  prerenderedCrossFade,

  /// Blur a downscaled surface and scale it back up.
  ///
  /// §8b option 2. Blur radius is perceptual, resolution is not, so a blur of a
  /// half-resolution surface reads almost identically at a quarter of the
  /// fill cost.
  downscaledBlur,
}

/// The obscuring layer over a reveal card, cleared by holding.
///
/// [progress] runs 0 (fully obscured) to 1 (fully clear).
class RevealSurface extends StatelessWidget {
  const RevealSurface({
    required this.child,
    required this.progress,
    required this.technique,
    required this.maxBlurSigma,
    this.downscaleFactor = 0.5,
    super.key,
  });

  final Widget child;

  /// 0 = obscured, 1 = revealed.
  final double progress;

  final RevealTechnique technique;

  /// Blur sigma at [progress] 0. Resolves from the active pack's theme, never
  /// hardcoded at a call site.
  final double maxBlurSigma;

  /// Resolution multiplier for [RevealTechnique.downscaledBlur].
  final double downscaleFactor;

  double get _sigma => maxBlurSigma * (1 - progress.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    // Reduced motion collapses every profile to a fade (03-VIBE-SYSTEM.md §6),
    // and a live per-frame filter is the opposite of that. The palette still
    // applies — theme and motion are independent.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effective = reduceMotion
        ? RevealTechnique.prerenderedCrossFade
        : technique;

    return switch (effective) {
      RevealTechnique.liveBackdropFilter => _LiveBackdrop(
        sigma: _sigma,
        child: child,
      ),
      RevealTechnique.prerenderedCrossFade => _PrerenderedCrossFade(
        sigma: maxBlurSigma,
        progress: progress.clamp(0.0, 1.0),
        child: child,
      ),
      RevealTechnique.downscaledBlur => _DownscaledBlur(
        sigma: _sigma,
        factor: downscaleFactor,
        child: child,
      ),
    };
  }
}

/// Re-filters the live subtree every frame. The expensive one.
class _LiveBackdrop extends StatelessWidget {
  const _LiveBackdrop({required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma <= 0.01) return child;
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          // Forces a saveLayer and a backdrop read-back on every frame the
          // sigma changes — which, during a hold, is every frame.
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blurs once, then animates opacity only.
///
/// The blurred copy is built with a constant sigma so the filter is not
/// re-evaluated as [progress] changes; only the opacity of the two layers
/// moves, and opacity on an already-rasterised layer is cheap.
class _PrerenderedCrossFade extends StatelessWidget {
  const _PrerenderedCrossFade({
    required this.sigma,
    required this.progress,
    required this.child,
  });

  final double sigma;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Opacity(opacity: progress, child: child),
          // RepaintBoundary so the blurred copy rasterises once and is then
          // only composited — this is the whole point of the technique.
          IgnorePointer(
            child: Opacity(
              opacity: 1 - progress,
              child: RepaintBoundary(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blurs a downscaled surface and scales it back up.
class _DownscaledBlur extends StatelessWidget {
  const _DownscaledBlur({
    required this.sigma,
    required this.factor,
    required this.child,
  });

  final double sigma;
  final double factor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma <= 0.01) return child;
    // Sigma is scaled with the surface so the perceived radius is unchanged;
    // the saving is fill rate, not blur strength.
    return ClipRect(
      child: Transform.scale(
        scale: 1 / factor,
        child: Transform.scale(
          scale: factor,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: sigma * factor,
              sigmaY: sigma * factor,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
