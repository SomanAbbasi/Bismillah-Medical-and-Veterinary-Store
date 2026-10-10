import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../../features/customers/data/customer_repository.dart';
import '../../features/suppliers/data/supplier_repository.dart';
import '../../features/dashboard/data/dashboard_provider.dart';

class ShopProfile {
  final String shopName;
  final String? ownerName;
  final String? phone;
  final String? address;
  final String? logoPath;

  ShopProfile({
    required this.shopName,
    this.ownerName,
    this.phone,
    this.address,
    this.logoPath,
  });
}

final shopProfileProvider = FutureProvider<ShopProfile>((ref) async {
  final db = ref.watch(databaseProvider);
  final shopName = await db.getSetting('shop_name') ?? 'Bismillah Medical & Veterinary Store';
  final ownerName = await db.getSetting('owner_name');
  final phone = await db.getSetting('phone');
  final address = await db.getSetting('store_address');
  final logoPath = await db.getSetting('shop_logo_path');

  return ShopProfile(
    shopName: shopName.trim().isNotEmpty ? shopName.trim() : 'Bismillah Medical & Veterinary Store',
    ownerName: ownerName,
    phone: phone,
    address: address,
    logoPath: logoPath,
  );
});

class PdfReportService {
  static final _pdfDateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final _shortDate = DateFormat('dd MMM yyyy');

  /// Build Header with Store Name, Owner info, phone, and optional Logo
  static pw.Widget _buildHeader({
    required ShopProfile shop,
    required String reportTitle,
    String? subtitle,
    pw.MemoryImage? logoImage,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.teal700, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo or Medical Cross Emblem
          pw.Container(
            width: 52,
            height: 52,
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.teal700, width: 1.5),
            ),
            child: logoImage != null
                ? pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                  )
                : pw.Center(
                    child: pw.Text(
                      '+',
                      style: pw.TextStyle(
                        fontSize: 34,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(width: 14),
          // Store Name & Contact Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  shop.shopName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.SizedBox(height: 2),
                if (shop.ownerName != null && shop.ownerName!.trim().isNotEmpty)
                  pw.Text(
                    'Proprietor: ${shop.ownerName!.trim()}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                if (shop.phone != null && shop.phone!.trim().isNotEmpty)
                  pw.Text(
                    'Phone / WhatsApp: ${shop.phone!.trim()}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                if (shop.address != null && shop.address!.trim().isNotEmpty)
                  pw.Text(
                    'Address: ${shop.address!.trim()}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
              ],
            ),
          ),
          // Report Title & Timestamp
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.teal700,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: ${_pdfDateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Footer with verification line and page numbering
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Bismillah Medical & Veterinary Store Management System • Computer Generated Statement',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Load custom shop logo if exists
  static Future<pw.MemoryImage?> _loadLogoImage(String? logoPath) async {
    if (logoPath == null || logoPath.isEmpty) return null;
    try {
      final file = File(logoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // 1. SALES & EXPENSES / FINANCIAL REPORT PDF
  // =========================================================================
  static Future<void> printFinancialReport({
    required ShopProfile shop,
    required String periodLabel,
    required DateTime startDate,
    required DateTime endDate,
    required int totalSalesPaisa,
    required int cashSalesPaisa,
    required int creditSalesPaisa,
    required int totalExpensesPaisa,
    required int netSalesPaisa,
    required List<Sale> sales,
    required List<Expense> expenses,
    bool includeSales = true,
    bool includeExpenses = true,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage(shop.logoPath);

    final title = (includeSales && includeExpenses)
        ? 'FINANCIAL & NET PROFIT REPORT'
        : includeSales
            ? 'SALES LEDGER REPORT'
            : 'STORE EXPENSES REPORT';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(
          shop: shop,
          reportTitle: title,
          subtitle: 'Period: $periodLabel',
          logoImage: logoImage,
        ),
        footer: _buildFooter,
        build: (context) {
          final isProfit = netSalesPaisa >= 0;

          return [
            pw.SizedBox(height: 10),

            // Top Financial Metrics Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _metricBox(
                    label: 'TOTAL SALES',
                    value: CurrencyFormatter.formatPaisa(totalSalesPaisa),
                    color: PdfColors.teal900,
                  ),
                  _metricBox(
                    label: 'TOTAL EXPENSES',
                    value: CurrencyFormatter.formatPaisa(totalExpensesPaisa),
                    color: PdfColors.orange800,
                  ),
                  _metricBox(
                    label: isProfit ? 'NET PROFIT' : 'NET LOSS',
                    value: CurrencyFormatter.formatPaisa(netSalesPaisa),
                    color: isProfit ? PdfColors.green800 : PdfColors.red800,
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            // Breakdown Summary Line
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Cash Collected: ${CurrencyFormatter.formatPaisa(cashSalesPaisa)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                  ),
                  pw.Text(
                    'Udhaar / Credit Sales: ${CurrencyFormatter.formatPaisa(creditSalesPaisa)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900),
                  ),
                  pw.Text(
                    'Total Transactions: ${sales.length} Sales • ${expenses.length} Expenses',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ],
              ),
            ),

            // Sales Table
            if (includeSales && sales.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Row(
                children: [
                  pw.Container(width: 3, height: 12, color: PdfColors.teal700),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    'ITEMIZED SALES LOG (${sales.length} records)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                headerHeight: 20,
                cellHeight: 18,
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                headers: ['Date & Time', 'Customer / Bill #', 'Method', 'Notes / Items', 'Amount'],
                data: sales.map((s) {
                  return [
                    _shortDate.format(s.createdAt),
                    s.customerId != null ? 'Customer #${s.customerId}' : 'Walk-in Customer',
                    s.paymentType.toUpperCase(),
                    s.notes?.isNotEmpty == true ? s.notes! : '-',
                    CurrencyFormatter.formatPaisa(s.finalAmountPaisa),
                  ];
                }).toList(),
              ),
            ],

            // Expenses Table
            if (includeExpenses && expenses.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Row(
                children: [
                  pw.Container(width: 3, height: 12, color: PdfColors.orange800),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    'STORE EXPENSES LOG (${expenses.length} records)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                headerHeight: 20,
                cellHeight: 18,
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
                headers: ['Date', 'Category', 'Description / Title', 'Amount'],
                data: expenses.map((e) {
                  return [
                    _shortDate.format(e.date),
                    e.category ?? 'General',
                    e.title + (e.note?.isNotEmpty == true ? ' • ${e.note}' : ''),
                    CurrencyFormatter.formatPaisa(e.amountPaisa),
                  ];
                }).toList(),
              ),
            ],

            pw.SizedBox(height: 20),

            // Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text('Prepared By', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text('Owner / Authorized Stamp', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final cleanFileName = 'Financial_Report_${_shortDate.format(startDate).replaceAll(' ', '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: cleanFileName,
    );
  }

  // =========================================================================
  // 2. CUSTOMER LEDGER STATEMENT PDF
  // =========================================================================
  static Future<void> printCustomerLedger({
    required ShopProfile shop,
    required Customer customer,
    required List<CustomerTransactionWithRunningBalance> history,
    required int currentBalancePaisa,
    String? periodLabel,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage(shop.logoPath);

    int totalCreditPaisa = 0;
    int totalPaidPaisa = 0;
    for (final h in history) {
      if (h.transaction.type == 'credit' || h.transaction.type == 'adjustment_debit') {
        totalCreditPaisa += h.transaction.amountPaisa;
      } else if (h.transaction.type == 'payment' || h.transaction.type == 'adjustment_credit') {
        totalPaidPaisa += h.transaction.amountPaisa;
      }
    }

    final owes = currentBalancePaisa > 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(
          shop: shop,
          reportTitle: 'CUSTOMER LEDGER STATEMENT',
          subtitle: periodLabel ?? 'Complete Account History',
          logoImage: logoImage,
        ),
        footer: _buildFooter,
        build: (context) {
          return [
            pw.SizedBox(height: 10),

            // Customer Info Box & Current Balance Card
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Customer: ${customer.name}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 8.5)),
                        if (customer.address != null && customer.address!.isNotEmpty)
                          pw.Text('Address: ${customer.address}', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Statement Period: ${periodLabel ?? "All Records"}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: owes ? PdfColors.red50 : PdfColors.green50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: owes ? PdfColors.red700 : PdfColors.green700),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          owes ? 'NET OUTSTANDING BALANCE' : 'ACCOUNT CLEARED',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: owes ? PdfColors.red800 : PdfColors.green800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          CurrencyFormatter.formatPaisa(currentBalancePaisa),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: owes ? PdfColors.red800 : PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            // Summary Totals
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Credit Taken (Udhaar): ${CurrencyFormatter.formatPaisa(totalCreditPaisa)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                  ),
                  pw.Text(
                    'Total Paid / Cleared: ${CurrencyFormatter.formatPaisa(totalPaidPaisa)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  ),
                  pw.Text(
                    'Entries: ${history.length}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Ledger Transaction Table
            pw.TableHelper.fromTextArray(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              headerHeight: 20,
              cellHeight: 18,
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              headers: ['Date', 'Type', 'Particulars / Notes', 'Debit (+)', 'Credit (-)', 'Balance'],
              data: history.map((item) {
                final t = item.transaction;
                final isDebit = t.type == 'credit' || t.type == 'adjustment_debit';
                final isCredit = t.type == 'payment' || t.type == 'adjustment_credit';

                String typeText = 'Credit';
                if (t.type == 'payment') typeText = 'Payment';
                if (t.type.contains('adjustment')) typeText = 'Adjustment';

                return [
                  _shortDate.format(t.date),
                  typeText,
                  t.note?.isNotEmpty == true ? t.note! : '-',
                  isDebit ? CurrencyFormatter.formatPaisa(t.amountPaisa) : '-',
                  isCredit ? CurrencyFormatter.formatPaisa(t.amountPaisa) : '-',
                  CurrencyFormatter.formatPaisa(item.runningBalancePaisa),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 20),

            // Note & Verification Section
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'Notice: Please review all transactions. If there is any discrepancy, please contact us within 3 days. Thank you for your continued trust.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ),

            pw.SizedBox(height: 24),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text('Store Stamp / Signature', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final cleanFileName = 'Customer_Statement_${customer.name.replaceAll(' ', '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: cleanFileName,
    );
  }

  // =========================================================================
  // 3. SUPPLIER LEDGER STATEMENT PDF
  // =========================================================================
  static Future<void> printSupplierLedger({
    required ShopProfile shop,
    required Supplier supplier,
    required List<SupplierTransactionWithRunningBalance> history,
    required int currentBalancePaisa,
    String? periodLabel,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage(shop.logoPath);

    int totalPurchasedPaisa = 0;
    int totalPaidPaisa = 0;
    for (final h in history) {
      if (h.transaction.type == 'payable' || h.transaction.type == 'adjustment_debit') {
        totalPurchasedPaisa += h.transaction.amountPaisa;
      } else if (h.transaction.type == 'payment' || h.transaction.type == 'adjustment_credit') {
        totalPaidPaisa += h.transaction.amountPaisa;
      }
    }

    final owes = currentBalancePaisa > 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(
          shop: shop,
          reportTitle: 'SUPPLIER LEDGER STATEMENT',
          subtitle: periodLabel ?? 'Complete Account History',
          logoImage: logoImage,
        ),
        footer: _buildFooter,
        build: (context) {
          return [
            pw.SizedBox(height: 10),

            // Supplier Info & Current Payable Card
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Supplier: ${supplier.name}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                        ),
                        if (supplier.company != null && supplier.company!.isNotEmpty)
                          pw.Text('Company / Distributor: ${supplier.company}', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('Phone: ${supplier.phone}', style: const pw.TextStyle(fontSize: 8.5)),
                        if (supplier.address != null && supplier.address!.isNotEmpty)
                          pw.Text('Address: ${supplier.address}', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: owes ? PdfColors.orange50 : PdfColors.green50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: owes ? PdfColors.orange800 : PdfColors.green700),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          owes ? 'TOTAL PAYABLE TO SUPPLIER' : 'ACCOUNT FULLY SETTLED',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: owes ? PdfColors.orange900 : PdfColors.green800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          CurrencyFormatter.formatPaisa(currentBalancePaisa),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: owes ? PdfColors.orange900 : PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            // Summary Totals
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Bills / Invoices: ${CurrencyFormatter.formatPaisa(totalPurchasedPaisa)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900),
                  ),
                  pw.Text(
                    'Total Payments Made: ${CurrencyFormatter.formatPaisa(totalPaidPaisa)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  ),
                  pw.Text(
                    'Transactions: ${history.length}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Ledger Transaction Table
            pw.TableHelper.fromTextArray(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              headerHeight: 20,
              cellHeight: 18,
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              headers: ['Date', 'Type', 'Invoice # / Particulars', 'Bill Amount', 'Paid Amount', 'Balance'],
              data: history.map((item) {
                final t = item.transaction;
                final isBill = t.type == 'payable' || t.type == 'adjustment_debit';
                final isPayment = t.type == 'payment' || t.type == 'adjustment_credit';

                String typeText = 'Purchase Bill';
                if (t.type == 'payment') typeText = 'Paid Bill';
                if (t.type.contains('adjustment')) typeText = 'Adjustment';

                return [
                  _shortDate.format(t.date),
                  typeText,
                  (t.reference?.isNotEmpty == true ? 'Ref: ${t.reference} ' : '') +
                      (t.note?.isNotEmpty == true ? t.note! : '-'),
                  isBill ? CurrencyFormatter.formatPaisa(t.amountPaisa) : '-',
                  isPayment ? CurrencyFormatter.formatPaisa(t.amountPaisa) : '-',
                  CurrencyFormatter.formatPaisa(item.runningBalancePaisa),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 24),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text('Distributor Representative', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    pw.Text('Store Authorized Stamp', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final cleanFileName = 'Supplier_Statement_${supplier.name.replaceAll(' ', '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: cleanFileName,
    );
  }

  // =========================================================================
  // 4. EXECUTIVE DASHBOARD DAILY SNAPSHOT PDF
  // =========================================================================
  static Future<void> printExecutiveSummary({
    required ShopProfile shop,
    required DashboardSummary summary,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage(shop.logoPath);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final isProfit = summary.todayNetPaisa >= 0;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                shop: shop,
                reportTitle: "DAILY EXECUTIVE SUMMARY",
                subtitle: _shortDate.format(DateTime.now()),
                logoImage: logoImage,
              ),

              pw.SizedBox(height: 12),

              // Overview Cards
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _metricBox(
                          label: "TODAY'S SALES",
                          value: CurrencyFormatter.formatPaisa(summary.todaySalesPaisa),
                          color: PdfColors.teal900,
                        ),
                        _metricBox(
                          label: "TODAY'S EXPENSES",
                          value: CurrencyFormatter.formatPaisa(summary.todayExpensesPaisa),
                          color: PdfColors.orange800,
                        ),
                        _metricBox(
                          label: isProfit ? "TODAY'S NET PROFIT" : "TODAY'S LOSS",
                          value: CurrencyFormatter.formatPaisa(summary.todayNetPaisa),
                          color: isProfit ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ],
                    ),
                    pw.Divider(color: PdfColors.grey300, height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _metricBox(
                          label: "CUSTOMER UDHAAR (RECEIVABLES)",
                          value: CurrencyFormatter.formatPaisa(summary.customerOutstandingPaisa),
                          color: PdfColors.red800,
                        ),
                        _metricBox(
                          label: "SUPPLIER DEBT (PAYABLES)",
                          value: CurrencyFormatter.formatPaisa(summary.supplierOutstandingPaisa),
                          color: PdfColors.orange900,
                        ),
                        _metricBox(
                          label: "EXPIRY ALERTS",
                          value: '${summary.expiredMedicinesCount + summary.expiringSoonMedicinesCount} items',
                          color: (summary.expiredMedicinesCount + summary.expiringSoonMedicinesCount) > 0
                              ? PdfColors.red800
                              : PdfColors.green800,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Top Overdue Customers
              if (summary.topOverdueCustomers.isNotEmpty) ...[
                pw.Row(
                  children: [
                    pw.Container(width: 3, height: 12, color: PdfColors.red700),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      'TOP CUSTOMERS WITH OUTSTANDING UDHAAR',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
                  headerHeight: 18,
                  cellHeight: 16,
                  headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  cellStyle: const pw.TextStyle(fontSize: 7.5),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                  },
                  headers: ['Customer Name', 'Phone Number', 'Outstanding Balance'],
                  data: summary.topOverdueCustomers.take(5).map((c) {
                    return [
                      c.customer.name,
                      c.customer.phone,
                      CurrencyFormatter.formatPaisa(c.balancePaisa),
                    ];
                  }).toList(),
                ),
              ],

              pw.SizedBox(height: 14),

              // Near Expiry Medicines
              if (summary.topExpiringMedicines.isNotEmpty) ...[
                pw.Row(
                  children: [
                    pw.Container(width: 3, height: 12, color: PdfColors.orange700),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      'CRITICAL & NEAR-EXPIRY MEDICINES ALERT',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                  headerHeight: 18,
                  cellHeight: 16,
                  headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  cellStyle: const pw.TextStyle(fontSize: 7.5),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerRight,
                  },
                  headers: ['Medicine Name', 'Batch #', 'Expiry Date', 'Status'],
                  data: summary.topExpiringMedicines.take(5).map((m) {
                    final isExpired = m.expiryDate.isBefore(DateFormatter.today());
                    return [
                      m.name,
                      m.batchNumber,
                      _shortDate.format(m.expiryDate),
                      isExpired ? 'EXPIRED' : 'Expiring Soon',
                    ];
                  }).toList(),
                ),
              ],

              pw.Spacer(),

              _buildFooter(context),
            ],
          );
        },
      ),
    );

    final cleanFileName = 'Daily_Snapshot_${_shortDate.format(DateTime.now()).replaceAll(' ', '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: cleanFileName,
    );
  }

  static pw.Widget _metricBox({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
