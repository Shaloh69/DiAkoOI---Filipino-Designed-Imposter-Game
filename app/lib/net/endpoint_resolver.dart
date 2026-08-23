import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Where the API actually is, resolved at runtime (docs/12-HOSTING.md §2b).
///
/// **There is no hardcoded API base URL anywhere in this app, ever.** The beta
/// runs behind a Cloudflare Quick Tunnel whose hostname rotates on every
/// `cloudflared` restart, so a baked-in URL is a dead app — and one that
/// cannot be fixed without shipping a new APK to every installed copy.
///
/// The discovery document lives at a stable, free location that already
/// belongs to us. When the domain is eventually bought, switching is a
/// one-line edit to that file with zero app changes.
@immutable
class Endpoint {
  const Endpoint({required this.apiBaseUrl, required this.updatedAt});

  final String apiBaseUrl;
  final DateTime updatedAt;

  /// Parses the discovery document, or returns null.
  ///
  /// **Null on anything unexpected**, including a well-formed document with a
  /// hostile URL. A malformed endpoint.json is indistinguishable from being
  /// offline as far as the app is concerned, and both end in the same silent
  /// fallback (§2c).
  static Endpoint? tryParse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return null;

      final url = decoded['apiBaseUrl'];
      if (url is! String || url.isEmpty) return null;

      final parsed = Uri.tryParse(url);
      // HTTPS only, and it must actually have a host. A discovery document is
      // a redirect we follow without a user seeing it, so it does not get to
      // downgrade the transport or point at a local socket.
      if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
        return null;
      }

      final updated = decoded['updatedAt'];
      return Endpoint(
        apiBaseUrl: url,
        updatedAt: updated is String
            ? (DateTime.tryParse(updated) ??
                  DateTime.fromMillisecondsSinceEpoch(0))
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
    } on Object {
      // Deliberately catch-all: every failure here is the same failure to the
      // app, and there is no branch worth distinguishing.
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Endpoint &&
      other.apiBaseUrl == apiBaseUrl &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(apiBaseUrl, updatedAt);
}

/// Where the rotating API URL is published (docs/12-HOSTING.md §2b).
///
/// **This is the one URL that is deliberately baked in, and it is not an API
/// base URL.** It is a stable, free location that already belongs to the
/// project: `raw.githubusercontent.com` costs nothing, never rotates, and is
/// reachable without an account. Everything about the API — host, scheme,
/// availability — is read from the document it serves.
///
/// That is the whole trick. When a domain is eventually bought, the switch is
/// a one-line edit to `endpoint.json` with zero app changes and no forced
/// update; without this constant, every tunnel rotation would strand every
/// installed copy.
const discoveryDocumentUrl =
    'https://raw.githubusercontent.com/Shaloh69/'
    'DiAkoOI---Filipino-Designed-Imposter-Game/main/endpoint.json';

/// Fetches a URL and returns the body, or null on any failure.
typedef DiscoveryFetch = Future<String?> Function(Uri url);

/// Resolves the API base URL, and gives up quietly when it cannot.
///
/// Every failure mode in `12-HOSTING.md` §2c ends in the same place: no
/// endpoint, bundled content, network features off, **no error dialog**. That
/// is not error handling as an afterthought — with a Quick Tunnel the API is
/// unreliable by construction, so silence is the designed behaviour rather
/// than a degraded one.
class EndpointResolver {
  EndpointResolver({
    required this.discoveryUrl,
    DiscoveryFetch? fetch,
    this.ttl = const Duration(minutes: 15),
    this.timeout = const Duration(seconds: 5),
  }) : _fetch = fetch ?? _defaultFetch;

  /// The stable location the rotating URL is published to (§2b).
  final Uri discoveryUrl;

  final DiscoveryFetch _fetch;

  /// How long a resolved endpoint is trusted before re-checking. Short,
  /// because the thing it points at rotates.
  final Duration ttl;

  /// Hard ceiling on the lookup. Nothing about starting a game waits on this,
  /// but a hung socket should not keep a queue retry pending forever.
  final Duration timeout;

  Endpoint? _cached;
  DateTime? _cachedAt;

  /// The last successfully resolved endpoint, even if stale.
  Endpoint? get cached => _cached;

  /// True when network features should be available at all.
  bool get isAvailable => _cached != null;

  bool get _isFresh {
    final at = _cachedAt;
    return at != null && DateTime.now().difference(at) < ttl;
  }

  /// Resolves the endpoint, using the cache when it is fresh.
  ///
  /// Returns null rather than throwing. A caller that has to handle an
  /// exception here would eventually handle it by showing something, and §2c
  /// says nothing is shown.
  Future<Endpoint?> resolve({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh) return _cached;

    // `.timeout(onTimeout:)` is avoided deliberately. It dispatches on the
    // future's RUNTIME type, so a fetch declared to return `Future<String?>`
    // but actually returning `Future<String>` — which is what any real
    // implementation does — rejects a null-returning callback at runtime.
    // Catching the timeout instead is typed the same either way, and also
    // covers a fetch that throws rather than returning null.
    String? body;
    try {
      body = await _fetch(discoveryUrl).timeout(timeout);
    } on Object {
      body = null;
    }

    if (body == null) {
      // Offline, 404, 500, DNS failure — all identical from here. The last
      // known endpoint is kept: a rotated tunnel is more likely than a
      // permanently dead one, and a stale guess costs one failed request.
      return _cached;
    }

    final parsed = Endpoint.tryParse(body);
    if (parsed == null) return _cached;

    _cached = parsed;
    _cachedAt = DateTime.now();
    return parsed;
  }

  /// Builds a full URL for an API path, or null when there is no endpoint.
  ///
  /// Returning null is what makes a caller unable to forget: there is no base
  /// URL to fall back to, so a network feature simply does not run.
  Uri? uriFor(String path) {
    final base = _cached?.apiBaseUrl;
    if (base == null) return null;
    return Uri.tryParse('$base$path');
  }

  static Future<String?> _defaultFetch(Uri url) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) return null;
      return await response.transform(utf8.decoder).join();
    } on Object {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
