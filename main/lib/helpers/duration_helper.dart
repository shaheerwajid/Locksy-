class DurationHelper {
  static Duration? getDurationFromString(String duration) {
    switch (duration) {
      case '1 min':
        return const Duration(minutes: 1);
      case '5 min':
        return const Duration(minutes: 5);
      case '15 min':
        return const Duration(minutes: 15);
      case '12 hours':
        return const Duration(hours: 12);
      case '24 hours':
        return const Duration(hours: 24);
      case '48 hours':
        return const Duration(hours: 48);
      case '7 days':
        return const Duration(days: 7);
      case '14 days':
        return const Duration(days: 14);
      case '21 days':
        return const Duration(days: 21);
      default:
        return null;
    }
  }

  /// Returns the duration in seconds for TTL (used by backend)
  static int? getDurationInSeconds(String duration) {
    final d = getDurationFromString(duration);
    return d?.inSeconds;
  }
}
