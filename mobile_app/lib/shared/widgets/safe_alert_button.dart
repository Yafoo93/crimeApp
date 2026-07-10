import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SafeAlertButton extends StatelessWidget {
  const SafeAlertButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final foreground = secondary ? AppTheme.textPrimary : AppTheme.textPrimary;
    final background = secondary ? AppTheme.surfaceAlt : AppTheme.primaryRed;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: secondary ? const Color(0xFF2A3550) : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
