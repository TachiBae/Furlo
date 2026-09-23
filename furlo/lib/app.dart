import 'package:flutter/material.dart';

import 'screens/pets/pet_onboarding_screen.dart';
import 'utils/app_theme.dart';

class FurloApp extends StatelessWidget {
  const FurloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Furlo',
      theme: AppTheme.dark,
      home: const OnboardingScreen(),
    );
  }
}
