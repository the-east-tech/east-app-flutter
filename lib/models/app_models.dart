enum UserRole {
  staff,
  manager,
  head,
}

enum KnowledgeVideoLanguage {
  english('ENGLISH', 'English'),
  myanmar('MYANMAR', 'Myanmar');

  final String apiValue;
  final String label;

  const KnowledgeVideoLanguage(this.apiValue, this.label);

  static KnowledgeVideoLanguage fromApi(String? value) {
    return KnowledgeVideoLanguage.values.firstWhere(
      (language) => language.apiValue == value?.toUpperCase(),
      orElse: () => KnowledgeVideoLanguage.english,
    );
  }
}

enum RewardTaskStatus {
  pending,
  inProgress,
  submitted,
  approved,
  rejected,
}

class StaffTask {
  final String id;
  final String title;
  final String description;
  final int maxScore;
  final int? awardedScore;
  final String category;
  final RewardTaskStatus status;
  final bool photoRequired;
  final String staffName;
  final String staffId;
  final String? submittedText;
  final String? approvedText;
  final String? rejectedText;
  final String? photoEvidenceName;
  final String? staffRemark;
  final String? approvedBy;
  final String sopOutcome;
  final String sopDescription;

  const StaffTask({
    required this.id,
    required this.title,
    required this.description,
    required this.maxScore,
    required this.category,
    required this.status,
    required this.photoRequired,
    required this.staffName,
    required this.staffId,
    required this.sopOutcome,
    required this.sopDescription,
    this.awardedScore,
    this.submittedText,
    this.approvedText,
    this.rejectedText,
    this.photoEvidenceName,
    this.staffRemark,
    this.approvedBy,
  });

  StaffTask copyWith({
    RewardTaskStatus? status,
    int? awardedScore,
    String? submittedText,
    String? approvedText,
    String? rejectedText,
    String? photoEvidenceName,
    String? staffRemark,
    String? approvedBy,
  }) {
    return StaffTask(
      id: id,
      title: title,
      description: description,
      maxScore: maxScore,
      awardedScore: awardedScore ?? this.awardedScore,
      category: category,
      status: status ?? this.status,
      photoRequired: photoRequired,
      staffName: staffName,
      staffId: staffId,
      submittedText: submittedText ?? this.submittedText,
      approvedText: approvedText ?? this.approvedText,
      rejectedText: rejectedText ?? this.rejectedText,
      photoEvidenceName: photoEvidenceName ?? this.photoEvidenceName,
      staffRemark: staffRemark ?? this.staffRemark,
      approvedBy: approvedBy ?? this.approvedBy,
      sopOutcome: sopOutcome,
      sopDescription: sopDescription,
    );
  }
}

class RecentActivity {
  final String title;
  final String time;
  final int score;
  final String status;

  const RecentActivity({
    required this.title,
    required this.time,
    required this.score,
    required this.status,
  });
}

class RewardHistory {
  final String title;
  final String category;
  final String approvedBy;
  final String date;
  final int score;

  const RewardHistory({
    required this.title,
    required this.category,
    required this.approvedBy,
    required this.date,
    required this.score,
  });
}

class CategoryPoint {
  final String category;
  final int taskCount;
  final int score;

  const CategoryPoint({
    required this.category,
    required this.taskCount,
    required this.score,
  });
}

class LeaderboardMember {
  final String name;
  final String staffId;
  final String role;
  final int score;
  final int tasks;

  const LeaderboardMember({
    required this.name,
    required this.staffId,
    required this.role,
    required this.score,
    required this.tasks,
  });
}

class StockTag {
  final String id;
  final String tag;
  final String createdBy;
  final String createdDate;
  final String lastUpdated;

  const StockTag({
    required this.id,
    required this.tag,
    required this.createdBy,
    required this.createdDate,
    required this.lastUpdated,
  });

  StockTag copyWith({
    String? tag,
    String? lastUpdated,
  }) {
    return StockTag(
      id: id,
      tag: tag ?? this.tag,
      createdBy: createdBy,
      createdDate: createdDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class KnowledgeItem {
  final String id;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String title;
  final String description;
  final String type;
  final String tagId;
  final String tagName;
  final String? imageAsset;
  final String? mediaType;
  final String expectedOutcome;
  final KnowledgeVideoLanguage language;
  final String linkGroupId;
  final String? linkedSopId;
  final String createdBy;
  final DateTime? createdAt;

  const KnowledgeItem({
    this.id = '',
    this.youtubeUrl = '',
    this.youtubeVideoId = '',
    required this.title,
    required this.description,
    required this.type,
    required this.tagId,
    this.tagName = '',
    this.imageAsset,
    this.mediaType,
    required this.expectedOutcome,
    this.language = KnowledgeVideoLanguage.english,
    this.linkGroupId = '',
    this.linkedSopId,
    this.createdBy = '',
    this.createdAt,
  });

  KnowledgeItem copyWith({
    String? id,
    String? youtubeUrl,
    String? youtubeVideoId,
    String? title,
    String? description,
    String? type,
    String? tagId,
    String? tagName,
    String? imageAsset,
    String? mediaType,
    String? expectedOutcome,
    KnowledgeVideoLanguage? language,
    String? linkGroupId,
    String? linkedSopId,
    bool clearLinkedSopId = false,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return KnowledgeItem(
      id: id ?? this.id,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      imageAsset: imageAsset ?? this.imageAsset,
      mediaType: mediaType ?? this.mediaType,
      expectedOutcome: expectedOutcome ?? this.expectedOutcome,
      language: language ?? this.language,
      linkGroupId: linkGroupId ?? this.linkGroupId,
      linkedSopId:
          clearLinkedSopId ? null : linkedSopId ?? this.linkedSopId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


class SupplierProfile {
  final String id;
  final String supplierName;
  final String supplierItem;
  final String contactPerson;
  final String phone;
  final String address;
  final String notes;
  final String unit;
  final double recommendedPurchaseAmount;
  final String recommendedPurchaseFrequency;
  final double pricingPerUnit;
  final double minimumBalanceValue;
  final double maximumBalanceValue;
  final double currentBalanceValue;
  final String lastBalanceUpdatedAt;
  final String lastBalanceUpdatedBy;

  const SupplierProfile({
    required this.id,
    required this.supplierName,
    required this.supplierItem,
    this.contactPerson = '',
    this.phone = '',
    this.address = '',
    this.notes = '',
    required this.unit,
    required this.recommendedPurchaseAmount,
    required this.recommendedPurchaseFrequency,
    required this.pricingPerUnit,
    required this.minimumBalanceValue,
    required this.maximumBalanceValue,
    required this.currentBalanceValue,
    required this.lastBalanceUpdatedAt,
    required this.lastBalanceUpdatedBy,
  });

  String get dropdownLabel => supplierName;

  bool get isBelowMinimumBalance => currentBalanceValue < minimumBalanceValue;

  SupplierProfile copyWith({
    double? currentBalanceValue,
    String? lastBalanceUpdatedAt,
    String? lastBalanceUpdatedBy,
  }) {
    return SupplierProfile(
      id: id,
      supplierName: supplierName,
      supplierItem: supplierItem,
      contactPerson: contactPerson,
      phone: phone,
      address: address,
      notes: notes,
      unit: unit,
      recommendedPurchaseAmount: recommendedPurchaseAmount,
      recommendedPurchaseFrequency: recommendedPurchaseFrequency,
      pricingPerUnit: pricingPerUnit,
      minimumBalanceValue: minimumBalanceValue,
      maximumBalanceValue: maximumBalanceValue,
      currentBalanceValue: currentBalanceValue ?? this.currentBalanceValue,
      lastBalanceUpdatedAt: lastBalanceUpdatedAt ?? this.lastBalanceUpdatedAt,
      lastBalanceUpdatedBy: lastBalanceUpdatedBy ?? this.lastBalanceUpdatedBy,
    );
  }
}




class StockSku {
  final String id;
  final String name;
  final String tag1Id;
  final String category;
  final String tag2Id;
  final String unit;
  final double minimumBalanceValue;
  final double maximumBalanceValue;
  final double currentBalanceValue;
  final int recoveryPercent;
  final double minimumPriceRm;
  final double maximumPriceRm;
  final List<String> supplierIds;
  final String photoPath;
  final List<String> assignedStaffNames;
  final String location;
  final List<String> receivingChecklist;
  final int stockCheckFrequencyDays;
  final String resetTime;
  final String lastUpdatedAt;
  final String lastUpdatedBy;
  final bool active;
  final bool coolingPeriod;

  StockSku({
    required this.id,
    required this.name,
    this.tag1Id = '',
    required this.category,
    this.tag2Id = '',
    required this.unit,
    required this.minimumBalanceValue,
    required this.maximumBalanceValue,
    required this.currentBalanceValue,
    this.recoveryPercent = 100,
    this.minimumPriceRm = 0,
    this.maximumPriceRm = 0,
    required this.supplierIds,
    this.photoPath = '',
    String assignedStaffName = 'Unassigned',
    List<String> assignedStaffNames = const [],
    this.location = '',
    this.receivingChecklist = const [],
    this.stockCheckFrequencyDays = 1,
    this.resetTime = '08:00',
    required this.lastUpdatedAt,
    required this.lastUpdatedBy,
    this.active = true,
    this.coolingPeriod = true,
  }) : assignedStaffNames = _normaliseAssignedStaffNames(
          assignedStaffNames.isNotEmpty ? assignedStaffNames : [assignedStaffName],
        );

  static List<String> _normaliseAssignedStaffNames(Iterable<String> values) {
    final result = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty || value == 'Unassigned') continue;
      if (!result.contains(value)) result.add(value);
    }
    return List.unmodifiable(result);
  }

  String get assignedStaffName => assignedStaffNames.isEmpty ? 'Unassigned' : assignedStaffNames.join(', ');

  bool get hasAssignee => assignedStaffNames.isNotEmpty;

  bool isAssignedTo(String name) => assignedStaffNames.contains(name);

  bool get isBelowMinimumBalance => currentBalanceValue < minimumBalanceValue;

  double get suggestedRestockAmount {
    final targetBalance = maximumBalanceValue * (recoveryPercent / 100);
    final amount = targetBalance - currentBalanceValue;
    return amount < 0 ? 0 : amount;
  }

  StockSku copyWith({
    String? name,
    String? tag1Id,
    String? category,
    String? tag2Id,
    String? unit,
    double? minimumBalanceValue,
    double? maximumBalanceValue,
    double? currentBalanceValue,
    int? recoveryPercent,
    double? minimumPriceRm,
    double? maximumPriceRm,
    List<String>? supplierIds,
    String? photoPath,
    String? assignedStaffName,
    List<String>? assignedStaffNames,
    String? location,
    List<String>? receivingChecklist,
    int? stockCheckFrequencyDays,
    String? resetTime,
    String? lastUpdatedAt,
    String? lastUpdatedBy,
    bool? active,
    bool? coolingPeriod,
  }) {
    final nextAssignedStaffNames = assignedStaffNames ??
        (assignedStaffName == null
            ? this.assignedStaffNames
            : _normaliseAssignedStaffNames([assignedStaffName]));

    return StockSku(
      id: id,
      name: name ?? this.name,
      tag1Id: tag1Id ?? this.tag1Id,
      category: category ?? this.category,
      tag2Id: tag2Id ?? this.tag2Id,
      unit: unit ?? this.unit,
      minimumBalanceValue: minimumBalanceValue ?? this.minimumBalanceValue,
      maximumBalanceValue: maximumBalanceValue ?? this.maximumBalanceValue,
      currentBalanceValue: currentBalanceValue ?? this.currentBalanceValue,
      recoveryPercent: recoveryPercent ?? this.recoveryPercent,
      minimumPriceRm: minimumPriceRm ?? this.minimumPriceRm,
      maximumPriceRm: maximumPriceRm ?? this.maximumPriceRm,
      supplierIds: supplierIds ?? this.supplierIds,
      photoPath: photoPath ?? this.photoPath,
      assignedStaffNames: nextAssignedStaffNames,
      location: location ?? this.location,
      receivingChecklist: receivingChecklist ?? this.receivingChecklist,
      stockCheckFrequencyDays: stockCheckFrequencyDays ?? this.stockCheckFrequencyDays,
      resetTime: resetTime ?? this.resetTime,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      active: active ?? this.active,
      coolingPeriod: coolingPeriod ?? this.coolingPeriod,
    );
  }
}

class StockReceivingItem {
  final String skuId;
  final String skuName;
  final double invoiceQuantity;
  final double receivedQuantity;
  final String unit;
  final String condition;
  final String note;

  const StockReceivingItem({
    required this.skuId,
    required this.skuName,
    required this.invoiceQuantity,
    required this.receivedQuantity,
    required this.unit,
    required this.condition,
    required this.note,
  });
}

class StockReceivingRecord {
  final String id;
  final String supplierId;
  final String supplierName;
  final String receivedBy;
  final String receivedAt;
  final DateTime capturedAt;
  final String invoicePhotoName;
  final String goodsPhotoName;
  final List<StockReceivingItem> items;
  final String reviewStatus;
  final String reviewedBy;
  final String reviewedAt;
  final String reviewNote;

  const StockReceivingRecord({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.receivedBy,
    required this.receivedAt,
    required this.capturedAt,
    required this.invoicePhotoName,
    required this.goodsPhotoName,
    required this.items,
    this.reviewStatus = 'Pending Review',
    this.reviewedBy = '',
    this.reviewedAt = '',
    this.reviewNote = '',
  });

  bool get isApproved => reviewStatus == 'Approved';
  bool get isRejected => reviewStatus == 'Rejected';
  bool get isPendingReview => reviewStatus == 'Pending Review' || reviewStatus == 'Pending';

  StockReceivingRecord copyWith({
    String? reviewStatus,
    String? reviewedBy,
    String? reviewedAt,
    String? reviewNote,
  }) {
    return StockReceivingRecord(
      id: id,
      supplierId: supplierId,
      supplierName: supplierName,
      receivedBy: receivedBy,
      receivedAt: receivedAt,
      capturedAt: capturedAt,
      invoicePhotoName: invoicePhotoName,
      goodsPhotoName: goodsPhotoName,
      items: items,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}

class StockCheckItem {
  final String id;
  final String question;

  const StockCheckItem({
    required this.id,
    required this.question,
  });
}

class StockTask {
  final String id;
  final String title;
  final String supplierId;
  final String supplierName;
  final String createdBy;
  final String createdAt;
  final List<StockCheckItem> checks;

  const StockTask({
    required this.id,
    required this.title,
    required this.supplierId,
    required this.supplierName,
    required this.createdBy,
    required this.createdAt,
    required this.checks,
  });
}

class StockSubmission {
  final String id;
  final String stockTaskId;
  final String skuName;
  final String skuUnit;
  final String skuCategory;
  final String skuLocation;
  final String skuPhotoPath;
  final double skuMinimumBalanceValue;
  final double skuMaximumBalanceValue;
  final String submittedBy;
  final String submittedAt;
  final DateTime capturedAt;
  final String stockPhotoName;
  final String invoicePhotoName;
  final double previousBalanceValue;
  final double currentBalanceValue;
  final bool belowMinimumBalance;
  final Map<String, bool> checkedItems;
  final Map<String, String> remarks;
  final String reviewStatus;
  final String reviewedBy;
  final String reviewedAt;
  final String reviewNote;

  const StockSubmission({
    required this.id,
    required this.stockTaskId,
    this.skuName = '',
    this.skuUnit = '',
    this.skuCategory = '',
    this.skuLocation = '',
    this.skuPhotoPath = '',
    this.skuMinimumBalanceValue = 0,
    this.skuMaximumBalanceValue = 0,
    required this.submittedBy,
    required this.submittedAt,
    required this.capturedAt,
    required this.stockPhotoName,
    required this.invoicePhotoName,
    required this.previousBalanceValue,
    required this.currentBalanceValue,
    required this.belowMinimumBalance,
    required this.checkedItems,
    required this.remarks,
    this.reviewStatus = 'Pending Review',
    this.reviewedBy = '',
    this.reviewedAt = '',
    this.reviewNote = '',
  });

  bool get isApproved => reviewStatus == 'Approved';
  bool get isRejected => reviewStatus == 'Rejected';
  bool get isPendingReview => reviewStatus == 'Pending Review' || reviewStatus == 'Pending';
  double get increasedValue => currentBalanceValue - previousBalanceValue;

  StockSubmission copyWith({
    String? reviewStatus,
    String? reviewedBy,
    String? reviewedAt,
    String? reviewNote,
  }) {
    return StockSubmission(
      id: id,
      stockTaskId: stockTaskId,
      skuName: skuName,
      skuUnit: skuUnit,
      skuCategory: skuCategory,
      skuLocation: skuLocation,
      skuPhotoPath: skuPhotoPath,
      skuMinimumBalanceValue: skuMinimumBalanceValue,
      skuMaximumBalanceValue: skuMaximumBalanceValue,
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      capturedAt: capturedAt,
      stockPhotoName: stockPhotoName,
      invoicePhotoName: invoicePhotoName,
      previousBalanceValue: previousBalanceValue,
      currentBalanceValue: currentBalanceValue,
      belowMinimumBalance: belowMinimumBalance,
      checkedItems: checkedItems,
      remarks: remarks,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}



class StockAuditChange {
  final String field;
  final String oldValue;
  final String newValue;

  const StockAuditChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });
}

class StockAuditEntry {
  final String id;
  final String module;
  final String action;
  final String itemId;
  final String itemName;
  final String actorName;
  final String actorId;
  final String actorRole;
  final String timestampText;
  final DateTime capturedAt;
  final List<StockAuditChange> changes;
  final String note;

  const StockAuditEntry({
    required this.id,
    required this.module,
    required this.action,
    required this.itemId,
    required this.itemName,
    required this.actorName,
    required this.actorId,
    required this.actorRole,
    required this.timestampText,
    required this.capturedAt,
    required this.changes,
    this.note = '',
  });

  bool get hasChanges => changes.isNotEmpty;
}

enum AttendanceStatus {
  notClockedIn,
  working,
  completed,
  suspicious,
}

class WorkLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const WorkLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class AttendanceRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String branchName;
  final String clockInTime;
  final String? clockOutTime;
  final double clockInLatitude;
  final double clockInLongitude;
  final int clockInAccuracyMeters;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final int? clockOutAccuracyMeters;
  final String clockInPhotoName;
  final String? clockOutPhotoName;
  final String deviceName;
  final String deviceStatus;
  final bool serverTimeVerified;
  final bool livePhotoVerified;
  final bool managerReviewRequired;
  final String totalWorkingTime;
  final AttendanceStatus status;
  final String note;

  const AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.branchName,
    required this.clockInTime,
    this.clockOutTime,
    required this.clockInLatitude,
    required this.clockInLongitude,
    required this.clockInAccuracyMeters,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutAccuracyMeters,
    required this.clockInPhotoName,
    this.clockOutPhotoName,
    required this.deviceName,
    required this.deviceStatus,
    required this.serverTimeVerified,
    required this.livePhotoVerified,
    required this.managerReviewRequired,
    required this.totalWorkingTime,
    required this.status,
    required this.note,
  });

  AttendanceRecord copyWith({
    String? clockOutTime,
    double? clockOutLatitude,
    double? clockOutLongitude,
    int? clockOutAccuracyMeters,
    String? clockOutPhotoName,
    bool? managerReviewRequired,
    String? totalWorkingTime,
    AttendanceStatus? status,
    String? note,
  }) {
    return AttendanceRecord(
      id: id,
      staffId: staffId,
      staffName: staffName,
      branchName: branchName,
      clockInTime: clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      clockInLatitude: clockInLatitude,
      clockInLongitude: clockInLongitude,
      clockInAccuracyMeters: clockInAccuracyMeters,
      clockOutLatitude: clockOutLatitude ?? this.clockOutLatitude,
      clockOutLongitude: clockOutLongitude ?? this.clockOutLongitude,
      clockOutAccuracyMeters:
          clockOutAccuracyMeters ?? this.clockOutAccuracyMeters,
      clockInPhotoName: clockInPhotoName,
      clockOutPhotoName: clockOutPhotoName ?? this.clockOutPhotoName,
      deviceName: deviceName,
      deviceStatus: deviceStatus,
      serverTimeVerified: serverTimeVerified,
      livePhotoVerified: livePhotoVerified,
      managerReviewRequired:
          managerReviewRequired ?? this.managerReviewRequired,
      totalWorkingTime: totalWorkingTime ?? this.totalWorkingTime,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}
