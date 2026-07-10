import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/safe_alert_button.dart';
import '../data/local_report_store.dart';
import '../domain/local_report.dart';
import 'report_flow_widgets.dart';
import 'report_preview_screen.dart';

class IncidentDescriptionScreen extends StatefulWidget {
  const IncidentDescriptionScreen({
    super.key,
    required this.report,
  });

  final LocalReport report;

  @override
  State<IncidentDescriptionScreen> createState() =>
      _IncidentDescriptionScreenState();
}

class _IncidentDescriptionScreenState extends State<IncidentDescriptionScreen> {
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.report.description ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final description = _descriptionController.text.trim();
    if (description.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 20 characters describing the incident.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updated = await LocalReportStore().updateDescription(
      report: widget.report,
      description: description,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(report: updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReportFlowScaffold(
      title: 'Describe incident',
      subtitle:
          'Add what happened, who is involved, where it happened, and any safety risks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descriptionController,
            minLines: 8,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Example: Two people were seen forcing a shop door near the junction...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved locally first. Upload can continue later if connection drops.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          SafeAlertButton(
            label: 'PREVIEW REPORT',
            icon: Icons.article_outlined,
            isLoading: _isSaving,
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}
