class StorageOverview {
  final DateTime measuredAt;
  final int databaseBytes;
  final int applicationTablesBytes;
  final List<StorageTableUsage> tables;

  const StorageOverview({
    required this.measuredAt,
    required this.databaseBytes,
    required this.applicationTablesBytes,
    required this.tables,
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
    );
  }
}

class StorageTableUsage {
  final String tableName;
  final String group;
  final String dataUse;
  final int rowCount;
  final DateTime? oldestDate;
  final DateTime? latestDate;
  final int dataBytes;
  final int indexBytes;
  final int totalBytes;
  final bool deleteAllowed;
  final int deletableRows;
  final String? deleteDescription;

  const StorageTableUsage({
    required this.tableName,
    required this.group,
    required this.dataUse,
    required this.rowCount,
    required this.oldestDate,
    required this.latestDate,
    required this.dataBytes,
    required this.indexBytes,
    required this.totalBytes,
    required this.deleteAllowed,
    required this.deletableRows,
    required this.deleteDescription,
  });

  factory StorageTableUsage.fromJson(Map<String, dynamic> json) {
    return StorageTableUsage(
      tableName: json['tableName'] as String,
      group: json['group'] as String,
      dataUse: json['dataUse'] as String,
      rowCount: (json['rowCount'] as num).toInt(),
      oldestDate: _dateOrNull(json['oldestDate']),
      latestDate: _dateOrNull(json['latestDate']),
      dataBytes: (json['dataBytes'] as num).toInt(),
      indexBytes: (json['indexBytes'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num).toInt(),
      deleteAllowed: json['deleteAllowed'] as bool,
      deletableRows: (json['deletableRows'] as num).toInt(),
      deleteDescription: json['deleteDescription'] as String?,
    );
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.parse(value);
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
