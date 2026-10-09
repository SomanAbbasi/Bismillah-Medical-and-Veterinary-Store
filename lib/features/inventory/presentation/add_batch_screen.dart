import 'package:flutter/material.dart';

class AddBatchScreen extends StatelessWidget {
  final int medicineId;
  const AddBatchScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expiry Date')),
      body: const Center(
        child: Text('Please set expiry date directly when adding or editing medicine.'),
      ),
    );
  }
}
