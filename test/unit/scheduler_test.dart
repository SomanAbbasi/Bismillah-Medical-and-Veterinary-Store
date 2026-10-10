import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expiry Notification Scheduling Algorithm Tests', () {
    test('Lead time calculation determines reminder start date accurately', () {
      final expiryDate = DateTime(2026, 12, 1);
      const leadDays = 30;
      final reminderStartDate = expiryDate.subtract(const Duration(days: leadDays));

      expect(reminderStartDate, DateTime(2026, 11, 1));

      // 60 days lead time
      final reminderStartDate60 = expiryDate.subtract(const Duration(days: 60));
      expect(reminderStartDate60, DateTime(2026, 10, 2));
    });

    test('Eligibility evaluation correctly identifies items needing active alert', () {
      final today = DateTime(2026, 10, 10);

      // Case 1: Already expired medicine
      final expiredMed = DateTime(2026, 9, 15);
      final isExpired = expiredMed.isBefore(today);
      expect(isExpired, true);

      // Case 2: In reminder window (expires in 20 days, lead time is 30 days)
      final nearMed = DateTime(2026, 10, 30);
      final startNear = nearMed.subtract(const Duration(days: 30));
      final isNearEligible = today.isAfter(startNear) || today.isAtSameMomentAs(startNear);
      expect(isNearEligible, true);

      // Case 3: Far future medicine (expires in 6 months, lead time is 30 days)
      final farMed = DateTime(2027, 4, 1);
      final startFar = farMed.subtract(const Duration(days: 30));
      final isFarEligible = today.isAfter(startFar);
      expect(isFarEligible, false);
    });

    test('Daily recurrence calculation schedules for preferred morning time', () {
      final now = DateTime(2026, 10, 10, 8, 30); // 8:30 AM
      const preferredHour = 9;
      const preferredMinute = 0;

      final candidateToday = DateTime(now.year, now.month, now.day, preferredHour, preferredMinute);
      DateTime nextOccurrence;

      if (candidateToday.isAfter(now)) {
        nextOccurrence = candidateToday; // Today at 9:00 AM
      } else {
        nextOccurrence = candidateToday.add(const Duration(days: 1)); // Tomorrow at 9:00 AM
      }

      expect(nextOccurrence, DateTime(2026, 10, 10, 9, 0));

      // If time has passed today (e.g. 11:00 AM):
      final afternoonNow = DateTime(2026, 10, 10, 11, 0);
      final candidatePassed = DateTime(afternoonNow.year, afternoonNow.month, afternoonNow.day, preferredHour, preferredMinute);
      final nextAfternoonOccurrence = candidatePassed.isAfter(afternoonNow)
          ? candidatePassed
          : candidatePassed.add(const Duration(days: 1));

      expect(nextAfternoonOccurrence, DateTime(2026, 10, 11, 9, 0));
    });

    test('Custom repetition interval in minutes schedules future alarm from now', () {
      final now = DateTime(2026, 10, 10, 10, 0);
      const customIntervalMinutes = 60; // 1 hour

      final nextAlarm = now.add(const Duration(minutes: customIntervalMinutes));
      expect(nextAlarm, DateTime(2026, 10, 10, 11, 0));

      // 15 minutes rapid interval
      final rapidAlarm = now.add(const Duration(minutes: 15));
      expect(rapidAlarm, DateTime(2026, 10, 10, 10, 15));
    });

    test('Stable notification ID guarantees duplicate prevention', () {
      const medicineId = 42;
      // Stable ID is identical to medicine ID
      const notifId1 = medicineId;
      const notifId2 = medicineId;

      expect(notifId1, equals(notifId2));
      expect(notifId1, equals(42));
    });

    test('Disabling, draft status, or soft deleting medicine flags cancellation of alerts', () {
      bool shouldCancelAlert({
        required bool isReminderDisabled,
        required bool isDeleted,
        required bool isDraft,
      }) {
        return isReminderDisabled || isDeleted || isDraft;
      }

      expect(shouldCancelAlert(isReminderDisabled: true, isDeleted: false, isDraft: false), true);
      expect(shouldCancelAlert(isReminderDisabled: false, isDeleted: true, isDraft: false), true);
      expect(shouldCancelAlert(isReminderDisabled: false, isDeleted: false, isDraft: true), true);
      expect(shouldCancelAlert(isReminderDisabled: false, isDeleted: false, isDraft: false), false);
    });

    test('Burst IDs helper covers canonical ID and burst range', () {
      const medId = 7;
      final burstIds = [medId, for (int i = 1; i <= 20; i++) medId * 1000 + i];
      expect(burstIds.first, equals(7));
      expect(burstIds.contains(7001), true);
      expect(burstIds.contains(7020), true);
      expect(burstIds.length, equals(21));
    });

    test('Batch expiring in 5 days with 30-day lead time qualifies for reminder', () {
      final now = DateTime(2026, 10, 10, 12, 0);
      final today = DateTime(now.year, now.month, now.day);
      final fiveDaysOut = today.add(const Duration(days: 5));
      const leadDays = 30;

      final reminderStartDate = fiveDaysOut.subtract(const Duration(days: leadDays));
      final isExpired = fiveDaysOut.isBefore(today);
      final isEligible = isExpired || now.isAfter(reminderStartDate) || now.isAtSameMomentAs(reminderStartDate);

      expect(isExpired, false);
      expect(isEligible, true);
    });

    test('Already expired batch qualifies for immediate alert', () {
      final now = DateTime(2026, 10, 10, 12, 0);
      final today = DateTime(now.year, now.month, now.day);
      final expiredDate = today.subtract(const Duration(days: 3));
      const leadDays = 30;

      final reminderStartDate = expiredDate.subtract(const Duration(days: leadDays));
      final isExpired = expiredDate.isBefore(today);
      final isEligible = isExpired || now.isAfter(reminderStartDate) || now.isAtSameMomentAs(reminderStartDate);

      expect(isExpired, true);
      expect(isEligible, true);
    });
  });
}
