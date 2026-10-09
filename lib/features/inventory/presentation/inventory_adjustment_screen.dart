import 'package:flutter/material.dart';

class InventoryAdjustmentScreen extends StatelessWidget {
  final int medicineId;
  final int? initialBatchId;

  const InventoryAdjustmentScreen({
    super.key,
    required this.medicineId,
    this.initialBatchId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Adjustment')),
      body: const Center(
        child: Text('Medicine stock is directly tracked per medicine.'),
      ),
    );
  }
}
