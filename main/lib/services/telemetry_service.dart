import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Lightweight telemetry helper to keep recent high-signal events in memory.
class TelemetryService {
  static const int _maxEntries = 200;
  static final List<String> _entries = <String>[];

  static void log(String event, {Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = jsonEncode({
      'ts': timestamp,
      'event': event,
      if (data != null) 'data': data,
    });
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    debugPrint('[Telemetry] $entry');
  }

  static List<String> dump() => List.unmodifiable(_entries);
}

