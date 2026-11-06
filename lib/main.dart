import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/shared/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabaseAnonKey,
  );

  runApp(const KosMateApp());
}

class KosMateApp extends StatelessWidget {
  const KosMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KosMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
