class UrgentReportAlertCandidate {
  const UrgentReportAlertCandidate({
    required this.id,
    required this.urgency,
    required this.status,
  });

  final String id;
  final String urgency;
  final String status;

  bool get needsAlert {
    final urgent = urgency == 'urgent' || urgency == 'critical';
    final closed = status == 'resolved' || status == 'closed';
    return urgent && !closed;
  }
}

class UrgentReportAlertTracker {
  final Set<String> _alertedReportIds = <String>{};

  List<String> consumeNewUrgentReportIds(
    Iterable<UrgentReportAlertCandidate> reports,
  ) {
    final ids = reports
        .where((report) => report.needsAlert)
        .map((report) => report.id)
        .where((id) => !_alertedReportIds.contains(id))
        .toList();

    _alertedReportIds.addAll(ids);
    return ids;
  }
}
