import 'package:flutter/material.dart';

class SupplierAccountScreen extends StatelessWidget {
  final int supplierId;
  const SupplierAccountScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Account')),
      body: const Center(child: Text('Supplier accounts are disabled in simplified settings.')),
    );
  }
}
