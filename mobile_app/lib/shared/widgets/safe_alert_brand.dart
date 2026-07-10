import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SafeAlertBrand extends StatelessWidget {
  const SafeAlertBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 56.0 : 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRed.withValues(alpha: 0.22),
                blurRadius: compact ? 12 : 28,
                offset: Offset(0, compact ? 6 : 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/crime_app_logo.png',
            fit: BoxFit.cover,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 18),
          const Text(
            'Crime and Emergency Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}
