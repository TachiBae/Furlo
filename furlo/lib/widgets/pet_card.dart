import 'package:flutter/material.dart';

class PetCard extends StatelessWidget {
  const PetCard({super.key, required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(name), subtitle: Text(subtitle)),
    );
  }
}
