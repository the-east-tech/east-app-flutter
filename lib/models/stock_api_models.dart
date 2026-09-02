import 'dart:typed_data';

import 'app_models.dart';
import 'api_models.dart';

class StockReviewSummary {
  final int pendingReview;
  final int done;
  final int total;

  const StockReviewSummary({
    required this.pendingReview,
    required this.done,
    required this.total,
  });

  factory StockReviewSummary.fromJson(Map<String, dynamic> json) {
    return StockReviewSummary(
      pendingReview: (json['pendingReview'] as num? ?? 0).toInt(),
      done: (json['done'] as num? ?? 0).toInt(),
      total: (json['total'] as num? ?? 0).toInt(),
    );
  }
}

class EastAppStockSnapshot {
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final List<StockSku> skus;
  final List<StockSubmission> submissions;
  final List<StockReceivingRecord> receivingRecords;

  const EastAppStockSnapshot({
    required this.tags,
    required this.suppliers,
    required this.skus,
    required this.submissions,
    required this.receivingRecords,
  });

  factory EastAppStockSnapshot.fromJson(Map<String, dynamic> json) {
    return EastAppStockSnapshot(
      tags: _list(json['tags'], stockTagFromJson),
      suppliers: _list(json['suppliers'], stockSupplierFromJson),
      skus: _list(json['skus'], stockSkuFromJson),
      submissions: _list(json['submissions'], stockSubmissionFromJson),
      receivingRecords: _list(
        json['receivingRecords'],
        stockReceivingRecordFromJson,
      ),
    );
  }
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List<dynamic>) return const [];
  return value
      .map((item) => mapper(item as Map<String, dynamic>))
      .toList(growable: false);
}

StockTag stockTagFromJson(Map<String, dynamic> json) {
  return StockTag(
    id: json['id'] as String,
    tag: json['tag'] as String,
    createdBy: json['createdBy'] as String,
    createdDate: json['createdDate'] as String,
    lastUpdated: json['lastUpdated'] as String,
    assignedUsers: (json['assignedUsers'] as List<dynamic>? ?? const [])
        .map((item) {
          final value = item as Map<String, dynamic>;
          return StockTagAssignee(
            userId: value['userId'] as String,
            fullName: value['fullName'] as String,
            employeeId: value['employeeId'] as String,
            role: value['role'] as String,
          );
        })
        .toList(growable: false),
  );
}

SupplierProfile stockSupplierFromJson(Map<String, dynamic> json) {
  return SupplierProfile(
    id: json['id'] as String,
    supplierName: json['supplierName'] as String,
    supplierItem: json['supplierItem'] as String,
    contactPerson: json['contactPerson'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    address: json['address'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    unit: json['unit'] as String,
    recommendedPurchaseAmount:
        (json['recommendedPurchaseAmount'] as num).toDouble(),
    recommendedPurchaseFrequency:
        json['recommendedPurchaseFrequency'] as String? ?? '',
    pricingPerUnit: (json['pricingPerUnit'] as num).toDouble(),
    minimumBalanceValue: (json['minimumBalanceValue'] as num).toDouble(),
    maximumBalanceValue: (json['maximumBalanceValue'] as num).toDouble(),
    currentBalanceValue: (json['currentBalanceValue'] as num).toDouble(),
    lastBalanceUpdatedAt: json['lastBalanceUpdatedAt'] as String,
    lastBalanceUpdatedBy: json['lastBalanceUpdatedBy'] as String,
  );
}

StockSku stockSkuFromJson(Map<String, dynamic> json) {
  return StockSku(
    id: json['id'] as String,
    name: json['name'] as String,
    tag1Id: json['tag1Id'] as String? ?? '',
    category: json['category'] as String? ?? '',
    tag2Id: json['tag2Id'] as String? ?? '',
    unit: json['unit'] as String,
    minimumBalanceValue: (json['minimumBalanceValue'] as num).toDouble(),
    maximumBalanceValue: (json['maximumBalanceValue'] as num).toDouble(),
    currentBalanceValue: (json['currentBalanceValue'] as num).toDouble(),
    recoveryPercent: (json['recoveryPercent'] as num).toInt(),
    minimumPriceRm: (json['minimumPriceRm'] as num).toDouble(),
    maximumPriceRm: (json['maximumPriceRm'] as num).toDouble(),
    supplierIds: (json['supplierIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    photoPath: json['photoPath'] as String? ?? '',
    assignedStaffNames:
        (json['assignedStaffNames'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
    location: json['location'] as String? ?? '',
    receivingChecklist:
        (json['receivingChecklist'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
    stockCheckFrequencyDays:
        (json['stockCheckFrequencyDays'] as num?)?.toInt() ?? 1,
    resetTime: json['resetTime'] as String? ?? '08:00',
    lastUpdatedAt: json['lastUpdatedAt'] as String? ?? '',
    lastUpdatedBy: json['lastUpdatedBy'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    coolingPeriod: json['coolingPeriod'] as bool? ?? true,
  );
}

StockSubmission stockSubmissionFromJson(Map<String, dynamic> json) {
  return StockSubmission(
    id: json['id'] as String,
    stockTaskId: json['stockTaskId'] as String,
    skuName: json['skuName'] as String? ?? '',
    skuUnit: json['skuUnit'] as String? ?? '',
    skuCategory: json['skuCategory'] as String? ?? '',
    skuLocation: json['skuLocation'] as String? ?? '',
    skuPhotoPath: json['skuPhotoPath'] as String? ?? '',
    skuMinimumBalanceValue:
        (json['skuMinimumBalanceValue'] as num?)?.toDouble() ?? 0,
    skuMaximumBalanceValue:
        (json['skuMaximumBalanceValue'] as num?)?.toDouble() ?? 0,
    submittedBy: json['submittedBy'] as String,
    submittedAt: json['submittedAt'] as String,
    capturedAt: DateTime.parse(json['capturedAt'] as String).toLocal(),
    stockPhotoName: json['stockPhotoName'] as String,
    invoicePhotoName: json['invoicePhotoName'] as String,
    previousBalanceValue:
        (json['previousBalanceValue'] as num).toDouble(),
    currentBalanceValue: (json['currentBalanceValue'] as num).toDouble(),
    belowMinimumBalance: json['belowMinimumBalance'] as bool,
    checkedItems: Map<String, bool>.from(
      json['checkedItems'] as Map<String, dynamic>? ?? const {},
    ),
    remarks: (json['remarks'] as Map<String, dynamic>? ?? const {})
        .map((key, value) => MapEntry(key, value.toString())),
    reviewStatus: json['reviewStatus'] as String? ?? 'Pending Review',
    reviewedBy: json['reviewedBy'] as String? ?? '',
    reviewedAt: json['reviewedAt'] as String? ?? '',
    reviewNote: json['reviewNote'] as String? ?? '',
  );
}

StockReceivingRecord stockReceivingRecordFromJson(
  Map<String, dynamic> json,
) {
  return StockReceivingRecord(
    id: json['id'] as String,
    supplierId: json['supplierId'] as String,
    supplierName: json['supplierName'] as String,
    receivedBy: json['receivedBy'] as String,
    receivedAt: json['receivedAt'] as String,
    capturedAt: DateTime.parse(json['capturedAt'] as String).toLocal(),
    invoicePhotoName: json['invoicePhotoName'] as String,
    goodsPhotoName: json['goodsPhotoName'] as String,
    items: _list(json['items'], stockReceivingItemFromJson),
    reviewStatus: json['reviewStatus'] as String? ?? 'Pending Review',
    reviewedBy: json['reviewedBy'] as String? ?? '',
    reviewedAt: json['reviewedAt'] as String? ?? '',
    reviewNote: json['reviewNote'] as String? ?? '',
  );
}

StockReceivingItem stockReceivingItemFromJson(Map<String, dynamic> json) {
  return StockReceivingItem(
    skuId: json['skuId'] as String,
    skuName: json['skuName'] as String,
    invoiceQuantity: (json['invoiceQuantity'] as num).toDouble(),
    receivedQuantity: (json['receivedQuantity'] as num).toDouble(),
    unit: json['unit'] as String,
    condition: json['condition'] as String? ?? '',
    note: json['note'] as String? ?? '',
  );
}

StockAuditEntry stockAuditEntryFromJson(Map<String, dynamic> json) {
  return StockAuditEntry(
    id: json['id'] as String,
    module: json['module'] as String,
    action: json['action'] as String,
    itemId: json['itemId'] as String? ?? '',
    itemName: json['itemName'] as String,
    actorName: json['actorName'] as String,
    actorId: json['actorId'] as String,
    actorRole: json['actorRole'] as String,
    timestampText: json['timestampText'] as String,
    capturedAt: DateTime.parse(json['capturedAt'] as String).toLocal(),
    changes: _list(json['changes'], stockAuditChangeFromJson),
    note: json['note'] as String? ?? '',
  );
}

StockAuditChange stockAuditChangeFromJson(Map<String, dynamic> json) {
  return StockAuditChange(
    field: json['field'] as String,
    oldValue: json['oldValue'] as String,
    newValue: json['newValue'] as String,
  );
}

Map<String, Object?> stockSupplierToJson(SupplierProfile supplier) {
  return {
    'supplierName': supplier.supplierName,
    'supplierItem': supplier.supplierItem,
    'contactPerson': supplier.contactPerson,
    'phone': supplier.phone,
    'address': supplier.address,
    'notes': supplier.notes,
    'unit': supplier.unit,
    'recommendedPurchaseAmount': supplier.recommendedPurchaseAmount,
    'recommendedPurchaseFrequency': supplier.recommendedPurchaseFrequency,
    'pricingPerUnit': supplier.pricingPerUnit,
    'minimumBalanceValue': supplier.minimumBalanceValue,
    'maximumBalanceValue': supplier.maximumBalanceValue,
    'currentBalanceValue': supplier.currentBalanceValue,
  };
}

Map<String, Object?> stockSkuToJson(StockSku sku) {
  return {
    'name': sku.name,
    'tag1Id': sku.tag1Id,
    'tag2Id': sku.tag2Id,
    'unit': sku.unit,
    'minimumBalanceValue': sku.minimumBalanceValue,
    'maximumBalanceValue': sku.maximumBalanceValue,
    'currentBalanceValue': sku.currentBalanceValue,
    'recoveryPercent': sku.recoveryPercent,
    'minimumPriceRm': sku.minimumPriceRm,
    'maximumPriceRm': sku.maximumPriceRm,
    'supplierIds': sku.supplierIds,
    'photoPath': sku.photoPath,
    'assignedStaffNames': sku.assignedStaffNames,
    'receivingChecklist': sku.receivingChecklist,
    'stockCheckFrequencyDays': sku.stockCheckFrequencyDays,
    'resetTime': sku.resetTime,
    'active': sku.active,
    'coolingPeriod': sku.coolingPeriod,
  };
}

Map<String, Object?> stockCountToJson(StockSubmission submission) {
  return {
    'skuId': submission.stockTaskId,
    'capturedAt': submission.capturedAt.toUtc().toIso8601String(),
    'stockPhotoName': submission.stockPhotoName,
    'invoicePhotoName': submission.invoicePhotoName,
    'currentBalanceValue': submission.currentBalanceValue,
    'checkedItems': submission.checkedItems,
    'remarks': submission.remarks,
  };
}

Map<String, Object?> stockReceivingToJson(StockReceivingRecord record) {
  return {
    'supplierId': record.supplierId,
    'capturedAt': record.capturedAt.toUtc().toIso8601String(),
    'invoicePhotoName': record.invoicePhotoName,
    'goodsPhotoName': record.goodsPhotoName,
    'items': record.items
        .map((item) => {
              'skuId': item.skuId,
              'invoiceQuantity': item.invoiceQuantity,
              'receivedQuantity': item.receivedQuantity,
              'condition': item.condition,
              'note': item.note,
            })
        .toList(growable: false),
  };
}

EastAppPage<StockAuditEntry> stockAuditPageFromJson(
  Map<String, dynamic> json,
) {
  return EastAppPage.fromJson(json, stockAuditEntryFromJson);
}


EastAppPage<StockTag> stockTagPageFromJson(Map<String, dynamic> json) {
  return EastAppPage.fromJson(json, stockTagFromJson);
}

EastAppPage<SupplierProfile> stockSupplierPageFromJson(
  Map<String, dynamic> json,
) {
  return EastAppPage.fromJson(json, stockSupplierFromJson);
}

EastAppPage<StockSku> stockSkuPageFromJson(Map<String, dynamic> json) {
  return EastAppPage.fromJson(json, stockSkuFromJson);
}

EastAppPage<StockSubmission> stockSubmissionPageFromJson(
  Map<String, dynamic> json,
) {
  return EastAppPage.fromJson(json, stockSubmissionFromJson);
}

EastAppPage<StockReceivingRecord> stockReceivingPageFromJson(
  Map<String, dynamic> json,
) {
  return EastAppPage.fromJson(json, stockReceivingRecordFromJson);
}

class StockSkuCsvFile {
  final String fileName;
  final Uint8List bytes;

  const StockSkuCsvFile({required this.fileName, required this.bytes});
}

class StockSkuCsvPreview {
  final String format;
  final int formatVersion;
  final int totalRows;
  final int readyRows;
  final int duplicateRows;
  final int invalidRows;
  final int newTagCount;
  final int unmatchedSupplierCount;
  final List<String> unmatchedSupplierNames;
  final List<String> errors;

  const StockSkuCsvPreview({
    required this.format,
    required this.formatVersion,
    required this.totalRows,
    required this.readyRows,
    required this.duplicateRows,
    required this.invalidRows,
    required this.newTagCount,
    required this.unmatchedSupplierCount,
    required this.unmatchedSupplierNames,
    required this.errors,
  });

  bool get canImport => readyRows > 0 && invalidRows == 0;

  factory StockSkuCsvPreview.fromJson(Map<String, dynamic> json) {
    return StockSkuCsvPreview(
      format: json['format'] as String? ?? '',
      formatVersion: (json['formatVersion'] as num? ?? 0).toInt(),
      totalRows: (json['totalRows'] as num? ?? 0).toInt(),
      readyRows: (json['readyRows'] as num? ?? 0).toInt(),
      duplicateRows: (json['duplicateRows'] as num? ?? 0).toInt(),
      invalidRows: (json['invalidRows'] as num? ?? 0).toInt(),
      newTagCount: (json['newTagCount'] as num? ?? 0).toInt(),
      unmatchedSupplierCount:
          (json['unmatchedSupplierCount'] as num? ?? 0).toInt(),
      unmatchedSupplierNames:
          (json['unmatchedSupplierNames'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class StockSkuCsvImportResult {
  final int importedRows;
  final int skippedDuplicateRows;
  final int createdTags;
  final int unmatchedSupplierLinks;

  const StockSkuCsvImportResult({
    required this.importedRows,
    required this.skippedDuplicateRows,
    required this.createdTags,
    required this.unmatchedSupplierLinks,
  });

  factory StockSkuCsvImportResult.fromJson(Map<String, dynamic> json) {
    return StockSkuCsvImportResult(
      importedRows: (json['importedRows'] as num? ?? 0).toInt(),
      skippedDuplicateRows:
          (json['skippedDuplicateRows'] as num? ?? 0).toInt(),
      createdTags: (json['createdTags'] as num? ?? 0).toInt(),
      unmatchedSupplierLinks:
          (json['unmatchedSupplierLinks'] as num? ?? 0).toInt(),
    );
  }
}
