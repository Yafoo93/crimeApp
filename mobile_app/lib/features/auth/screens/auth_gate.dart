import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'auth_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
          return HomeScreen(authService: authService, user: user);
        }

        return AuthScreen(authService: authService);
      },
    );
  }
}
