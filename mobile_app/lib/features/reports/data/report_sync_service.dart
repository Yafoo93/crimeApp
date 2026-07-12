import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/local_report.dart';
import 'local_report_store.dart';

class ReportSyncService {
  ReportSyncService({
    LocalReportStore? store,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Connectivity? connectivity,
  })  : _store = store ?? LocalReportStore(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _connectivity = connectivity ?? Connectivity();

  final LocalReportStore _store;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  Future<void> start() async {
    await syncPendingReports();
    _connectivitySubscription ??=
        _connectivity.onConnectivityChanged.listen((results) {
      if (_hasNetwork(results)) {
        unawaited(syncPendingReports());
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> syncPendingReports() async {
    if (_isSyncing) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final connectivity = await _connectivity.checkConnectivity();
    if (!_hasNetwork(connectivity)) return;

    _isSyncing = true;
    try {
      final queue = _store.pendingSyncReports(user.uid);
      for (final report in queue) {
        await _syncReport(report, user);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncReport(LocalReport report, User user) async {
    final reportRef = _firestore.collection('reports').doc(report.id);
    var currentReport = report;

    try {
      final existing = await reportRef.get();
      if (existing.exists) {
        await _store.markSubmitted(report);
        return;
      }

      final uploading = await _store.markUploading(report);
      currentReport = uploading;
      final media = await _uploadMedia(uploading);
      final now = FieldValue.serverTimestamp();

      final batch = _firestore.batch();
      batch.set(reportRef, {
        'id': uploading.id,
        'reporterId': user.uid,
        'reporterDisplayName': user.isAnonymous
            ? 'Protected Reporter'
            : user.displayName ?? 'Reporter',
        'anonymous': user.isAnonymous,
        'categoryId': _categoryId(uploading.category),
        'categoryLabel': uploading.category,
        'urgency': _remoteUrgency(uploading.urgency),
        'description': uploading.description ?? '',
        'status': LocalReportStatus.submitted.name,
        'syncStatus': LocalReportStatus.submitted.name,
        'location': uploading.location.toMap(),
        'media': media,
        'spamFlagged': false,
        'createdAt': Timestamp.fromDate(uploading.createdAt),
        'updatedAt': now,
        'submittedAt': now,
        'assignedTo': null,
        'adminNotesCount': 0,
      });

      for (final item in media) {
        final mediaId = item['id'] as String;
        batch.set(_firestore.collection('report_media').doc(mediaId), {
          'id': mediaId,
          'ownerId': user.uid,
          'reportId': uploading.id,
          'type': item['type'],
          'storagePath': item['storagePath'],
          'contentType': item['contentType'],
          'sizeBytes': item['sizeBytes'],
          'status': 'uploaded',
          'createdAt': now,
          'updatedAt': now,
        });
      }

      await batch.commit();
      await _store.markSubmitted(uploading);
    } catch (error) {
      await _store.markSyncFailed(
        report: currentReport,
        error: _syncErrorMessage(error),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _uploadMedia(LocalReport report) async {
    final media = <Map<String, dynamic>>[];

    for (var index = 0; index < report.images.length; index++) {
      final image = report.images[index];
      final extension = _extensionFromMimeType(image.mimeType);
      final storagePath =
          'evidence/${report.ownerId}/${report.id}/image_$index.$extension';
      await _uploadFile(
        path: image.path,
        storagePath: storagePath,
        contentType: image.mimeType,
      );
      media.add({
        'id': '${report.id}_image_$index',
        'type': 'image',
        'storagePath': storagePath,
        'contentType': image.mimeType,
        'sizeBytes': image.sizeBytes,
      });
    }

    final voice = report.voiceNote;
    if (voice != null) {
      final file = File(voice.path);
      final sizeBytes = await file.length();
      final storagePath = 'evidence/${report.ownerId}/${report.id}/voice.m4a';
      await _uploadFile(
        path: voice.path,
        storagePath: storagePath,
        contentType: 'audio/mp4',
      );
      media.add({
        'id': '${report.id}_voice',
        'type': 'voice',
        'storagePath': storagePath,
        'contentType': 'audio/mp4',
        'sizeBytes': sizeBytes,
        'durationSeconds': voice.durationSeconds,
      });
    }

    return media;
  }

  Future<void> _uploadFile({
    required String path,
    required String storagePath,
    required String contentType,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Missing evidence file: $path');
    }

    await _storage.ref(storagePath).putFile(
          file,
          SettableMetadata(contentType: contentType),
        );
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _remoteUrgency(ReportUrgency? urgency) {
    switch (urgency) {
      case ReportUrgency.high:
        return 'urgent';
      case ReportUrgency.critical:
        return 'critical';
      case ReportUrgency.low:
      case ReportUrgency.medium:
      case null:
        return 'normal';
    }
  }

  String _categoryId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _extensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/heic':
      case 'image/heif':
        return 'heic';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  String _syncErrorMessage(Object error) {
    final message = error.toString();
    if (message.length <= 300) return message;
    return message.substring(0, 300);
  }
}
