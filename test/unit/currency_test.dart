import 'package:flutter_test/flutter_test.dart';
import 'package:arslan_medical_store/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formatPaisa formats integer paisas to PKR correctly', () {
      expect(CurrencyFormatter.formatPaisa(0), 'Rs. 0');
      expect(CurrencyFormatter.formatPaisa(100), 'Rs. 1');
      expect(CurrencyFormatter.formatPaisa(150), 'Rs. 1.50');
      expect(CurrencyFormatter.formatPaisa(125000), 'Rs. 1,250');
      expect(CurrencyFormatter.formatPaisa(1000000), 'Rs. 10,000');
    });

    test('parseToPaisa parses string inputs into integer paisa safely', () {
      expect(CurrencyFormatter.parseToPaisa('0'), 0);
      expect(CurrencyFormatter.parseToPaisa('10'), 1000);
      expect(CurrencyFormatter.parseToPaisa('10.5'), 1050);
      expect(CurrencyFormatter.parseToPaisa('10.50'), 1050);
      expect(CurrencyFormatter.parseToPaisa('1,250.75'), 125075);
      expect(CurrencyFormatter.parseToPaisa('Rs. 500'), 50000);
      expect(CurrencyFormatter.parseToPaisa('invalid'), 0);
      expect(CurrencyFormatter.parseToPaisa(''), 0);
    });

    test('paisaToDouble converts integer paisa to double for charts', () {
      expect(CurrencyFormatter.paisaToDouble(25000), 250.0);
      expect(CurrencyFormatter.paisaToDouble(25050), 250.50);
    });

    test('paisaToInputString formats paisa for editing in text fields', () {
      expect(CurrencyFormatter.paisaToInputString(0), '');
      expect(CurrencyFormatter.paisaToInputString(50000), '500');
      expect(CurrencyFormatter.paisaToInputString(50025), '500.25');
    });
  });
}
