import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/firebase/firebase_emulators.dart';
import 'core/theme/admin_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await connectFirebaseEmulators();

  runApp(const SafeAlertAdminApp());
}

class SafeAlertAdminApp extends StatelessWidget {
  const SafeAlertAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeAlert Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark(),
      home: const Scaffold(
        body: Center(
          child: Text('SafeAlert Admin Dashboard'),
        ),
      ),
    );
  }
}
