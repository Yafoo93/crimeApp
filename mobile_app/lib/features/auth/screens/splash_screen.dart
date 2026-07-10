import 'package:flutter/material.dart';

import '../../../shared/widgets/safe_alert_brand.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeAlertBrand(),
            SizedBox(height: 32),
            CircularProgressIndicator(color: AppTheme.primaryRed),
          ],
        ),
      ),
    );
  }
}
