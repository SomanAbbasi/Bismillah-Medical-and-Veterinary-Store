import 'package:flutter/material.dart';

class AddSupplierPayableScreen extends StatelessWidget {
  final int? preselectedSupplierId;
  const AddSupplierPayableScreen({super.key, this.preselectedSupplierId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Supplier Payable')),
      body: const Center(child: Text('Supplier payables are disabled in simplified settings.')),
    );
  }
}
