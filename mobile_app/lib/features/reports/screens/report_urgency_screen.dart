import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/local_report_store.dart';
import '../domain/local_report.dart';
import 'incident_description_screen.dart';
import 'report_flow_widgets.dart';

class ReportUrgencyScreen extends StatelessWidget {
  const ReportUrgencyScreen({
    super.key,
    required this.report,
  });

  final LocalReport report;

  Future<void> _selectUrgency(
    BuildContext context,
    ReportUrgency urgency,
  ) async {
    final updated = await LocalReportStore().updateUrgency(
      report: report,
      urgency: urgency,
    );

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IncidentDescriptionScreen(report: updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReportFlowScaffold(
      title: 'Urgency level',
      subtitle:
          'This helps responders prioritize review. If anyone is in immediate danger, call 112 first.',
      child: Column(
        children: [
          ReportOptionCard(
            title: 'Critical',
            subtitle: 'Immediate danger, active violence, fire, or severe injury',
            icon: Icons.priority_high_rounded,
            color: AppTheme.primaryRed,
            onTap: () => _selectUrgency(context, ReportUrgency.critical),
          ),
          ReportOptionCard(
            title: 'High',
            subtitle: 'Needs fast attention but immediate dispatch is not active',
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFFF851B),
            onTap: () => _selectUrgency(context, ReportUrgency.high),
          ),
          ReportOptionCard(
            title: 'Medium',
            subtitle: 'Important report with enough time to add details',
            icon: Icons.error_outline_rounded,
            color: AppTheme.amber,
            onTap: () => _selectUrgency(context, ReportUrgency.medium),
          ),
          ReportOptionCard(
            title: 'Low',
            subtitle: 'Information, suspicious activity, or non-urgent follow-up',
            icon: Icons.info_outline_rounded,
            color: AppTheme.cyan,
            onTap: () => _selectUrgency(context, ReportUrgency.low),
          ),
        ],
      ),
    );
  }
}
