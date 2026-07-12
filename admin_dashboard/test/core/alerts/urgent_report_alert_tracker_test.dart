import 'package:admin_dashboard/core/alerts/urgent_report_alert_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('urgent alert tracker returns only new active urgent reports', () {
    final tracker = UrgentReportAlertTracker();

    final first = tracker.consumeNewUrgentReportIds(const [
      UrgentReportAlertCandidate(
        id: 'normal-1',
        urgency: 'normal',
        status: 'submitted',
      ),
      UrgentReportAlertCandidate(
        id: 'urgent-1',
        urgency: 'urgent',
        status: 'submitted',
      ),
      UrgentReportAlertCandidate(
        id: 'critical-closed',
        urgency: 'critical',
        status: 'resolved',
      ),
    ]);

    final second = tracker.consumeNewUrgentReportIds(const [
      UrgentReportAlertCandidate(
        id: 'urgent-1',
        urgency: 'urgent',
        status: 'submitted',
      ),
      UrgentReportAlertCandidate(
        id: 'critical-2',
        urgency: 'critical',
        status: 'investigating',
      ),
    ]);

    expect(first, ['urgent-1']);
    expect(second, ['critical-2']);
  });
}
