import 'package:flutter/material.dart';

class WeightTrackingScreen extends StatelessWidget {
  const WeightTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Weight Tracking'),
      ),
      body: const Center(child: Text('Weight tracking screen')),
    );
  }
}
