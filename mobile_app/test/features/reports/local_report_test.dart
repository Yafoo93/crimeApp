import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/reports/domain/local_report.dart';

void main() {
  test('local report serializes and restores report details', () {
    final now = DateTime.utc(2026, 7, 12, 10, 30);
    final report = LocalReport(
      id: 'report-1',
      ownerId: 'user-1',
      category: 'Robbery',
      status: LocalReportStatus.pendingUpload,
      createdAt: now,
      updatedAt: now,
      urgency: ReportUrgency.critical,
      description: 'Armed robbery near the bank.',
      location: const LocalReportLocation(
        latitude: 5.6037,
        longitude: -0.1870,
        accuracyMeters: 12,
        ghanaPostGps: 'GA-123-4567',
      ),
      images: [
        LocalImageEvidence(
          path: '/tmp/evidence.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 2048,
          createdAt: now,
        ),
      ],
      voiceNote: LocalVoiceEvidence(
        path: '/tmp/voice.m4a',
        durationSeconds: 30,
        createdAt: now,
      ),
      syncAttempts: 2,
      lastSyncError: 'network failed',
      lastSyncAttemptAt: now,
    );

    final restored = LocalReport.fromMap(report.toMap());

    expect(restored.id, report.id);
    expect(restored.ownerId, report.ownerId);
    expect(restored.status, LocalReportStatus.pendingUpload);
    expect(restored.urgency, ReportUrgency.critical);
    expect(restored.location.latitude, 5.6037);
    expect(restored.images.single.mimeType, 'image/jpeg');
    expect(restored.voiceNote?.durationSeconds, 30);
    expect(restored.syncAttempts, 2);
    expect(restored.lastSyncError, 'network failed');
  });

  test('location is empty only when GPS and GhanaPostGPS are absent', () {
    expect(const LocalReportLocation().isEmpty, isTrue);
    expect(
      const LocalReportLocation(latitude: 5.6, longitude: -0.1).isEmpty,
      isFalse,
    );
    expect(
      const LocalReportLocation(ghanaPostGps: 'GA-123-4567').isEmpty,
      isFalse,
    );
  });
}
