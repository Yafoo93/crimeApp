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

  Future<LocalReport> markPendingUpload(LocalReport report) async {
    final updated = report.copyWith(
      status: LocalReportStatus.pendingUpload,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }
}
