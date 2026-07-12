import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/reports/data/report_sync_service.dart';
import 'package:mobile_app/features/reports/domain/local_report.dart';

void main() {
  LocalReport reportWithEvidence() {
    final now = DateTime.utc(2026, 7, 12);
    return LocalReport(
      id: 'report-123',
      ownerId: 'user-1',
      category: 'Suspicious Activity',
      status: LocalReportStatus.pendingUpload,
      createdAt: now,
      updatedAt: now,
      urgency: ReportUrgency.high,
      images: [
        LocalImageEvidence(
          path: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
          createdAt: now,
        ),
      ],
      voiceNote: LocalVoiceEvidence(
        path: '/tmp/voice.m4a',
        durationSeconds: 20,
        createdAt: now,
      ),
    );
  }

  test('builds deterministic report category and urgency values', () {
    expect(
      ReportSyncPayloadBuilder.categoryId(' Suspicious Activity! '),
      'suspicious_activity',
    );
    expect(
      ReportSyncPayloadBuilder.remoteUrgency(ReportUrgency.high),
      'urgent',
    );
    expect(
      ReportSyncPayloadBuilder.remoteUrgency(ReportUrgency.critical),
      'critical',
    );
    expect(
      ReportSyncPayloadBuilder.remoteUrgency(ReportUrgency.low),
      'normal',
    );
  });

  test('builds idempotent media ids and storage paths', () {
    final report = reportWithEvidence();
    final image = report.images.single;
    final imagePath = ReportSyncPayloadBuilder.imageStoragePath(
      report: report,
      index: 0,
      extension: ReportSyncPayloadBuilder.extensionFromMimeType(
        image.mimeType,
      ),
    );
    final firstPayload = ReportSyncPayloadBuilder.imageMediaPayload(
      report: report,
      index: 0,
      storagePath: imagePath,
      image: image,
    );
    final secondPayload = ReportSyncPayloadBuilder.imageMediaPayload(
      report: report,
      index: 0,
      storagePath: imagePath,
      image: image,
    );

    expect(imagePath, 'evidence/user-1/report-123/image_0.jpg');
    expect(firstPayload, secondPayload);
    expect(firstPayload['id'], 'report-123_image_0');
  });

  test('builds voice note upload metadata', () {
    final report = reportWithEvidence();
    final voice = report.voiceNote!;
    final storagePath = ReportSyncPayloadBuilder.voiceStoragePath(report);
    final payload = ReportSyncPayloadBuilder.voiceMediaPayload(
      report: report,
      storagePath: storagePath,
      voice: voice,
      sizeBytes: 4096,
    );

    expect(storagePath, 'evidence/user-1/report-123/voice.m4a');
    expect(payload['id'], 'report-123_voice');
    expect(payload['type'], 'voice');
    expect(payload['contentType'], 'audio/mp4');
    expect(payload['durationSeconds'], 20);
  });
}
