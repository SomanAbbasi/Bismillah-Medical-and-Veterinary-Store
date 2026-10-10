import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

class ReceiptShareHelper {
  /// Normalizes Pakistani and international mobile phone numbers.
  /// Converts 03xx, 3xx, +923xx, 00923xx to international digits (923001234567).
  static String? normalizePhoneNumber(String? rawPhone) {
    if (rawPhone == null) return null;
    String clean = rawPhone.trim().replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (clean.isEmpty) return null;

    if (clean.startsWith('+')) {
      clean = clean.substring(1);
    } else if (clean.startsWith('00')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0') && clean.length == 11) {
      clean = '92${clean.substring(1)}';
    } else if (clean.startsWith('3') && clean.length == 10) {
      clean = '92$clean';
    }

    final digitsOnly = clean.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length >= 8 ? digitsOnly : null;
  }

  /// Builds a clean, professional customer transaction receipt
  static String buildCustomerReceipt({
    required String storeName,
    required String customerName,
    required String type, // 'credit' or 'payment'
    required int amountPaisa,
    required DateTime date,
    int? previousBalancePaisa,
    int? newBalancePaisa,
    String? reference,
    String? paymentMethod,
    String? note,
  }) {
    final isCredit = type == 'credit';
    final typeLabel = isCredit ? 'Credit Sale (Medicine Taken)' : 'Payment Received';
    final amountFormatted = CurrencyFormatter.formatPaisa(amountPaisa);

    final sb = StringBuffer();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('*${storeName.toUpperCase()}*');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('*${isCredit ? 'CREDIT SALE RECEIPT' : 'PAYMENT RECEIPT'}*');
    sb.writeln('');
    sb.writeln('👤 *Customer:* $customerName');
    sb.writeln('📋 *Type:* $typeLabel');
    sb.writeln('💰 *Amount:* $amountFormatted');
    sb.writeln('📅 *Date:* ${DateFormatter.formatDate(date)}');

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      sb.writeln('💳 *Method:* $paymentMethod');
    }
    if (reference != null && reference.isNotEmpty) {
      sb.writeln('🔖 *Ref / Slip #:* $reference');
    }
    if (note != null && note.isNotEmpty) {
      sb.writeln('📝 *Remarks:* $note');
    }

    if (previousBalancePaisa != null || newBalancePaisa != null) {
      sb.writeln('');
      sb.writeln('───────────────────────');
      sb.writeln('📊 *Account Balance Summary:*');
      if (previousBalancePaisa != null) {
        sb.writeln('• Previous Balance: ${CurrencyFormatter.formatPaisa(previousBalancePaisa)}');
      }
      if (newBalancePaisa != null) {
        sb.writeln('• *Current Net Balance: ${CurrencyFormatter.formatPaisa(newBalancePaisa)}*');
      }
      sb.writeln('───────────────────────');
    }

    sb.writeln('');
    sb.writeln('_Thank you for your business!_');
    sb.writeln('_${storeName}_');
    return sb.toString();
  }

  /// Builds a clean, professional supplier transaction receipt
  static String buildSupplierReceipt({
    required String storeName,
    required String supplierName,
    required String type, // 'payable' or 'payment'
    required int amountPaisa,
    required DateTime date,
    int? previousBalancePaisa,
    int? newBalancePaisa,
    String? reference,
    String? paymentMethod,
    String? note,
  }) {
    final isBill = type == 'payable';
    final typeLabel = isBill ? 'Medicine Supply Bill' : 'Payment to Supplier';
    final amountFormatted = CurrencyFormatter.formatPaisa(amountPaisa);

    final sb = StringBuffer();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('*${storeName.toUpperCase()}*');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('*${isBill ? 'SUPPLIER BILL RECORD' : 'SUPPLIER PAYMENT VOUCHER'}*');
    sb.writeln('');
    sb.writeln('🏢 *Supplier:* $supplierName');
    sb.writeln('📋 *Type:* $typeLabel');
    sb.writeln('💰 *Amount:* $amountFormatted');
    sb.writeln('📅 *Date:* ${DateFormatter.formatDate(date)}');

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      sb.writeln('💳 *Payment Method:* $paymentMethod');
    }
    if (reference != null && reference.isNotEmpty) {
      sb.writeln('🔖 *Invoice / Ref #:* $reference');
    }
    if (note != null && note.isNotEmpty) {
      sb.writeln('📝 *Notes:* $note');
    }

    if (previousBalancePaisa != null || newBalancePaisa != null) {
      sb.writeln('');
      sb.writeln('───────────────────────');
      sb.writeln('📊 *Payable Balance Summary:*');
      if (previousBalancePaisa != null) {
        sb.writeln('• Previous Payable: ${CurrencyFormatter.formatPaisa(previousBalancePaisa)}');
      }
      if (newBalancePaisa != null) {
        sb.writeln('• *Current Net Payable: ${CurrencyFormatter.formatPaisa(newBalancePaisa)}*');
      }
      sb.writeln('───────────────────────');
    }

    sb.writeln('');
    sb.writeln('_${storeName}_');
    return sb.toString();
  }

  /// Opens WhatsApp conversation with prefilled receipt text or falls back to system share
  static Future<bool> shareToWhatsApp({
    required String? rawPhone,
    required String message,
  }) async {
    final normalized = normalizePhoneNumber(rawPhone);

    if (normalized != null) {
      // 1. Try whatsapp deep link scheme
      final deepLink = Uri.parse('whatsapp://send?phone=$normalized&text=${Uri.encodeComponent(message)}');
      try {
        if (await canLaunchUrl(deepLink)) {
          await launchUrl(deepLink, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}

      // 2. Try universal wa.me link
      final universalLink = Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent(message)}');
      try {
        if (await canLaunchUrl(universalLink)) {
          await launchUrl(universalLink, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }

    // 3. Fallback to system share sheet if WhatsApp cannot be opened directly
    await shareViaSystem(message);
    return false;
  }

  /// Opens Android native share sheet
  static Future<void> shareViaSystem(String message) async {
    await Share.share(message);
  }

  /// Shows the user-confirmed bottom sheet for sharing a transaction receipt
  static Future<void> showReceiptShareSheet({
    required BuildContext context,
    required String personName,
    required String? phone,
    required String formattedAmount,
    required String typeLabel,
    required String receiptText,
    VoidCallback? onDismissed,
  }) async {
    final hasPhone = normalizePhoneNumber(phone) != null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: AppRadii.roundedMd,
                    ),
                    child: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transaction Recorded', style: AppTypography.heading3),
                        Text('$typeLabel • $formattedAmount', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Preview card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadii.roundedMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receipt Preview for $personName:', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${receiptText.split('\n').take(6).join('\n')}\n...',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              if (hasPhone) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
                  ),
                  icon: const Icon(Icons.send),
                  label: Text('Send on WhatsApp ($phone)'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await shareToWhatsApp(rawPhone: phone, message: receiptText);
                    onDismissed?.call();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
                ),
                icon: const Icon(Icons.share),
                label: const Text('Share via Other Apps'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await shareViaSystem(receiptText);
                  onDismissed?.call();
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Done'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onDismissed?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
