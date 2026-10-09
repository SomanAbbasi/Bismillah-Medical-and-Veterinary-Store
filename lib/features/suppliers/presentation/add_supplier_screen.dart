import 'package:flutter/material.dart';

class AddSupplierScreen extends StatelessWidget {
  const AddSupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Supplier')),
      body: const Center(
        child: Text('Supplier management is disabled in simplified settings.'),
      ),
    );
  }
}
