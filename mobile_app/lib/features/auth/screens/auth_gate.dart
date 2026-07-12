import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../../home/screens/home_screen.dart';
import '../../reports/data/report_sync_service.dart';
import 'auth_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ReportSyncService _reportSyncService;
  String? _activeSyncUserId;

  @override
  void initState() {
    super.initState();
    _reportSyncService = ReportSyncService();
  }

  @override
  void dispose() {
    unawaited(_reportSyncService.dispose());
    super.dispose();
  }

  void _startSyncForUser(String userId) {
    if (_activeSyncUserId == userId) return;
    _activeSyncUserId = userId;
    unawaited(_reportSyncService.start());
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;
        if (user != null) {
          _startSyncForUser(user.uid);
          return HomeScreen(authService: authService, user: user);
        }

        _activeSyncUserId = null;
        return AuthScreen(authService: authService);
      },
    );
  }
}
