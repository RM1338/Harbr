import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(HiveBoxes.settings);
  await Hive.openBox<dynamic>(HiveBoxes.reservationsCache);
  await Hive.openBox<dynamic>(HiveBoxes.authCache);
  await Hive.openBox<dynamic>(HiveBoxes.userProfile);

  runApp(
    const ProviderScope(
      child: HarbrApp(),
    ),
  );
}

class HarbrApp extends ConsumerWidget {
  const HarbrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Harbr',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
