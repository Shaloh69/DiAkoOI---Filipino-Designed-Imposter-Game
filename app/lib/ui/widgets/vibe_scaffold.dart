import 'package:diakooi/providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The frame every game screen sits in.
///
/// Supplies the pack's background, safe-area padding derived from the pack's
/// own gutter, and the attribution watermark — which §5 requires on screen and
/// which stays visible when audio is muted, because attribution is a licence
/// obligation rather than an audio feature.
///
/// **No colour, spacing or radius is decided here.** Everything comes from
/// `context.vibe`.
class VibeScaffold extends StatelessWidget {
  const VibeScaffold({
    required this.child,
    this.title,
    this.subtitle,
    this.banner,
    this.footer,
    this.onBack,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// The §9f constraint banner slot. Empty in the base game; Phase 5 fills it.
  final Widget? banner;

  /// Primary actions, pinned above the watermark so a thumb reaches them.
  final Widget? footer;

  /// Null hides the back affordance — used where going back would mean seeing
  /// a word that was already passed on.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: vibe.gutter * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: vibe.gutter),
              if (onBack != null || title != null)
                Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        color: palette.textMuted,
                        tooltip: 'Back',
                      ),
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: vibe.pack.type.display,
                          ),
                        ),
                      ),
                    const _MuteButton(),
                  ],
                ),
              if (subtitle != null) ...[
                SizedBox(height: vibe.gutter * 0.5),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ],
              if (banner != null) ...[
                SizedBox(height: vibe.gutter),
                banner!,
              ],
              SizedBox(height: vibe.gutter),
              Expanded(child: child),
              if (footer != null) ...[
                SizedBox(height: vibe.gutter),
                footer!,
              ],
              const VibeWatermark(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one button style in the game.
///
/// A party game passed hand to hand gets tapped by people who have never seen
/// it before, so there is one shape and it is large.
class VibeButton extends StatelessWidget {
  const VibeButton({
    required this.label,
    required this.onPressed,
    this.emphasis = VibeEmphasis.primary,
    this.icon,
    super.key,
  });

  final String label;

  /// Null disables the button. Kept explicit so a disabled primary action is a
  /// deliberate state rather than a tap that quietly does nothing.
  final VoidCallback? onPressed;
  final VibeEmphasis emphasis;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final enabled = onPressed != null;

    final background = switch (emphasis) {
      VibeEmphasis.primary => palette.crew,
      VibeEmphasis.danger => palette.danger,
      VibeEmphasis.quiet => palette.surface,
    };
    final foreground = switch (emphasis) {
      VibeEmphasis.quiet => palette.textPrimary,
      _ => palette.bg,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? background : palette.surfaceAlt,
        borderRadius: vibe.cardRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: vibe.cardRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: vibe.gutter * 2,
              vertical: vibe.gutter * 1.75,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: enabled ? foreground : palette.textMuted,
                    size: 20,
                  ),
                  SizedBox(width: vibe.gutter),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: enabled ? foreground : palette.textMuted,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: vibe.pack.type.display,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum VibeEmphasis { primary, danger, quiet }

/// Mute, reachable from every screen.
///
/// A party game gets played in a room that already has music on, and hunting
/// for a settings screen mid-pass is not something anyone will do. Muting does
/// **not** hide the attribution watermark — that is a licence obligation, not
/// an audio feature (§5).
class _MuteButton extends ConsumerWidget {
  const _MuteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: settings.audioOn,
      builder: (context, on, _) => IconButton(
        onPressed: settings.toggleAudioOn,
        icon: Icon(on ? Icons.volume_up_outlined : Icons.volume_off_outlined),
        color: context.vibe.palette.textMuted,
        tooltip: on ? 'Mute' : 'Unmute',
      ),
    );
  }
}
