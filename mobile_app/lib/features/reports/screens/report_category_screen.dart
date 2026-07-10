import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/local_report_store.dart';
import 'report_flow_widgets.dart';
import 'report_urgency_screen.dart';

class ReportCategoryScreen extends StatelessWidget {
  const ReportCategoryScreen({
    super.key,
    required this.ownerId,
  });

  final String ownerId;

  Future<void> _selectCategory(BuildContext context, String category) async {
    final store = LocalReportStore();
    final report = await store.createDraft(
      ownerId: ownerId,
      category: category,
    );

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportUrgencyScreen(report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReportFlowScaffold(
      title: 'Report category',
      subtitle:
          'Choose the closest category. A local draft is created before anything is uploaded.',
      child: Column(
        children: [
          ReportOptionCard(
            title: 'Robbery',
            subtitle: 'Theft, armed robbery, burglary, or attempted robbery',
            icon: Icons.local_police_outlined,
            color: AppTheme.primaryRed,
            onTap: () => _selectCategory(context, 'Robbery'),
          ),
          ReportOptionCard(
            title: 'Assault',
            subtitle: 'Physical attack, threat, or violence in progress',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFFF851B),
            onTap: () => _selectCategory(context, 'Assault'),
          ),
          ReportOptionCard(
            title: 'Fire',
            subtitle: 'Fire outbreak, smoke, explosion, or fire hazard',
            icon: Icons.local_fire_department_outlined,
            color: AppTheme.amber,
            onTap: () => _selectCategory(context, 'Fire'),
          ),
          ReportOptionCard(
            title: 'Medical emergency',
            subtitle: 'Injury, collapse, urgent care, or ambulance support',
            icon: Icons.medical_services_outlined,
            color: AppTheme.green,
            onTap: () => _selectCategory(context, 'Medical emergency'),
          ),
          ReportOptionCard(
            title: 'Suspicious activity',
            subtitle: 'Unsafe activity, missing person, accident, or other',
            icon: Icons.visibility_outlined,
            color: AppTheme.cyan,
            onTap: () => _selectCategory(context, 'Suspicious activity'),
          ),
        ],
      ),
    );
  }
}
