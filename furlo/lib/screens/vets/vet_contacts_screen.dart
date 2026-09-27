import 'package:flutter/material.dart';

class VetContactsScreen extends StatelessWidget {
  const VetContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Vet Contacts'),
      ),
      body: const Center(child: Text('Vet contacts screen')),
    );
  }
}
