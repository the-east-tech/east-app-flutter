class StorageOverview {
  final DateTime measuredAt;
  final int databaseBytes;
  final int applicationTablesBytes;
  final int maxViewRows;
  final List<StorageTableUsage> tables;

  const StorageOverview({
    required this.measuredAt,
    required this.databaseBytes,
    required this.applicationTablesBytes,
    required this.maxViewRows,
    required this.tables,
  });

  factory StorageOverview.fromJson(Map<String, dynamic> json) {
    return StorageOverview(
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      databaseBytes: (json['databaseBytes'] as num).toInt(),
      applicationTablesBytes:
          (json['applicationTablesBytes'] as num).toInt(),
      maxViewRows: (json['maxViewRows'] as num?)?.toInt() ?? 100,
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

class StorageTableData {
  final String tableName;
  final int requestedRows;
  final int returnedRows;
  final List<StorageTableColumn> columns;
  final List<List<String?>> rows;

  const StorageTableData({
    required this.tableName,
    required this.requestedRows,
    required this.returnedRows,
    required this.columns,
    required this.rows,
  });

  factory StorageTableData.fromJson(Map<String, dynamic> json) {
    return StorageTableData(
      tableName: json['tableName'] as String,
      requestedRows: (json['requestedRows'] as num).toInt(),
      returnedRows: (json['returnedRows'] as num).toInt(),
      columns: (json['columns'] as List<dynamic>)
          .map(
            (item) => StorageTableColumn.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      rows: (json['rows'] as List<dynamic>)
          .map(
            (row) => (row as List<dynamic>)
                .map((value) => value?.toString())
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }
}

class StorageTableColumn {
  final String name;
  final String dataType;
  final bool nullable;

  const StorageTableColumn({
    required this.name,
    required this.dataType,
    required this.nullable,
  });

  factory StorageTableColumn.fromJson(Map<String, dynamic> json) {
    return StorageTableColumn(
      name: json['name'] as String,
      dataType: json['dataType'] as String,
      nullable: json['nullable'] as bool,
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
