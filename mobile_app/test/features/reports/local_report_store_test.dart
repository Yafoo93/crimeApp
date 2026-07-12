import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_app/features/reports/data/local_report_store.dart';
import 'package:mobile_app/features/reports/domain/local_report.dart';

void main() {
  late Directory tempDir;
  late LocalReportStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crimeapp_reports_test_');
    Hive.init(tempDir.path);
    await LocalReportStore.initialize();
    store = LocalReportStore();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('offline report creation writes draft locally first', () async {
    final report = await store.createDraft(
      ownerId: 'user-1',
      category: 'Robbery',
    );

    final reports = store.reportsForOwner('user-1');

    expect(reports, hasLength(1));
    expect(reports.single.id, report.id);
    expect(reports.single.status, LocalReportStatus.draft);
    expect(store.find(report.id), isNotNull);
  });

  test('failed upload is kept in retry queue and retry increments attempts',
      () async {
    final draft = await store.createDraft(
      ownerId: 'user-1',
      category: 'Fire',
    );
    final pending = await store.markPendingUpload(draft);
    final failed = await store.markSyncFailed(
      report: pending,
      error: 'upload failed',
    );

    expect(store.pendingSyncReports('user-1').single.id, failed.id);
    expect(failed.status, LocalReportStatus.failed);
    expect(failed.lastSyncError, 'upload failed');

    final uploading = await store.markUploading(failed);

    expect(uploading.status, LocalReportStatus.uploading);
    expect(uploading.syncAttempts, 1);
    expect(uploading.lastSyncError, isNull);
  });

  test('voice note evidence is saved and can be replaced or cleared', () async {
    final draft = await store.createDraft(
      ownerId: 'user-1',
      category: 'Medical',
    );
    final voice = LocalVoiceEvidence(
      path: '${tempDir.path}/voice.m4a',
      durationSeconds: 45,
      createdAt: DateTime.now().toUtc(),
    );

    final withVoice = await store.saveVoiceEvidence(
      report: draft,
      voiceNote: voice,
    );
    final restored = store.find(withVoice.id);

    expect(restored?.voiceNote?.path, voice.path);
    expect(restored?.voiceNote?.durationSeconds, 45);

    final cleared = await store.clearVoiceEvidence(withVoice);

    expect(cleared.voiceNote, isNull);
    expect(store.find(cleared.id)?.voiceNote, isNull);
  });
}
