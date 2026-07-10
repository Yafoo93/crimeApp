import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/safe_alert_button.dart';
import '../data/local_report_store.dart';
import '../domain/local_report.dart';
import 'report_confirmation_screen.dart';
import 'report_flow_widgets.dart';

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    required this.report,
  });

  final LocalReport report;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final updated = await LocalReportStore().markPendingUpload(widget.report);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ReportConfirmationScreen(report: updated),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final created = DateFormat.yMMMd()
        .add_jm()
        .format(widget.report.createdAt.toLocal());

    return ReportFlowScaffold(
      title: 'Preview report',
      subtitle: 'Review the saved local draft before marking it for upload.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewPanel(
            rows: [
              _PreviewRow('Report ID', widget.report.id),
              _PreviewRow('Category', widget.report.category),
              _PreviewRow('Urgency', widget.report.urgency?.label ?? 'Not set'),
              _PreviewRow('Status', widget.report.status.label),
              _PreviewRow('Created', created),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF222D44)),
            ),
            child: Text(
              widget.report.description ?? '',
              style: const TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          SafeAlertButton(
            label: 'CONFIRM REPORT',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.rows});

  final List<_PreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        row.label,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PreviewRow {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String value;
}

extension _ReportUrgencyLabel on ReportUrgency {
  String get label {
    switch (this) {
      case ReportUrgency.low:
        return 'Low';
      case ReportUrgency.medium:
        return 'Medium';
      case ReportUrgency.high:
        return 'High';
      case ReportUrgency.critical:
        return 'Critical';
    }
  }
}

extension _LocalReportStatusLabel on LocalReportStatus {
  String get label {
    switch (this) {
      case LocalReportStatus.draft:
        return 'Draft';
      case LocalReportStatus.pendingUpload:
        return 'Pending upload';
      case LocalReportStatus.uploading:
        return 'Uploading';
      case LocalReportStatus.submitted:
        return 'Submitted';
      case LocalReportStatus.failed:
        return 'Failed';
    }
  }
}
