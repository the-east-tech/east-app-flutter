class StorageOverview {
  final DateTime measuredAt;
  final int databaseBytes;
  final int applicationTablesBytes;
  final List<StorageTableUsage> tables;
  final List<StorageCleanupAction> cleanupActions;

  const StorageOverview({
    required this.measuredAt,
    required this.databaseBytes,
    required this.applicationTablesBytes,
    required this.tables,
    required this.cleanupActions,
  });

  factory StorageOverview.fromJson(Map<String, dynamic> json) {
    return StorageOverview(
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      databaseBytes: (json['databaseBytes'] as num).toInt(),
      applicationTablesBytes:
          (json['applicationTablesBytes'] as num).toInt(),
      tables: (json['tables'] as List<dynamic>)
          .map(
            (item) => StorageTableUsage.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      cleanupActions: (json['cleanupActions'] as List<dynamic>)
          .map(
            (item) => StorageCleanupAction.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class StorageTableUsage {
  final String tableName;
  final String group;
  final String dataUse;
  final int estimatedRows;
  final int dataBytes;
  final int indexBytes;
  final int totalBytes;

  const StorageTableUsage({
    required this.tableName,
    required this.group,
    required this.dataUse,
    required this.estimatedRows,
    required this.dataBytes,
    required this.indexBytes,
    required this.totalBytes,
  });

  factory StorageTableUsage.fromJson(Map<String, dynamic> json) {
    return StorageTableUsage(
      tableName: json['tableName'] as String,
      group: json['group'] as String,
      dataUse: json['dataUse'] as String,
      estimatedRows: (json['estimatedRows'] as num).toInt(),
      dataBytes: (json['dataBytes'] as num).toInt(),
      indexBytes: (json['indexBytes'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num).toInt(),
    );
  }
}

class StorageCleanupResult {
  final String key;
  final int deletedRows;
  final DateTime completedAt;

  const StorageCleanupResult({
    required this.key,
    required this.deletedRows,
    required this.completedAt,
  });

  factory StorageCleanupResult.fromJson(Map<String, dynamic> json) {
    return StorageCleanupResult(
      key: json['key'] as String,
      deletedRows: (json['deletedRows'] as num).toInt(),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}

class StorageCleanupAction {
  final String key;
  final String title;
  final String description;
  final int retentionDays;
  final int currentBytes;
  final bool automatic;

  const StorageCleanupAction({
    required this.key,
    required this.title,
    required this.description,
    required this.retentionDays,
    required this.currentBytes,
    required this.automatic,
  });

  factory StorageCleanupAction.fromJson(Map<String, dynamic> json) {
    return StorageCleanupAction(
      key: json['key'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      retentionDays: (json['retentionDays'] as num).toInt(),
      currentBytes: (json['currentBytes'] as num).toInt(),
      automatic: json['automatic'] as bool,
    );
  }
}
