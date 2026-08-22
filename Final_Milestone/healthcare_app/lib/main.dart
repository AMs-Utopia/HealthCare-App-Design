import 'package:flutter/material.dart';

import 'screens/sign_in_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const HealthCareApp());
}
class HealthCareApp extends StatelessWidget {
  const HealthCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.logoGreen),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const SignInScreen(),
    );
  }
}