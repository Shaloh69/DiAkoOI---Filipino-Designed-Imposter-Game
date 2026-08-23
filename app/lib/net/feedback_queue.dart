import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One report waiting to be delivered.
///
/// Carries `occurredAt` because a queued report keeps the time it was
/// *written*, not the time it was finally sent — those can be days apart on a
/// Quick Tunnel (docs/12-HOSTING.md §2c).
@immutable
class QueuedFeedback {
  const QueuedFeedback({
    required this.id,
    required this.category,
    required this.message,
    required this.occurredAt,
    this.appVersion,
    this.deviceModel,
    this.contactEmail,
  });

  final String id;
  final String category;
  final String message;
  final DateTime occurredAt;
  final String? appVersion;
  final String? deviceModel;
  final String? contactEmail;

  /// The request body, exactly as `openapi.yaml` documents it.
  ///
  /// **No attachment field, and no selfie-shaped field of any kind.** A queued
  /// report is written to disk, and §4b's guarantee is that a photograph of a
  /// person never reaches storage — so the queue carries text only.
  Map<String, dynamic> toRequestJson() => {
    'category': category,
    'message': message,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    if (appVersion != null) 'appVersion': appVersion,
    if (deviceModel != null) 'deviceModel': deviceModel,
    if (contactEmail != null) 'contactEmail': contactEmail,
  };

  Map<String, dynamic> toJson() => {'id': id, ...toRequestJson()};

  static QueuedFeedback? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final category = json['category'];
    final message = json['message'];
    if (id is! String || category is! String || message is! String) return null;

    return QueuedFeedback(
      id: id,
      category: category,
      message: message,
      occurredAt:
          DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      appVersion: json['appVersion'] as String?,
      deviceModel: json['deviceModel'] as String?,
      contactEmail: json['contactEmail'] as String?,
    );
  }
}

/// Where the queue is kept between launches.
///
/// An interface so the queue is testable without a plugin, and so the one
/// place that touches persistence stays one place.
abstract interface class FeedbackStore {
  Future<String?> read();
  Future<void> write(String contents);
}

/// Delivers one report. Returns true when the server accepted it.
typedef FeedbackSender = Future<bool> Function(QueuedFeedback item);

/// Feedback written while offline, retried later (§16a, §2c).
///
/// The API is allowed to be unreachable, so "send" means "enqueue and try" —
/// a user who writes a bug report on a bus should not be told to reconnect,
/// and should not lose it either.
class FeedbackQueue {
  FeedbackQueue({required this.store, this.maxItems = 50});

  final FeedbackStore store;

  /// A cap, because this is a party game and an unbounded on-disk queue is a
  /// slow leak nobody will ever notice. Oldest goes first.
  final int maxItems;

  List<QueuedFeedback> _items = [];
  bool _loaded = false;

  List<QueuedFeedback> get pending => List.unmodifiable(_items);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await store.read();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _items = [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) ?QueuedFeedback.tryParse(entry),
      ];
    } on Object {
      // A corrupt queue file is dropped rather than crashing the app. The
      // reports are lost, which is bad; refusing to start is worse.
      _items = [];
    }
  }

  Future<void> _persist() =>
      store.write(jsonEncode([for (final item in _items) item.toJson()]));

  /// Adds a report and persists it immediately.
  Future<void> enqueue(QueuedFeedback item) async {
    await _ensureLoaded();
    _items.add(item);
    if (_items.length > maxItems) {
      _items = _items.sublist(_items.length - maxItems);
    }
    await _persist();
  }

  /// Tries to deliver everything pending.
  ///
  /// Stops at the first failure and keeps the rest: if the tunnel is down,
  /// hammering it with the whole queue achieves nothing. Returns how many were
  /// delivered.
  Future<int> flush(FeedbackSender send) async {
    await _ensureLoaded();
    if (_items.isEmpty) return 0;

    var delivered = 0;
    while (_items.isNotEmpty) {
      final accepted = await send(_items.first);
      if (!accepted) break;
      _items.removeAt(0);
      delivered++;
    }
    if (delivered > 0) await _persist();
    return delivered;
  }
}
