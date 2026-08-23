import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:flutter/material.dart';

/// A player's selfie, or their monogram if they skipped (§4).
///
/// **Never takes a path.** The bytes come from [SeatedPlayer.selfie], which is
/// in-memory only, and `Image.memory` is the only image constructor this app
/// uses for a player (01-DESIGN.md §4b).
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.seat,
    this.size = 96,
    this.framed = true,
    this.showCaption = false,
    this.tilt = 0,
    super.key,
  });

  final SeatedPlayer seat;
  final double size;

  /// The Polaroid frame is the running motif, but a dense voting grid does not
  /// have room for twenty of them.
  final bool framed;

  /// The name under the frame. Off by default because most callers already
  /// render the name themselves and two copies read as a mistake.
  final bool showCaption;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final selfie = seat.selfie;
    // The larger rendition only where it will actually be seen at that size;
    // the grid tile exists because twenty polaroids is the memory §8e warns
    // about.
    final image = selfie == null
        ? MonogramBadge(name: seat.player.name, size: size)
        : Image.memory(
            size > 120 ? selfie.polaroid : selfie.gridTile,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );

    if (!framed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.12),
        child: SizedBox(width: size, height: size, child: image),
      );
    }
    return PolaroidFrame(
      size: size,
      tilt: tilt,
      caption: showCaption ? seat.player.name : null,
      child: image,
    );
  }
}
