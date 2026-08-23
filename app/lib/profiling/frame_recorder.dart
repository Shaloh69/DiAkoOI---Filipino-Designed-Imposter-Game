import 'dart:convert';
import 'dart:io';

import 'package:diakooi/theme/frame_budget.dart';
import 'package:flutter/scheduler.dart';

/// One scenario's frame timings.
///
/// **Raw numbers, and only numbers this actually observed.** No estimate, no
/// extrapolation, no figure derived from a desktop run — ADR 0008 rejected all
/// three, and a measurement harness that produced one would be worse than the
/// gap it filled.
class FrameReport {
  const FrameReport({
    required this.scenario,
    required this.packId,
    required this.buildMicros,
    required this.rasterMicros,
    required this.totalMicros,
  });

  final String scenario;
  final String packId;

  /// Per frame, in microseconds. Build and raster are separated because they
  /// fail for different reasons: build is Dart work, raster is the Mali-G615
  /// MC2 (06-TESTING-STRATEGY.md §8b).
  final List<int> buildMicros;
  final List<int> rasterMicros;
  final List<int> totalMicros;

  int get frameCount => totalMicros.length;

  double get budgetMicros => FrameBudget.target.budgetMs * 1000;

  int get overBudget => totalMicros.where((t) => t > budgetMicros).length;

  double get worstMs =>
      totalMicros.isEmpty ? 0 : totalMicros.reduce(_max) / 1000;

  double get medianMs {
    if (totalMicros.isEmpty) return 0;
    final sorted = [...totalMicros]..sort();
    return sorted[sorted.length ~/ 2] / 1000;
  }

  /// The 99th percentile, which is the number that decides whether it janks.
  /// A median inside budget with a bad tail still looks broken in the hand.
  double get p99Ms {
    if (totalMicros.isEmpty) return 0;
    final sorted = [...totalMicros]..sort();
    final index = ((sorted.length - 1) * 0.99).round();
    return sorted[index] / 1000;
  }

  static int _max(int a, int b) => a > b ? a : b;

  Map<String, dynamic> toJson() => {
    'scenario': scenario,
    'packId': packId,
    'frameTarget': FrameBudget.target.name,
    'budgetMs': FrameBudget.target.budgetMs,
    'frameCount': frameCount,
    'framesOverBudget': overBudget,
    'medianMs': medianMs,
    'p99Ms': p99Ms,
    'worstMs': worstMs,
    // Every frame, so a human can re-derive any statistic rather than trusting
    // the ones chosen here.
    'buildMicros': buildMicros,
    'rasterMicros': rasterMicros,
    'totalMicros': totalMicros,
  };

  @override
  String toString() {
    String ms(double value) => '${value.toStringAsFixed(2)}ms';
    return '$scenario [$packId] n=$frameCount median=${ms(medianMs)} '
        'p99=${ms(p99Ms)} worst=${ms(worstMs)} over=$overBudget';
  }
}

/// Collects [FrameTiming] from the engine for the duration of a scenario.
///
/// `SchedulerBinding.addTimingsCallback` reports what the engine actually did
/// — including raster, which is the half the Dart side cannot see and the half
/// §8b says is at risk on a two-core GPU.
class FrameRecorder {
  FrameRecorder();

  final List<FrameTiming> _timings = [];
  bool _recording = false;

  void start() {
    _timings.clear();
    if (_recording) return;
    _recording = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_recording) _timings.addAll(timings);
  }

  FrameReport stop({required String scenario, required String packId}) {
    if (_recording) {
      _recording = false;
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    return FrameReport(
      scenario: scenario,
      packId: packId,
      buildMicros: [
        for (final t in _timings) t.buildDuration.inMicroseconds,
      ],
      rasterMicros: [
        for (final t in _timings) t.rasterDuration.inMicroseconds,
      ],
      totalMicros: [
        for (final t in _timings) t.totalSpan.inMicroseconds,
      ],
    );
  }
}

/// Writes a run to a file the human can pull off the device.
///
/// Plain JSON in the app's own documents directory. **Never a selfie and never
/// anything derived from one** — this file is meant to be copied off the
/// handset, and §4b's guarantee does not get an exception for diagnostics.
class ProfilingReportWriter {
  const ProfilingReportWriter(this.directory);

  /// Where to write. Passed in rather than resolved here so a test can point
  /// it at a sandbox and so nothing in `lib/` reaches for a plugin.
  final Directory directory;

  static String fileNameFor(DateTime at) =>
      'diakooi-profile-${at.toUtc().toIso8601String().replaceAll(':', '-')}'
      '.json';

  File write({
    required List<FrameReport> reports,
    required Map<String, dynamic> environment,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final payload = {
      'schema': 1,
      'recordedAt': when.toUtc().toIso8601String(),
      'frameTarget': FrameBudget.target.name,
      'budgetMs': FrameBudget.target.budgetMs,
      // Everything a reader needs to know whether the run counts. A trace with
      // no record of power mode or Extended RAM cannot be checked against the
      // §8c/§8d procedure afterwards, and an uncheckable trace is not evidence.
      'environment': environment,
      'reports': [for (final report in reports) report.toJson()],
    };

    directory.createSync(recursive: true);
    final file = File('${directory.path}/${fileNameFor(when)}')
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
    return file;
  }
}
