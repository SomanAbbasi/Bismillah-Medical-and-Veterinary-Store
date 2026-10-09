import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final DateFormat _monthYearFormat = DateFormat('MM/yyyy');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM yyyy');

  /// Formats DateTime to "DD/MM/YYYY"
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  /// Formats DateTime to "DD/MM/YYYY hh:mm a"
  static String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  /// Formats DateTime to "MM/YYYY" (useful for medicine expiry shorthand)
  static String formatMonthYear(DateTime? date) {
    if (date == null) return '-';
    return _monthYearFormat.format(date);
  }

  /// Formats DateTime to "15 Oct 2026"
  static String formatShortDate(DateTime? date) {
    if (date == null) return '-';
    return _shortDateFormat.format(date);
  }

  /// Normalizes a DateTime to local date-only midnight (00:00:00)
  /// Crucial for expiry and date calculations to avoid timezone shifts.
  static DateTime toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Returns today at midnight
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Parse a DD/MM/YYYY string safely
  static DateTime? tryParseDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }
}
