import 'package:flutter/material.dart';

class RecordSupplierPaymentScreen extends StatelessWidget {
  final int? preselectedSupplierId;
  const RecordSupplierPaymentScreen({super.key, this.preselectedSupplierId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Supplier Payment')),
      body: const Center(child: Text('Supplier payments are disabled in simplified settings.')),
    );
  }
}
