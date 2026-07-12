import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/safe_alert_button.dart';
import '../domain/local_report.dart';

class ReportConfirmationScreen extends StatelessWidget {
  const ReportConfirmationScreen({
    super.key,
    required this.report,
  });

  final LocalReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTheme.green,
                  size: 52,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Report saved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your report is stored locally and queued for upload. It will sync automatically when a connection is available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 18),
              Text(
                report.id,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              SafeAlertButton(
                label: 'BACK TO HOME',
                icon: Icons.home_outlined,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
