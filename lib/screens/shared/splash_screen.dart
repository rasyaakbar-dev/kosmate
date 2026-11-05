import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KosMateLogo(
              size: 110,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'KosMate',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

