import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/app_router.dart';
import 'core/data_mode.dart';
import 'services/db_crypto_service.dart';
import 'services/access_request_monitor.dart';

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

/// Global navigator key — used by AccessRequestMonitor to show dialogs
/// on any screen without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CureNetApp extends StatefulWidget {
  const CureNetApp({super.key});

  @override
  State<CureNetApp> createState() => _CureNetAppState();
}

class _CureNetAppState extends State<CureNetApp> {
  @override
  void initState() {
    super.initState();
    // Start global access request monitoring after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessRequestMonitor.instance.init(navigatorKey);
    });
  }

  @override
  void dispose() {
    AccessRequestMonitor.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CureNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
    );
  }
}
