import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/local_report.dart';

class LocalReportStore {
  static const boxName = 'local_reports';
  static const _uuid = Uuid();

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Map>(boxName);
    }
  }

  Box<Map> get _box => Hive.box<Map>(boxName);

  ValueListenable<Box<Map>> listenable() => _box.listenable();

  List<LocalReport> reportsForOwner(String ownerId) {
    final reports = _box.values
        .map(LocalReport.fromMap)
        .where((report) => report.ownerId == ownerId)
        .toList();

    reports.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return reports;
  }

  List<LocalReport> pendingSyncReports(String ownerId) {
    return reportsForOwner(ownerId)
        .where(
          (report) =>
              report.status == LocalReportStatus.pendingUpload ||
              report.status == LocalReportStatus.failed,
        )
        .toList();
  }

  LocalReport? find(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return LocalReport.fromMap(data);
  }

  Future<LocalReport> createDraft({
    required String ownerId,
    required String category,
  }) async {
    final now = DateTime.now().toUtc();
    final report = LocalReport(
      id: _uuid.v4(),
      ownerId: ownerId,
      category: category,
      status: LocalReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    await save(report);
    return report;
  }

  Future<void> save(LocalReport report) {
    return _box.put(report.id, report.toMap());
  }

  Future<LocalReport> updateUrgency({
    required LocalReport report,
    required ReportUrgency urgency,
  }) async {
    final updated = report.copyWith(
      urgency: urgency,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> updateDescription({
    required LocalReport report,
    required String description,
  }) async {
    final updated = report.copyWith(
      description: description.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> updateLocation({
    required LocalReport report,
    required LocalReportLocation location,
  }) async {
    final updated = report.copyWith(
      location: location,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> addImageEvidence({
    required LocalReport report,
    required LocalImageEvidence image,
  }) async {
    final updated = report.copyWith(
      images: [...report.images, image],
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> removeImageEvidence({
    required LocalReport report,
    required LocalImageEvidence image,
  }) async {
    final updated = report.copyWith(
      images: report.images
          .where((existing) => existing.path != image.path)
          .toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> saveVoiceEvidence({
    required LocalReport report,
    required LocalVoiceEvidence voiceNote,
  }) async {
    final updated = report.copyWith(
      voiceNote: voiceNote,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> clearVoiceEvidence(LocalReport report) async {
    final updated = report.copyWith(
      clearVoiceNote: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> markPendingUpload(LocalReport report) async {
    final updated = report.copyWith(
      status: LocalReportStatus.pendingUpload,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> markUploading(LocalReport report) async {
    final now = DateTime.now().toUtc();
    final updated = report.copyWith(
      status: LocalReportStatus.uploading,
      syncAttempts: report.syncAttempts + 1,
      clearLastSyncError: true,
      lastSyncAttemptAt: now,
      updatedAt: now,
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> markSyncFailed({
    required LocalReport report,
    required String error,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = report.copyWith(
      status: LocalReportStatus.failed,
      lastSyncError: error,
      lastSyncAttemptAt: now,
      updatedAt: now,
    );
    await save(updated);
    return updated;
  }

  Future<LocalReport> markSubmitted(LocalReport report) async {
    final now = DateTime.now().toUtc();
    final updated = report.copyWith(
      status: LocalReportStatus.submitted,
      clearLastSyncError: true,
      submittedAt: now,
      updatedAt: now,
    );
    await save(updated);
    return updated;
  }
}
