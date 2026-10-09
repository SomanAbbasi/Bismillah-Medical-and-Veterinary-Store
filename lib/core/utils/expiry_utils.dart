import 'date_formatter.dart';

enum ExpiryStatus {
  expired,
  critical1Month,
  warning3Months,
  notice6Months,
  healthy,
}

class ExpiryUtils {
  /// Calculates the ExpiryStatus for a given expiry date relative to today
  static ExpiryStatus getStatus(DateTime expiryDate, {DateTime? referenceDate}) {
    final today = referenceDate ?? DateFormatter.today();
    final expiry = DateFormatter.toDateOnly(expiryDate);

    if (expiry.isBefore(today) || expiry.isAtSameMomentAs(today)) {
      return ExpiryStatus.expired;
    }

    final diffDays = expiry.difference(today).inDays;

    if (diffDays <= 30) {
      return ExpiryStatus.critical1Month;
    } else if (diffDays <= 90) {
      return ExpiryStatus.warning3Months;
    } else if (diffDays <= 180) {
      return ExpiryStatus.notice6Months;
    } else {
      return ExpiryStatus.healthy;
    }
  }

  /// Calculates the remaining days until expiry. Negative if already expired.
  static int getDaysRemaining(DateTime expiryDate, {DateTime? referenceDate}) {
    final today = referenceDate ?? DateFormatter.today();
    final expiry = DateFormatter.toDateOnly(expiryDate);
    return expiry.difference(today).inDays;
  }

  /// Calculates human readable remaining string
  /// Example: "Expired 5 days ago", "Expires in 12 days", "Expires in 2 months", "Expires in 1 yr 2 mos"
  static String getHumanRemainingText(DateTime expiryDate, {DateTime? referenceDate}) {
    final days = getDaysRemaining(expiryDate, referenceDate: referenceDate);
    if (days < 0) {
      final absDays = days.abs();
      if (absDays == 1) return 'Expired yesterday';
      if (absDays < 30) return 'Expired $absDays days ago';
      final months = absDays ~/ 30;
      return 'Expired $months month${months > 1 ? "s" : ""} ago';
    } else if (days == 0) {
      return 'Expires today';
    } else if (days == 1) {
      return 'Expires tomorrow';
    } else if (days < 30) {
      return 'Expires in $days days';
    } else if (days < 365) {
      final months = (days / 30.4).round();
      return 'Expires in $months month${months > 1 ? "s" : ""}';
    } else {
      final years = days ~/ 365;
      final remainingMonths = ((days % 365) / 30.4).round();
      if (remainingMonths == 0) {
        return 'Expires in $years yr${years > 1 ? "s" : ""}';
      }
      return 'Expires in $years yr $remainingMonths mo';
    }
  }

  /// Checks if a batch has entered its reminder window based on configured reminder months
  static bool isInReminderWindow(DateTime expiryDate, int reminderMonths, {DateTime? referenceDate}) {
    final today = referenceDate ?? DateFormatter.today();
    final expiry = DateFormatter.toDateOnly(expiryDate);

    // If already expired, handled separately by expired status
    if (expiry.isBefore(today)) return false;

    // Calculate reminder threshold date (expiry - reminderMonths)
    final thresholdDays = reminderMonths * 30;
    final diffDays = expiry.difference(today).inDays;

    return diffDays <= thresholdDays && diffDays > 0;
  }

  /// Label for ExpiryStatus
  static String getStatusLabel(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return 'Expired';
      case ExpiryStatus.critical1Month:
        return '< 1 Month';
      case ExpiryStatus.warning3Months:
        return '< 3 Months';
      case ExpiryStatus.notice6Months:
        return '< 6 Months';
      case ExpiryStatus.healthy:
        return 'Healthy';
    }
  }
}
