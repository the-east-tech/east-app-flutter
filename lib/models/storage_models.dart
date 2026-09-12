import 'dart:typed_data';

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

enum BusinessCleanupDataType {
  inactiveSetup('INACTIVE_SETUP', 'Inactive Setup'),
  stockHistory('STOCK_HISTORY', 'Stock History'),
  reports('REPORTS', 'Reports'),
  tasks('TASKS', 'Tasks'),
  attendance('ATTENDANCE', 'Attendance'),
  activity('ACTIVITY', 'Activity'),
  videoAnalytics('VIDEO_ANALYTICS', 'Video Analytics');

  final String apiValue;
  final String label;

  const BusinessCleanupDataType(this.apiValue, this.label);

  static BusinessCleanupDataType fromApi(String value) => values.firstWhere(
        (item) => item.apiValue == value,
      );
}

enum BusinessCleanupMediaMode {
  all('ALL', 'Include all photos'),
  selected('SELECTED', 'Choose photo types'),
  none('NONE', 'Data only — exclude all photos');

  final String apiValue;
  final String label;

  const BusinessCleanupMediaMode(this.apiValue, this.label);

  static BusinessCleanupMediaMode fromApi(String value) => values.firstWhere(
        (item) => item.apiValue == value,
      );
}

enum BusinessCleanupMediaType {
  skuThumbnails('SKU_THUMBNAILS', 'SKU photos & thumbnails'),
  stockCountPhotos('STOCK_COUNT_PHOTOS', 'Stock Count photos'),
  receivableInvoicePhotos(
    'RECEIVABLE_INVOICE_PHOTOS',
    'Receivable invoice photos',
  ),
  receivableGoodsPhotos(
    'RECEIVABLE_GOODS_PHOTOS',
    'Receivable goods photos',
  ),
  salesVoidBillPhotos(
    'SALES_VOID_BILL_PHOTOS',
    'Sales void-bill photos',
  ),
  wastePhotos('WASTE_PHOTOS', 'Waste photos'),
  complaintPhotos('COMPLAINT_PHOTOS', 'Complaint photos'),
  taskReportPhotos('TASK_REPORT_PHOTOS', 'Task/report photos'),
  advertisementPhotos('ADVERTISEMENT_PHOTOS', 'Advertisement photos');

  final String apiValue;
  final String label;

  const BusinessCleanupMediaType(this.apiValue, this.label);

  static BusinessCleanupMediaType fromApi(String value) => values.firstWhere(
        (item) => item.apiValue == value,
      );
}

class BusinessCleanupSelection {
  final Set<BusinessCleanupDataType> dataTypes;
  final DateTime cutoffDate;
  final BusinessCleanupMediaMode mediaMode;
  final Set<BusinessCleanupMediaType> mediaTypes;

  const BusinessCleanupSelection({
    required this.dataTypes,
    required this.cutoffDate,
    required this.mediaMode,
    required this.mediaTypes,
  });

  Map<String, Object?> toJson() => {
        'dataTypes': dataTypes.map((item) => item.apiValue).toList(),
        'cutoffDate': _apiDate(cutoffDate),
        'mediaMode': mediaMode.apiValue,
        'mediaTypes': mediaTypes.map((item) => item.apiValue).toList(),
      };
}

class BusinessCleanupPreview {
  final int recordCount;
  final int blockedRecordCount;
  final int photoCount;
  final int excludedPhotoCount;
  final int estimatedZipBytes;
  final List<BusinessCleanupCategoryPreview> categories;

  const BusinessCleanupPreview({
    required this.recordCount,
    required this.blockedRecordCount,
    required this.photoCount,
    required this.excludedPhotoCount,
    required this.estimatedZipBytes,
    required this.categories,
  });

  factory BusinessCleanupPreview.fromJson(Map<String, dynamic> json) {
    return BusinessCleanupPreview(
      recordCount: (json['recordCount'] as num).toInt(),
      blockedRecordCount: (json['blockedRecordCount'] as num).toInt(),
      photoCount: (json['photoCount'] as num).toInt(),
      excludedPhotoCount: (json['excludedPhotoCount'] as num).toInt(),
      estimatedZipBytes: (json['estimatedZipBytes'] as num).toInt(),
      categories: (json['categories'] as List<dynamic>)
          .map(
            (item) => BusinessCleanupCategoryPreview.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class BusinessCleanupCategoryPreview {
  final BusinessCleanupDataType dataType;
  final int recordCount;
  final int blockedRecordCount;
  final String description;

  const BusinessCleanupCategoryPreview({
    required this.dataType,
    required this.recordCount,
    required this.blockedRecordCount,
    required this.description,
  });

  factory BusinessCleanupCategoryPreview.fromJson(Map<String, dynamic> json) {
    return BusinessCleanupCategoryPreview(
      dataType: BusinessCleanupDataType.fromApi(json['dataType'] as String),
      recordCount: (json['recordCount'] as num).toInt(),
      blockedRecordCount: (json['blockedRecordCount'] as num).toInt(),
      description: json['description'] as String,
    );
  }
}

class BusinessCleanupBackupFile {
  final String runId;
  final String fileName;
  final String sha256;
  final Uint8List bytes;

  const BusinessCleanupBackupFile({
    required this.runId,
    required this.fileName,
    required this.sha256,
    required this.bytes,
  });
}

class BusinessCleanupRun {
  final String id;
  final DateTime cutoffDate;
  final Set<BusinessCleanupDataType> dataTypes;
  final BusinessCleanupMediaMode mediaMode;
  final Set<BusinessCleanupMediaType> mediaTypes;
  final int recordCount;
  final int blockedRecordCount;
  final int photoCount;
  final int excludedPhotoCount;
  final int zipSizeBytes;
  final String zipFileName;
  final String zipSha256;
  final String status;
  final DateTime createdAt;
  final DateTime? savedConfirmedAt;
  final DateTime? completedAt;
  final int deletedRecordCount;
  final int deletedPhotoCount;

  const BusinessCleanupRun({
    required this.id,
    required this.cutoffDate,
    required this.dataTypes,
    required this.mediaMode,
    required this.mediaTypes,
    required this.recordCount,
    required this.blockedRecordCount,
    required this.photoCount,
    required this.excludedPhotoCount,
    required this.zipSizeBytes,
    required this.zipFileName,
    required this.zipSha256,
    required this.status,
    required this.createdAt,
    required this.savedConfirmedAt,
    required this.completedAt,
    required this.deletedRecordCount,
    required this.deletedPhotoCount,
  });

  bool get isBackupCreated => status == 'BACKUP_CREATED';
  bool get isSavedConfirmed => status == 'SAVED_CONFIRMED';
  bool get isCompleted => status == 'COMPLETED';

  factory BusinessCleanupRun.fromJson(Map<String, dynamic> json) {
    return BusinessCleanupRun(
      id: json['id'] as String,
      cutoffDate: DateTime.parse(json['cutoffDate'] as String),
      dataTypes: (json['dataTypes'] as List<dynamic>)
          .map((item) => BusinessCleanupDataType.fromApi(item as String))
          .toSet(),
      mediaMode: BusinessCleanupMediaMode.fromApi(json['mediaMode'] as String),
      mediaTypes: (json['mediaTypes'] as List<dynamic>)
          .map((item) => BusinessCleanupMediaType.fromApi(item as String))
          .toSet(),
      recordCount: (json['recordCount'] as num).toInt(),
      blockedRecordCount: (json['blockedRecordCount'] as num).toInt(),
      photoCount: (json['photoCount'] as num).toInt(),
      excludedPhotoCount: (json['excludedPhotoCount'] as num).toInt(),
      zipSizeBytes: (json['zipSizeBytes'] as num).toInt(),
      zipFileName: json['zipFileName'] as String,
      zipSha256: json['zipSha256'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      savedConfirmedAt: _dateTimeOrNull(json['savedConfirmedAt']),
      completedAt: _dateTimeOrNull(json['completedAt']),
      deletedRecordCount: (json['deletedRecordCount'] as num).toInt(),
      deletedPhotoCount: (json['deletedPhotoCount'] as num).toInt(),
    );
  }
}

class BusinessCleanupComplete {
  final String runId;
  final int deletedRecordCount;
  final int deletedPhotoCount;
  final DateTime completedAt;

  const BusinessCleanupComplete({
    required this.runId,
    required this.deletedRecordCount,
    required this.deletedPhotoCount,
    required this.completedAt,
  });

  factory BusinessCleanupComplete.fromJson(Map<String, dynamic> json) {
    return BusinessCleanupComplete(
      runId: json['runId'] as String,
      deletedRecordCount: (json['deletedRecordCount'] as num).toInt(),
      deletedPhotoCount: (json['deletedPhotoCount'] as num).toInt(),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}

String _apiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? _dateTimeOrNull(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value);
}
