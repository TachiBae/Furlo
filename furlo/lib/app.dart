import 'package:flutter/material.dart';

import 'utils/app_theme.dart';

class FurloApp extends StatelessWidget {
  const FurloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Furlo',
      theme: FurloTheme.lightTheme,
      home: const PlaceholderScreen(),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Furlo app shell ready for feature screens')),
    );
  }
}
