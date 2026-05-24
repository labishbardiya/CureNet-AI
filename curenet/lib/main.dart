import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/app_router.dart';
import 'core/data_mode.dart';
import 'services/db_crypto_service.dart';

import 'package:provider/provider.dart';
import 'core/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataMode.init();
  // Initialize AES-256-GCM encryption key for the encrypted ObjectBox DB.
  // Key is generated on first launch and stored in Android Keystore / iOS Keychain.
  await DbCryptoService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const CureNetApp(),
    ),
  );
}

class CureNetApp extends StatelessWidget {
  const CureNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CureNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
    );
  }
}
