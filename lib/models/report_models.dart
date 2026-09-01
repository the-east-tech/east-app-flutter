import 'task_models.dart';

class ReportDashboard {
  final DateTime asOfDate;
  final int periodDays;
  final bool managementView;
  final SalesOverview? sales;
  final PeriodCountCoverage? countCoverage;
  final WorkforceIntelligence? workforce;
  final InventoryIntelligence? inventory;
  final WasteOverview? waste;
  final DailyPhotoOverview dailyPhotos;
  final TaskOverview tasks;
  final ComplaintOverview? complaints;
  final int pendingApprovals;
  final List<ReportTrendPoint> trend;

  const ReportDashboard({
    required this.asOfDate,
    required this.periodDays,
    required this.managementView,
    required this.sales,
    required this.countCoverage,
    required this.workforce,
    required this.inventory,
    required this.waste,
    required this.dailyPhotos,
    required this.tasks,
    required this.complaints,
    required this.pendingApprovals,
    required this.trend,
  });

  factory ReportDashboard.fromJson(Map<String, dynamic> json) {
    return ReportDashboard(
      asOfDate: DateTime.parse(json['asOfDate'] as String),
      periodDays: (json['periodDays'] as num).toInt(),
      managementView: json['managementView'] as bool,
      sales: json['sales'] == null
          ? null
          : SalesOverview.fromJson(json['sales'] as Map<String, dynamic>),
      countCoverage: json['countCoverage'] == null
          ? null
          : PeriodCountCoverage.fromJson(
              json['countCoverage'] as Map<String, dynamic>,
            ),
      workforce: json['workforce'] == null
          ? null
          : WorkforceIntelligence.fromJson(
              json['workforce'] as Map<String, dynamic>,
            ),
      inventory: json['inventory'] == null
          ? null
          : InventoryIntelligence.fromJson(
              json['inventory'] as Map<String, dynamic>,
            ),
      waste: json['waste'] == null
          ? null
          : WasteOverview.fromJson(json['waste'] as Map<String, dynamic>),
      dailyPhotos: DailyPhotoOverview.fromJson(
        json['dailyPhotos'] as Map<String, dynamic>,
      ),
      tasks: json['tasks'] is Map<String, dynamic>
          ? TaskOverview.fromJson(
              json['tasks'] as Map<String, dynamic>,
            )
          : TaskOverview.empty,
      complaints: json['complaints'] == null
          ? null
          : ComplaintOverview.fromJson(
              json['complaints'] as Map<String, dynamic>,
            ),
      pendingApprovals: (json['pendingApprovals'] as num).toInt(),
      trend: (json['trend'] as List<dynamic>? ?? const [])
          .map((item) => ReportTrendPoint.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class SalesOverview {
  final double grossSalesRm;
  final double netSalesRm;
  final double grossFoodDeliverySalesRm;
  final double netFoodDeliverySalesRm;
  final double estimatedPlatformCommissionRm;
  final double voidTotalRm;
  final double salesPerStaffRm;
  final double averageSalesPerReportingDayRm;
  final double voidRatePercent;
  final double versusPreviousPeriodPercent;
  final double averageStaffPerReportedDay;
  final int reportedDayCount;
  final bool submittedToday;

  const SalesOverview({
    required this.grossSalesRm,
    required this.netSalesRm,
    required this.grossFoodDeliverySalesRm,
    required this.netFoodDeliverySalesRm,
    required this.estimatedPlatformCommissionRm,
    required this.voidTotalRm,
    required this.salesPerStaffRm,
    required this.averageSalesPerReportingDayRm,
    required this.voidRatePercent,
    required this.versusPreviousPeriodPercent,
    required this.averageStaffPerReportedDay,
    required this.reportedDayCount,
    required this.submittedToday,
  });

  factory SalesOverview.fromJson(Map<String, dynamic> json) {
    return SalesOverview(
      grossSalesRm: _double(json['grossSalesRm']),
      netSalesRm: _double(json['netSalesRm']),
      grossFoodDeliverySalesRm: _double(json['grossFoodDeliverySalesRm']),
      netFoodDeliverySalesRm: _double(json['netFoodDeliverySalesRm']),
      estimatedPlatformCommissionRm: _double(
        json['estimatedPlatformCommissionRm'],
      ),
      voidTotalRm: _double(json['voidTotalRm']),
      salesPerStaffRm: _double(json['salesPerStaffRm']),
      averageSalesPerReportingDayRm: _double(
        json['averageSalesPerReportingDayRm'] ?? json['averageDailySalesRm'],
      ),
      voidRatePercent: _double(json['voidRatePercent']),
      versusPreviousPeriodPercent: _double(
        json['versusPreviousPeriodPercent'],
      ),
      averageStaffPerReportedDay: _double(
        json['averageStaffPerReportedDay'],
      ),
      reportedDayCount: (json['reportedDayCount'] as num).toInt(),
      submittedToday: json['submittedToday'] as bool,
    );
  }
}

class PeriodCountCoverage {
  final double countCoveragePercent;
  final int countedSkuDays;
  final int expectedSkuDays;
  final int missingCountSkuDays;

  const PeriodCountCoverage({
    required this.countCoveragePercent,
    required this.countedSkuDays,
    required this.expectedSkuDays,
    required this.missingCountSkuDays,
  });

  factory PeriodCountCoverage.fromJson(Map<String, dynamic> json) {
    return PeriodCountCoverage(
      countCoveragePercent: _double(json['countCoveragePercent']),
      countedSkuDays: (json['countedSkuDays'] as num).toInt(),
      expectedSkuDays: (json['expectedSkuDays'] as num).toInt(),
      missingCountSkuDays: (json['missingCountSkuDays'] as num).toInt(),
    );
  }
}

class WorkforceIntelligence {
  final double totalLabourHours;
  final double salesPerLabourHourRm;
  final double averageStaffPerDay;
  final int completedShiftCount;
  final int openShiftCount;
  final int operatingDayCount;
  final int staffCountMismatchDays;

  const WorkforceIntelligence({
    required this.totalLabourHours,
    required this.salesPerLabourHourRm,
    required this.averageStaffPerDay,
    required this.completedShiftCount,
    required this.openShiftCount,
    required this.operatingDayCount,
    required this.staffCountMismatchDays,
  });

  factory WorkforceIntelligence.fromJson(Map<String, dynamic> json) {
    return WorkforceIntelligence(
      totalLabourHours: _double(json['totalLabourHours']),
      salesPerLabourHourRm: _double(json['salesPerLabourHourRm']),
      averageStaffPerDay: _double(json['averageStaffPerDay']),
      completedShiftCount: (json['completedShiftCount'] as num).toInt(),
      openShiftCount: (json['openShiftCount'] as num).toInt(),
      operatingDayCount: (json['operatingDayCount'] as num).toInt(),
      staffCountMismatchDays: (json['staffCountMismatchDays'] as num).toInt(),
    );
  }
}

class InventoryIntelligence {
  final int activeSkuCount;
  final int healthySkuCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int overstockCount;
  final double estimatedStockValueRm;
  final double estimatedReorderInvestmentRm;
  final double estimatedOverstockCapitalRm;
  final double healthScorePercent;
  final List<InventoryRisk> topRisks;

  const InventoryIntelligence({
    required this.activeSkuCount,
    required this.healthySkuCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.overstockCount,
    required this.estimatedStockValueRm,
    required this.estimatedReorderInvestmentRm,
    required this.estimatedOverstockCapitalRm,
    required this.healthScorePercent,
    required this.topRisks,
  });

  factory InventoryIntelligence.fromJson(Map<String, dynamic> json) {
    return InventoryIntelligence(
      activeSkuCount: (json['activeSkuCount'] as num).toInt(),
      healthySkuCount: (json['healthySkuCount'] as num).toInt(),
      lowStockCount: (json['lowStockCount'] as num).toInt(),
      outOfStockCount: (json['outOfStockCount'] as num).toInt(),
      overstockCount: (json['overstockCount'] as num).toInt(),
      estimatedStockValueRm: _double(json['estimatedStockValueRm']),
      estimatedReorderInvestmentRm: _double(
        json['estimatedReorderInvestmentRm'],
      ),
      estimatedOverstockCapitalRm: _double(
        json['estimatedOverstockCapitalRm'],
      ),
      healthScorePercent: _double(json['healthScorePercent']),
      topRisks: (json['topRisks'] as List<dynamic>? ?? const [])
          .map((item) => InventoryRisk.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class InventoryRisk {
  final String skuId;
  final String skuName;
  final String severity;
  final double currentBalance;
  final double minimumBalance;
  final double maximumBalance;
  final double estimatedValueAtRiskRm;
  final String insight;

  const InventoryRisk({
    required this.skuId,
    required this.skuName,
    required this.severity,
    required this.currentBalance,
    required this.minimumBalance,
    required this.maximumBalance,
    required this.estimatedValueAtRiskRm,
    required this.insight,
  });

  factory InventoryRisk.fromJson(Map<String, dynamic> json) {
    return InventoryRisk(
      skuId: json['skuId'] as String,
      skuName: json['skuName'] as String,
      severity: json['severity'] as String,
      currentBalance: _double(json['currentBalance']),
      minimumBalance: _double(json['minimumBalance']),
      maximumBalance: _double(json['maximumBalance']),
      estimatedValueAtRiskRm: _double(json['estimatedValueAtRiskRm']),
      insight: json['insight'] as String,
    );
  }
}

class WasteOverview {
  final double todayLossRm;
  final double periodLossRm;
  final double wasteToNetSalesPercent;
  final String topWasteItem;
  final double topWasteItemLossRm;

  const WasteOverview({
    required this.todayLossRm,
    required this.periodLossRm,
    required this.wasteToNetSalesPercent,
    required this.topWasteItem,
    required this.topWasteItemLossRm,
  });

  factory WasteOverview.fromJson(Map<String, dynamic> json) {
    return WasteOverview(
      todayLossRm: _double(json['todayLossRm']),
      periodLossRm: _double(json['periodLossRm']),
      wasteToNetSalesPercent: _double(json['wasteToNetSalesPercent']),
      topWasteItem: json['topWasteItem'] as String,
      topWasteItemLossRm: _double(json['topWasteItemLossRm']),
    );
  }
}

class DailyPhotoOverview {
  final int currentUserPhotoCount;
  final int minimumRequired;
  final bool currentUserComplete;
  final int requiredStaffCount;
  final int completedStaffCount;
  final double completionRatePercent;

  const DailyPhotoOverview({
    required this.currentUserPhotoCount,
    required this.minimumRequired,
    required this.currentUserComplete,
    required this.requiredStaffCount,
    required this.completedStaffCount,
    required this.completionRatePercent,
  });

  factory DailyPhotoOverview.fromJson(Map<String, dynamic> json) {
    return DailyPhotoOverview(
      currentUserPhotoCount: (json['currentUserPhotoCount'] as num).toInt(),
      minimumRequired: (json['minimumRequired'] as num).toInt(),
      currentUserComplete: json['currentUserComplete'] as bool,
      requiredStaffCount: (json['requiredStaffCount'] as num).toInt(),
      completedStaffCount: (json['completedStaffCount'] as num).toInt(),
      completionRatePercent: _double(json['completionRatePercent']),
    );
  }
}

class ComplaintOverview {
  final int openCount;
  final int resolvedInPeriod;
  final double resolutionRatePercent;
  final double compensationInPeriodRm;

  const ComplaintOverview({
    required this.openCount,
    required this.resolvedInPeriod,
    required this.resolutionRatePercent,
    required this.compensationInPeriodRm,
  });

  factory ComplaintOverview.fromJson(Map<String, dynamic> json) {
    return ComplaintOverview(
      openCount: (json['openCount'] as num).toInt(),
      resolvedInPeriod: (json['resolvedInPeriod'] as num).toInt(),
      resolutionRatePercent: _double(json['resolutionRatePercent']),
      compensationInPeriodRm: _double(json['compensationInPeriodRm']),
    );
  }
}

class ReportTrendPoint {
  final DateTime date;
  final double netSalesRm;
  final double voidAmountRm;
  final double wasteLossRm;

  const ReportTrendPoint({
    required this.date,
    required this.netSalesRm,
    required this.voidAmountRm,
    required this.wasteLossRm,
  });

  factory ReportTrendPoint.fromJson(Map<String, dynamic> json) {
    return ReportTrendPoint(
      date: DateTime.parse(json['date'] as String),
      netSalesRm: _double(json['netSalesRm']),
      voidAmountRm: _double(json['voidAmountRm']),
      wasteLossRm: _double(json['wasteLossRm']),
    );
  }
}

class SalesReport {
  final String? id;
  final DateTime reportDate;
  final String workflowStatus;
  final double cashTotalRm;
  final String cashReceivedBy;
  final double foodDeliverySalesRm;
  final double netFoodDeliverySalesRm;
  final double estimatedPlatformCommissionRm;
  final double ewalletTotalRm;
  final double totalSalesRm;
  final double voidTotalRm;
  final int staffOnDuty;
  final double salesPerStaffRm;
  final double voidExposurePercent;
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? reviewedByName;
  final String? reviewNote;
  final List<VoidBill> voidBills;

  const SalesReport({
    required this.id,
    required this.reportDate,
    required this.workflowStatus,
    required this.cashTotalRm,
    required this.cashReceivedBy,
    required this.foodDeliverySalesRm,
    required this.netFoodDeliverySalesRm,
    required this.estimatedPlatformCommissionRm,
    required this.ewalletTotalRm,
    required this.totalSalesRm,
    required this.voidTotalRm,
    required this.staffOnDuty,
    required this.salesPerStaffRm,
    required this.voidExposurePercent,
    required this.submittedByName,
    required this.submittedAt,
    required this.reviewedByName,
    required this.reviewNote,
    required this.voidBills,
  });

  bool get isEditable => workflowStatus == 'DRAFT' || workflowStatus == 'REJECTED';
  bool get canSubmit => id != null && isEditable && staffOnDuty > 0;

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      id: json['id'] as String?,
      reportDate: DateTime.parse(json['reportDate'] as String),
      workflowStatus: json['workflowStatus'] as String,
      cashTotalRm: _double(json['cashTotalRm']),
      cashReceivedBy: json['cashReceivedBy'] as String? ?? '',
      foodDeliverySalesRm: _double(json['foodDeliverySalesRm']),
      netFoodDeliverySalesRm: _double(json['netFoodDeliverySalesRm']),
      estimatedPlatformCommissionRm: _double(
        json['estimatedPlatformCommissionRm'],
      ),
      ewalletTotalRm: _double(json['ewalletTotalRm']),
      totalSalesRm: _double(json['totalSalesRm']),
      voidTotalRm: _double(json['voidTotalRm']),
      staffOnDuty: (json['staffOnDuty'] as num).toInt(),
      salesPerStaffRm: _double(json['salesPerStaffRm']),
      voidExposurePercent: _double(json['voidExposurePercent']),
      submittedByName: json['submittedByName'] as String?,
      submittedAt: _dateTime(json['submittedAt']),
      reviewedByName: json['reviewedByName'] as String?,
      reviewNote: json['reviewNote'] as String?,
      voidBills: (json['voidBills'] as List<dynamic>? ?? const [])
          .map((item) => VoidBill.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class VoidBill {
  final String id;
  final String billNumber;
  final String reason;
  final double amountRm;
  final String photoStorageKey;
  final String createdByName;
  final DateTime createdAt;

  const VoidBill({
    required this.id,
    required this.billNumber,
    required this.reason,
    required this.amountRm,
    required this.photoStorageKey,
    required this.createdByName,
    required this.createdAt,
  });

  factory VoidBill.fromJson(Map<String, dynamic> json) {
    return VoidBill(
      id: json['id'] as String,
      billNumber: json['billNumber'] as String,
      reason: json['reason'] as String,
      amountRm: _double(json['amountRm']),
      photoStorageKey: json['photoStorageKey'] as String,
      createdByName: json['createdByName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class WasteReport {
  final String id;
  final DateTime reportDate;
  final String workflowStatus;
  final String? skuId;
  final String itemName;
  final double quantity;
  final String unit;
  final double estimatedUnitCostRm;
  final double estimatedLossRm;
  final String reason;
  final String photoStorageKey;
  final String submittedByName;
  final DateTime? submittedAt;
  final String? reviewedByName;
  final String? reviewNote;

  const WasteReport({
    required this.id,
    required this.reportDate,
    required this.workflowStatus,
    required this.skuId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.estimatedUnitCostRm,
    required this.estimatedLossRm,
    required this.reason,
    required this.photoStorageKey,
    required this.submittedByName,
    required this.submittedAt,
    required this.reviewedByName,
    required this.reviewNote,
  });

  factory WasteReport.fromJson(Map<String, dynamic> json) {
    return WasteReport(
      id: json['id'] as String,
      reportDate: DateTime.parse(json['reportDate'] as String),
      workflowStatus: json['workflowStatus'] as String,
      skuId: json['skuId'] as String?,
      itemName: json['itemName'] as String,
      quantity: _double(json['quantity']),
      unit: json['unit'] as String,
      estimatedUnitCostRm: _double(json['estimatedUnitCostRm']),
      estimatedLossRm: _double(json['estimatedLossRm']),
      reason: json['reason'] as String,
      photoStorageKey: json['photoStorageKey'] as String,
      submittedByName: json['submittedByName'] as String,
      submittedAt: _dateTime(json['submittedAt']),
      reviewedByName: json['reviewedByName'] as String?,
      reviewNote: json['reviewNote'] as String?,
    );
  }
}

class DailyPhotoReport {
  final String? id;
  final DateTime reportDate;
  final String workflowStatus;
  final String userId;
  final String userName;
  final int photoCount;
  final int minimumRequired;
  final bool requirementMet;
  final DateTime? submittedAt;
  final String? reviewedByName;
  final String? reviewNote;
  final List<DailyPhotoItem> photos;

  const DailyPhotoReport({
    required this.id,
    required this.reportDate,
    required this.workflowStatus,
    required this.userId,
    required this.userName,
    required this.photoCount,
    required this.minimumRequired,
    required this.requirementMet,
    required this.submittedAt,
    required this.reviewedByName,
    required this.reviewNote,
    required this.photos,
  });

  bool get isEditable => workflowStatus == 'DRAFT' || workflowStatus == 'REJECTED';

  factory DailyPhotoReport.fromJson(Map<String, dynamic> json) {
    return DailyPhotoReport(
      id: json['id'] as String?,
      reportDate: DateTime.parse(json['reportDate'] as String),
      workflowStatus: json['workflowStatus'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      photoCount: (json['photoCount'] as num).toInt(),
      minimumRequired: (json['minimumRequired'] as num).toInt(),
      requirementMet: json['requirementMet'] as bool,
      submittedAt: _dateTime(json['submittedAt']),
      reviewedByName: json['reviewedByName'] as String?,
      reviewNote: json['reviewNote'] as String?,
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((item) => DailyPhotoItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class DailyPhotoItem {
  final String id;
  final String photoStorageKey;
  final DateTime createdAt;

  const DailyPhotoItem({
    required this.id,
    required this.photoStorageKey,
    required this.createdAt,
  });

  factory DailyPhotoItem.fromJson(Map<String, dynamic> json) {
    return DailyPhotoItem(
      id: json['id'] as String,
      photoStorageKey: json['photoStorageKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ComplaintReport {
  final String id;
  final DateTime reportDate;
  final String status;
  final String photoStorageKey;
  final String customerGender;
  final int estimatedAge;
  final String complaintInfo;
  final String? phoneE164;
  final String actionTaken;
  final double? compensationAmountRm;
  final String submittedByName;
  final DateTime? submittedAt;
  final DateTime? resolvedAt;

  const ComplaintReport({
    required this.id,
    required this.reportDate,
    required this.status,
    required this.photoStorageKey,
    required this.customerGender,
    required this.estimatedAge,
    required this.complaintInfo,
    required this.phoneE164,
    required this.actionTaken,
    required this.compensationAmountRm,
    required this.submittedByName,
    required this.submittedAt,
    required this.resolvedAt,
  });

  factory ComplaintReport.fromJson(Map<String, dynamic> json) {
    return ComplaintReport(
      id: json['id'] as String,
      reportDate: DateTime.parse(json['reportDate'] as String),
      status: json['status'] as String,
      photoStorageKey: json['photoStorageKey'] as String,
      customerGender: json['customerGender'] as String,
      estimatedAge: (json['estimatedAge'] as num).toInt(),
      complaintInfo: json['complaintInfo'] as String,
      phoneE164: json['phoneE164'] as String?,
      actionTaken: json['actionTaken'] as String,
      compensationAmountRm: json['compensationAmountRm'] == null
          ? null
          : _double(json['compensationAmountRm']),
      submittedByName: json['submittedByName'] as String,
      submittedAt: _dateTime(json['submittedAt']),
      resolvedAt: _dateTime(json['resolvedAt']),
    );
  }
}

class ReportApproval {
  final String id;
  final String reportType;
  final DateTime reportDate;
  final String submittedByUserId;
  final String submittedByName;
  final DateTime submittedAt;
  final String summary;
  final double amountRm;
  final int evidenceCount;

  const ReportApproval({
    required this.id,
    required this.reportType,
    required this.reportDate,
    required this.submittedByUserId,
    required this.submittedByName,
    required this.submittedAt,
    required this.summary,
    required this.amountRm,
    required this.evidenceCount,
  });

  factory ReportApproval.fromJson(Map<String, dynamic> json) {
    return ReportApproval(
      id: json['id'] as String,
      reportType: json['reportType'] as String,
      reportDate: DateTime.parse(json['reportDate'] as String),
      submittedByUserId: json['submittedByUserId'] as String,
      submittedByName: json['submittedByName'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      summary: json['summary'] as String,
      amountRm: _double(json['amountRm']),
      evidenceCount: (json['evidenceCount'] as num).toInt(),
    );
  }
}

double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

DateTime? _dateTime(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}
