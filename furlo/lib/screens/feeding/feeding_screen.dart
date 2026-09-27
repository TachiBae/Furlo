import 'package:flutter/material.dart';

class FeedingScreen extends StatelessWidget {
  const FeedingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Feeding Schedule'),
      ),
      body: const Center(child: Text('Feeding schedule screen')),
    );
  }
}
