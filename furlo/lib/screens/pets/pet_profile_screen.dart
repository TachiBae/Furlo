import 'package:flutter/material.dart';

class PetProfileScreen extends StatelessWidget {
  const PetProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Pet Profile'),
      ),
      body: const Center(child: Text('Pet profile screen')),
    );
  }
}
