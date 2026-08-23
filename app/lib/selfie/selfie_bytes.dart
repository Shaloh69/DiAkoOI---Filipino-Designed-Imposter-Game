import 'dart:typed_data';

/// A captured selfie, held **in memory only** (01-DESIGN.md §4b).
///
/// Two downscaled renditions and nothing else — never a path, never a file
/// handle, never the sensor frame. The type carries the guarantee: there is no
/// constructor that takes a path, so a future change that reintroduces one has
/// to be deliberate rather than accidental.
///
/// **Scope.** This is an application-level guarantee. The OS may page process
/// memory to a vendor Extended RAM swap file, which is below our layer and not
/// controllable from Flutter — see `docs/adr/0005-extended-ram-and-selfie-privacy.md`.
/// The app never writes a selfie to storage; that is the claim, and it is the
/// only claim.
class SelfieBytes {
  SelfieBytes({required Uint8List polaroid, required Uint8List gridTile})
    : _polaroid = polaroid,
      _gridTile = gridTile;

  Uint8List _polaroid;
  Uint8List _gridTile;
  bool _shredded = false;

  /// The larger rendition, for the Polaroid frame during onboarding and the
  /// pass interstitial.
  Uint8List get polaroid => _guard(_polaroid);

  /// The small rendition for the voting grid, where twenty of these are on
  /// screen at once.
  Uint8List get gridTile => _guard(_gridTile);

  bool get isShredded => _shredded;

  int get byteLength => _polaroid.lengthInBytes + _gridTile.lengthInBytes;

  Uint8List _guard(Uint8List bytes) {
    if (_shredded) {
      throw StateError(
        'This selfie has been shredded. Reading it after teardown would mean '
        'the reference outlived the roster it belongs to (01-DESIGN.md §4b).',
      );
    }
    return bytes;
  }

  /// Overwrites the bytes and drops the buffers.
  ///
  /// §8e mitigation 3: this does not unwrite a page that was already swapped,
  /// and does not pretend to. It shortens the window in which the bytes are
  /// resident, which is the part we control. Called on **New Game**, where the
  /// roster is torn down — never on Play Again, which keeps the roster.
  void shred() {
    if (_shredded) return;
    _polaroid.fillRange(0, _polaroid.length, 0);
    _gridTile.fillRange(0, _gridTile.length, 0);
    _polaroid = Uint8List(0);
    _gridTile = Uint8List(0);
    _shredded = true;
  }

  @override
  String toString() => _shredded
      ? 'SelfieBytes(shredded)'
      : 'SelfieBytes(${_polaroid.lengthInBytes}B + '
            '${_gridTile.lengthInBytes}B)';
}
