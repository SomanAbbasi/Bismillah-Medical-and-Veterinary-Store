import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const String defaultCurrencySymbol = 'Rs.';

  /// Formats an integer amount in minor units (paisa) into a display string.
  /// Example: 15000 paisa -> "Rs. 150"
  /// Example: 15050 paisa -> "Rs. 150.50"
  /// Example: -25000 paisa -> "-Rs. 250"
  static String formatPaisa(int paisa, {String symbol = defaultCurrencySymbol, bool includeDecimalsIfZero = false}) {
    final bool isNegative = paisa < 0;
    final int absPaisa = paisa.abs();
    final int rupees = absPaisa ~/ 100;
    final int remainderPaisa = absPaisa % 100;

    final rupeeFormatter = NumberFormat('#,##0');
    final String formattedRupees = rupeeFormatter.format(rupees);

    String result;
    if (remainderPaisa > 0 || includeDecimalsIfZero) {
      final String paisaStr = remainderPaisa.toString().padLeft(2, '0');
      result = '$symbol $formattedRupees.$paisaStr';
    } else {
      result = '$symbol $formattedRupees';
    }

    return isNegative ? '-$result' : result;
  }

  /// Converts a user input text string (like "150", "150.50", "1250.75") into integer paisa.
  /// Avoids double float precision issues.
  static int parseToPaisa(String input) {
    String clean = input.trim();
    // Remove common prefixes like "Rs." or "Rs" or "PKR" or "$"
    clean = clean.replaceAll(RegExp(r'^(Rs\.?|PKR|\$)\s*', caseSensitive: false), '').trim();
    clean = clean.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    if (clean.isEmpty) return 0;

    final lastDotIndex = clean.lastIndexOf('.');
    if (lastDotIndex == -1) {
      final val = int.tryParse(clean) ?? 0;
      return val * 100;
    }

    final intPart = clean.substring(0, lastDotIndex).replaceAll('.', '');
    final rupees = int.tryParse(intPart) ?? 0;
    String paisaStr = clean.substring(lastDotIndex + 1);
    if (paisaStr.length > 2) {
      paisaStr = paisaStr.substring(0, 2);
    } else if (paisaStr.length == 1) {
      paisaStr = '${paisaStr}0';
    } else if (paisaStr.isEmpty) {
      paisaStr = '00';
    }

    final paisa = int.tryParse(paisaStr) ?? 0;
    return (rupees * 100) + paisa;
  }

  /// Converts paisa to double solely for chart plotting when fl_chart requires double
  static double paisaToDouble(int paisa) {
    return paisa / 100.0;
  }

  /// Converts paisa to clean text for editing inside text fields
  static String paisaToInputString(int paisa) {
    if (paisa == 0) return '';
    final int absPaisa = paisa.abs();
    final int rupees = absPaisa ~/ 100;
    final int remainderPaisa = absPaisa % 100;
    if (remainderPaisa == 0) {
      return (paisa < 0 ? '-' : '') + rupees.toString();
    }
    return '${paisa < 0 ? '-' : ''}$rupees.${remainderPaisa.toString().padLeft(2, '0')}';
  }
}
