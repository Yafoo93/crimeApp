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
  });

  final String id;
  final String ownerId;
  final String category;
  final LocalReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReportUrgency? urgency;
  final String? description;

  LocalReport copyWith({
    String? category,
    LocalReportStatus? status,
    DateTime? updatedAt,
    ReportUrgency? urgency,
    String? description,
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
    );
  }
}
