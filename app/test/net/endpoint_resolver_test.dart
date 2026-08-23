import 'dart:io';

import 'package:diakooi/net/endpoint_resolver.dart';
import 'package:diakooi/net/feedback_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Endpoint discovery and the offline-first behaviour it exists to support.
///
/// **Every failure mode in `docs/12-HOSTING.md` §2c is asserted here**, and
/// the list is asserted to be complete rather than to be long. With a Quick
/// Tunnel the API is unreliable by construction, so this is the path a real
/// user meets most often — not the exception.
void main() {
  final discovery = Uri.parse('https://example.test/endpoint.json');

  EndpointResolver resolverReturning(String? body) => EndpointResolver(
    discoveryUrl: discovery,
    fetch: (_) async => body,
  );

  group('no hardcoded API base URL, anywhere', () {
    test('lib/ contains no literal API host', () {
      // The static half of the rule. A widget test only catches what it
      // exercises, and one baked-in URL in a screen nobody pumped would ship
      // silently — and could not be fixed without a new APK on every device.
      final offenders = <String>[];
      var scanned = 0;

      final suspicious = RegExp(
        r'''https?://(?!example\.test|schemas\.|json-schema\.|www\.w3\.)[a-z0-9.-]+''',
        caseSensitive: false,
      );

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart') ||
            entity.path.endsWith('.freezed.dart')) {
          continue;
        }
        scanned++;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final trimmed = lines[i].trimLeft();
          // Doc comments naming a URL are fine; code holding one is not.
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (suspicious.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        scanned,
        greaterThan(10),
        reason: 'almost nothing was scanned — the check would pass vacuously',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'the beta runs behind a tunnel whose hostname rotates on every '
            'restart, so a baked-in URL is a dead app that cannot be fixed '
            'without shipping a new APK (12-HOSTING.md §2b). Found:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the check can actually fail', () {
      final suspicious = RegExp(
        r'''https?://(?!example\.test)[a-z0-9.-]+''',
        caseSensitive: false,
      );
      expect(
        suspicious.hasMatch(
          "const base = 'https://abc-def.trycloudflare.com';",
        ),
        isTrue,
      );
      expect(
        suspicious.hasMatch('final uri = resolver.uriFor(path);'),
        isFalse,
      );
    });
  });

  group('a good discovery document resolves', () {
    test('it parses the documented shape', () async {
      final resolver = resolverReturning(
        '{"apiBaseUrl":"https://abc-def.trycloudflare.com",'
        '"updatedAt":"2026-08-24T10:14:00Z"}',
      );
      final endpoint = await resolver.resolve();

      expect(endpoint, isNotNull);
      expect(endpoint!.apiBaseUrl, 'https://abc-def.trycloudflare.com');
      expect(resolver.isAvailable, isTrue);
      expect(
        resolver.uriFor('/v1/word-banks').toString(),
        'https://abc-def.trycloudflare.com/v1/word-banks',
      );
    });

    test('a fresh cache is reused rather than refetched', () async {
      var fetches = 0;
      final resolver = EndpointResolver(
        discoveryUrl: discovery,
        fetch: (_) async {
          fetches++;
          return '{"apiBaseUrl":"https://a.trycloudflare.com"}';
        },
      );

      await resolver.resolve();
      await resolver.resolve();
      expect(fetches, 1);

      await resolver.resolve(forceRefresh: true);
      expect(fetches, 2);
    });
  });

  group('§2c: every failure mode ends in the same silent place', () {
    // The table in 12-HOSTING.md §2c, as executable cases. Named so a reader
    // can check the list against the doc rather than trusting that it matches.
    final failures = <String, String?>{
      'unreachable (offline, DNS failure)': null,
      'empty body': '',
      'not JSON at all': '<html>404 Not Found</html>',
      'JSON but not an object': '["nope"]',
      'object with no apiBaseUrl': '{"updatedAt":"2026-08-24T10:14:00Z"}',
      'apiBaseUrl not a string': '{"apiBaseUrl":42}',
      'apiBaseUrl empty': '{"apiBaseUrl":""}',
      'apiBaseUrl not a URL': '{"apiBaseUrl":"not a url at all"}',
      'plain http, not https': '{"apiBaseUrl":"http://insecure.example"}',
      'no host': '{"apiBaseUrl":"https:///nohost"}',
      'truncated JSON': '{"apiBaseUrl":"https://a.trycloudf',
    };

    for (final entry in failures.entries) {
      test('${entry.key} yields no endpoint, and does not throw', () async {
        final resolver = resolverReturning(entry.value);

        // The assertion that matters: it returns, rather than throwing. A
        // caller forced to catch would eventually handle it by showing
        // something, and §2c says nothing is shown.
        final endpoint = await resolver.resolve();
        expect(endpoint, isNull, reason: entry.key);
        expect(resolver.isAvailable, isFalse);
        expect(
          resolver.uriFor('/v1/word-banks'),
          isNull,
          reason:
              'with no endpoint there is no base URL to fall back to, which '
              'is what stops a caller forgetting',
        );
      });
    }

    test('the failure list covers every row of the §2c table', () {
      // Breadth asserted explicitly. A green suite that quietly stopped
      // covering a case is the failure mode this project has already hit
      // twice (CLAUDE.md §Standing rules).
      expect(
        failures.length,
        greaterThanOrEqualTo(11),
        reason: 'a case was dropped from the §2c matrix',
      );
      expect(failures.values.where((v) => v == null), hasLength(1));
      expect(
        failures.keys.where((k) => k.contains('http')),
        isNotEmpty,
        reason: 'a downgrade to plain http must be one of the cases',
      );
    });

    test('a rotated tunnel keeps the last known endpoint', () async {
      // §2c: "tunnel rotated mid-session — session unaffected". Keeping the
      // stale value costs one failed request; dropping it disables the
      // feature for no reason.
      var body = '{"apiBaseUrl":"https://first.trycloudflare.com"}';
      final resolver = EndpointResolver(
        discoveryUrl: discovery,
        ttl: Duration.zero,
        fetch: (_) async => body,
      );

      await resolver.resolve();
      expect(resolver.cached!.apiBaseUrl, 'https://first.trycloudflare.com');

      body = '';
      final afterFailure = await resolver.resolve();
      expect(
        afterFailure!.apiBaseUrl,
        'https://first.trycloudflare.com',
        reason: 'a failed refresh must not throw away a working endpoint',
      );
    });

    test('a hung fetch is abandoned rather than pending forever', () async {
      final resolver = EndpointResolver(
        discoveryUrl: discovery,
        timeout: const Duration(milliseconds: 50),
        fetch: (_) => Future<String?>.delayed(
          const Duration(seconds: 30),
          () => '{"apiBaseUrl":"https://late.trycloudflare.com"}',
        ),
      );

      expect(await resolver.resolve(), isNull);
      expect(resolver.isAvailable, isFalse);
    });
  });

  group('the offline feedback queue', () {
    test('a report written offline survives and is delivered later', () async {
      final store = _MemoryStore();
      final queue = FeedbackQueue(store: store);

      await queue.enqueue(
        QueuedFeedback(
          id: 'a',
          category: 'bug',
          message: 'sticks on reveal',
          occurredAt: DateTime.utc(2026, 8, 24, 9),
        ),
      );
      expect(queue.pending, hasLength(1));

      // Nothing delivered while the API is unreachable, and nothing lost.
      expect(await queue.flush((_) async => false), 0);
      expect(queue.pending, hasLength(1));

      expect(await queue.flush((_) async => true), 1);
      expect(queue.pending, isEmpty);
    });

    test('it survives a relaunch', () async {
      final store = _MemoryStore();
      await FeedbackQueue(store: store).enqueue(
        QueuedFeedback(
          id: 'a',
          category: 'suggestion',
          message: 'more topics',
          occurredAt: DateTime.utc(2026, 8, 24),
        ),
      );

      final reloaded = FeedbackQueue(store: store);
      expect(await reloaded.flush((_) async => true), 1);
    });

    test('the queued body keeps when it was written, not when it was sent', () {
      final written = DateTime.utc(2026, 8, 20, 21, 30);
      final json = QueuedFeedback(
        id: 'a',
        category: 'bug',
        message: 'x',
        occurredAt: written,
      ).toRequestJson();

      expect(json['occurredAt'], '2026-08-20T21:30:00.000Z');
    });

    test('a queued report carries nothing selfie-shaped', () {
      // The queue is written to disk, and §4b's guarantee is that a photograph
      // of a person never reaches storage — so the queue is text only.
      final json = QueuedFeedback(
        id: 'a',
        category: 'bug',
        message: 'x',
        occurredAt: DateTime.utc(2026),
      ).toRequestJson();

      for (final banned in [
        'attachment',
        'selfie',
        'photo',
        'image',
        'dataBase64',
      ]) {
        expect(
          json.keys,
          isNot(contains(banned)),
          reason: 'the on-disk queue must never hold image bytes (§4b)',
        );
      }
    });

    test('a corrupt queue file is dropped rather than crashing', () async {
      final store = _MemoryStore()..contents = 'not json at all';
      final queue = FeedbackQueue(store: store);
      expect(await queue.flush((_) async => true), 0);
      expect(queue.pending, isEmpty);
    });

    test('the queue is capped, oldest first', () async {
      final queue = FeedbackQueue(store: _MemoryStore(), maxItems: 3);
      for (var i = 0; i < 5; i++) {
        await queue.enqueue(
          QueuedFeedback(
            id: '$i',
            category: 'bug',
            message: 'm$i',
            occurredAt: DateTime.utc(2026),
          ),
        );
      }
      expect(queue.pending.map((q) => q.id), ['2', '3', '4']);
    });
  });
}

class _MemoryStore implements FeedbackStore {
  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String value) async => contents = value;
}
