import 'package:flutter_test/flutter_test.dart';
import 'package:arslan_medical_store/core/utils/expiry_utils.dart';

void main() {
  group('ExpiryUtils Tests', () {
    test('getStatus correctly identifies expired items', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final status = ExpiryUtils.getStatus(pastDate);
      expect(status, ExpiryStatus.expired);
    });

    test('getStatus correctly identifies critical items within 30 days', () {
      final soonDate = DateTime.now().add(const Duration(days: 15));
      final status = ExpiryUtils.getStatus(soonDate);
      expect(status, ExpiryStatus.critical1Month);
    });

    test('getStatus correctly identifies warning items within 3 months', () {
      final warningDate = DateTime.now().add(const Duration(days: 60));
      final status = ExpiryUtils.getStatus(warningDate);
      expect(status, ExpiryStatus.warning3Months);
    });

    test('getStatus correctly identifies healthy items beyond 6 months', () {
      final farDate = DateTime.now().add(const Duration(days: 365));
      final status = ExpiryUtils.getStatus(farDate);
      expect(status, ExpiryStatus.healthy);
    });

    test('getDaysRemaining returns negative for expired, positive for future', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      expect(ExpiryUtils.getDaysRemaining(pastDate) <= 0, true);

      final futureDate = DateTime.now().add(const Duration(days: 10));
      expect(ExpiryUtils.getDaysRemaining(futureDate) >= 9, true);
    });

    test('getHumanRemainingText returns human readable descriptions', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final pastText = ExpiryUtils.getHumanRemainingText(pastDate);
      expect(pastText.contains('Expired'), true);

      final futureDate = DateTime.now().add(const Duration(days: 20));
      final futureText = ExpiryUtils.getHumanRemainingText(futureDate);
      expect(futureText.contains('day'), true);
    });

    test('isInReminderWindow accurately checks custom reminder window', () {
      final inTwoMonths = DateTime.now().add(const Duration(days: 55));
      // With 3 months threshold, 55 days is within window
      expect(ExpiryUtils.isInReminderWindow(inTwoMonths, 3), true);
      // With 1 month threshold, 55 days is NOT yet within window
      expect(ExpiryUtils.isInReminderWindow(inTwoMonths, 1), false);
    });
  });
}
