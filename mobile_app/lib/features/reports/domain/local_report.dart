enum LocalReportStatus {
  draft,
  pendingUpload,
  uploading,
  submitted,
  failed,
}

enum ReportUrgency {
  low,
  medium,
  high,
  critical,
}

class LocalImageEvidence {
  const LocalImageEvidence({
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String path;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalImageEvidence.fromMap(Map<dynamic, dynamic> map) {
    return LocalImageEvidence(
      path: map['path'] as String,
      mimeType: map['mimeType'] as String,
      sizeBytes: map['sizeBytes'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class LocalVoiceEvidence {
  const LocalVoiceEvidence({
    required this.path,
    required this.durationSeconds,
    required this.createdAt,
  });

  final String path;
  final int durationSeconds;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalVoiceEvidence.fromMap(Map<dynamic, dynamic> map) {
    return LocalVoiceEvidence(
      path: map['path'] as String,
      durationSeconds: map['durationSeconds'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class LocalReportLocation {
  const LocalReportLocation({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.ghanaPostGps,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? ghanaPostGps;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isEmpty =>
      !hasCoordinates && (ghanaPostGps == null || ghanaPostGps!.trim().isEmpty);

  LocalReportLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    String? ghanaPostGps,
  }) {
    return LocalReportLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      ghanaPostGps: ghanaPostGps ?? this.ghanaPostGps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'ghanaPostGps': ghanaPostGps,
    };
  }

  factory LocalReportLocation.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const LocalReportLocation();

    return LocalReportLocation(
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      ghanaPostGps: map['ghanaPostGps'] as String?,
    );
  }
}

class LocalReport {
  const LocalReport({
    required this.id,
    required this.ownerId,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.urgency,
    this.description,
    this.location = const LocalReportLocation(),
    this.images = const [],
    this.voiceNote,
    this.syncAttempts = 0,
    this.lastSyncError,
    this.lastSyncAttemptAt,
    this.submittedAt,
  });

  final String id;
  final String ownerId;
  final String category;
  final LocalReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReportUrgency? urgency;
  final String? description;
  final LocalReportLocation location;
  final List<LocalImageEvidence> images;
  final LocalVoiceEvidence? voiceNote;
  final int syncAttempts;
  final String? lastSyncError;
  final DateTime? lastSyncAttemptAt;
  final DateTime? submittedAt;

  LocalReport copyWith({
    String? category,
    LocalReportStatus? status,
    DateTime? updatedAt,
    ReportUrgency? urgency,
    String? description,
    LocalReportLocation? location,
    List<LocalImageEvidence>? images,
    LocalVoiceEvidence? voiceNote,
    bool clearVoiceNote = false,
    int? syncAttempts,
    String? lastSyncError,
    bool clearLastSyncError = false,
    DateTime? lastSyncAttemptAt,
    DateTime? submittedAt,
  }) {
    return LocalReport(
      id: id,
      ownerId: ownerId,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      urgency: urgency ?? this.urgency,
      description: description ?? this.description,
      location: location ?? this.location,
      images: images ?? this.images,
      voiceNote: clearVoiceNote ? null : voiceNote ?? this.voiceNote,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncError:
          clearLastSyncError ? null : lastSyncError ?? this.lastSyncError,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'category': category,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'urgency': urgency?.name,
      'description': description,
      'location': location.toMap(),
      'images': images.map((image) => image.toMap()).toList(),
      'voiceNote': voiceNote?.toMap(),
      'syncAttempts': syncAttempts,
      'lastSyncError': lastSyncError,
      'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }

  factory LocalReport.fromMap(Map<dynamic, dynamic> map) {
    final statusName = map['status'] as String? ?? LocalReportStatus.draft.name;
    final urgencyName = map['urgency'] as String?;

    return LocalReport(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      category: map['category'] as String,
      status: LocalReportStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => LocalReportStatus.draft,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      urgency: urgencyName == null
          ? null
          : ReportUrgency.values.firstWhere(
              (urgency) => urgency.name == urgencyName,
              orElse: () => ReportUrgency.medium,
            ),
      description: map['description'] as String?,
      location: LocalReportLocation.fromMap(
        map['location'] as Map<dynamic, dynamic>?,
      ),
      images: ((map['images'] as List<dynamic>?) ?? const [])
          .map(
            (item) => LocalImageEvidence.fromMap(
              item as Map<dynamic, dynamic>,
            ),
          )
          .toList(),
      voiceNote: map['voiceNote'] == null
          ? null
          : LocalVoiceEvidence.fromMap(
              map['voiceNote'] as Map<dynamic, dynamic>,
            ),
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      lastSyncError: map['lastSyncError'] as String?,
      lastSyncAttemptAt: map['lastSyncAttemptAt'] == null
          ? null
          : DateTime.parse(map['lastSyncAttemptAt'] as String),
      submittedAt: map['submittedAt'] == null
          ? null
          : DateTime.parse(map['submittedAt'] as String),
    );
  }
}
