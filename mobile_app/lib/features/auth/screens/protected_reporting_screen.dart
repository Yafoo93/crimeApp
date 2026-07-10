import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/safe_alert_button.dart';
import '../data/auth_service.dart';

class ProtectedReportingScreen extends StatefulWidget {
  const ProtectedReportingScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ProtectedReportingScreen> createState() =>
      _ProtectedReportingScreenState();
}

class _ProtectedReportingScreenState extends State<ProtectedReportingScreen> {
  bool _isLoading = false;

  Future<void> _continueProtected() async {
    setState(() => _isLoading = true);

    try {
      await widget.authService.continueProtectedReport();
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Could not continue protected report.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protected reporting')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF2A3550)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: AppTheme.primaryRed,
                    size: 34,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Report without creating a full account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Use this for sensitive incidents where you do not want to attach normal profile details. You can still add location, evidence, and a voice note later.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SafeAlertButton(
              label: 'CONTINUE PROTECTED',
              icon: Icons.shield_outlined,
              isLoading: _isLoading,
              onPressed: _continueProtected,
            ),
            const SizedBox(height: 14),
            SafeAlertButton(
              label: 'GO BACK',
              icon: Icons.arrow_back_rounded,
              secondary: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
