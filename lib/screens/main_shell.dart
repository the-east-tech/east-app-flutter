import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_data.dart';
import '../localization/app_language.dart';
import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/api_models.dart';
import '../models/auth_models.dart';
import '../models/people_models.dart';
import '../models/points_models.dart';
import '../models/organisation_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../utils/app_diagnostics.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import 'attendance_screen.dart';
import 'home_screen.dart';
import 'knowledge_screen.dart';
import 'ranking_screen.dart';
import 'rewards_screen.dart';
import 'stock_screen.dart';
import 'report_screen.dart';

class MainShell extends StatefulWidget {
  final UserRole role;
  final EastAppSession session;
  final EastAppApi api;
  final Future<void> Function() onLogout;
  final ValueChanged<EastAppSession> onSessionChanged;
  final ValueChanged<EastAppUser> onCurrentUserChanged;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final AppLanguage initialLanguage;

  const MainShell({
    super.key,
    required this.role,
    required this.session,
    required this.api,
    required this.onLogout,
    required this.onSessionChanged,
    required this.onCurrentUserChanged,
    required this.onLanguageChanged,
    this.initialLanguage = AppLanguage.english,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;
  late AppLanguage language;
  late List<StaffTask> tasks;
  late List<KnowledgeItem> knowledge;
  late List<StockTag> stockTags;
  late List<StockTask> stockTasks;
  late List<StockSubmission> stockSubmissions;
  late List<StockSku> stockSkus;
  late List<StockReceivingRecord> stockReceivingRecords;
  late List<StockAuditEntry> stockAuditEntries;
  late List<SupplierProfile> suppliers;
  late List<AttendanceRecord> attendanceRecords;
  int stockTagPage = -1;
  int stockSupplierPage = -1;
  int stockSkuPage = -1;
  int stockCountPage = -1;
  int stockReceivingPage = -1;
  bool stockTagsLast = false;
  bool stockSuppliersLast = false;
  bool stockSkusLast = false;
  bool stockCountsLast = false;
  bool stockReceivingsLast = false;
  DateTime? stockTagsUpdatedAt;
  DateTime? stockSuppliersUpdatedAt;
  DateTime? stockSkusUpdatedAt;
  bool? stockCountsMine;
  bool knowledgeLoaded = false;
  bool knowledgeLoading = false;
  int stockResetSignal = 0;
  int homeRefreshSignal = 0;
  int pageSlideDirection = 1;
  double mainSwipeStartX = 0;
  double mainSwipeDeltaX = 0;
  EastAppLeaderboard? pointsLeaderboard;
  Future<EastAppLeaderboard>? pointsLeaderboardRequest;
  StockPage? requestedStockPage;
  bool requestedStockPageBackToHome = false;

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
    tasks = List<StaffTask>.from(sampleTasks);
    knowledge = <KnowledgeItem>[];
    stockTags = <StockTag>[];
    stockTasks = <StockTask>[];
    stockSubmissions = <StockSubmission>[];
    stockSkus = <StockSku>[];
    stockReceivingRecords = <StockReceivingRecord>[];
    stockAuditEntries = <StockAuditEntry>[];
    suppliers = <SupplierProfile>[];
    attendanceRecords = List<AttendanceRecord>.from(sampleAttendanceRecords);
    unawaited(loadPointsLeaderboard());
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.tenant.id != widget.session.tenant.id ||
        oldWidget.session.user.id != widget.session.user.id) {
      pointsLeaderboard = null;
      pointsLeaderboardRequest = null;
      unawaited(loadPointsLeaderboard());
    }
  }

  Future<EastAppLeaderboard?> loadPointsLeaderboard() async {
    final existingRequest = pointsLeaderboardRequest;
    if (existingRequest != null) {
      return existingRequest;
    }

    late final Future<EastAppLeaderboard> request;
    request = widget.api.pointsLeaderboard();
    pointsLeaderboardRequest = request;
    try {
      final value = await request;
      if (!mounted) return value;
      setState(() => pointsLeaderboard = value);
      return value;
    } on EastAppApiException {
      return pointsLeaderboard;
    } finally {
      if (identical(pointsLeaderboardRequest, request)) {
        pointsLeaderboardRequest = null;
      }
    }
  }

  void handlePointsChanged(EastAppLeaderboard value) {
    if (!mounted) return;
    setState(() => pointsLeaderboard = value);
  }

  void openStockReviewFromHome() {
    AppFeedback.select();
    setState(() {
      pageSlideDirection = 1;
      requestedStockPage = StockPage.review;
      requestedStockPageBackToHome = true;
      selectedIndex = 2;
    });
  }

  void consumeRequestedStockPage() {
    if (requestedStockPage == null) return;
    setState(() => requestedStockPage = null);
  }

  void exitStockToMainHome() {
    setState(() {
      pageSlideDirection = -1;
      requestedStockPage = null;
      requestedStockPageBackToHome = false;
      homeRefreshSignal++;
      selectedIndex = 0;
    });
  }

  Future<void> loadStockTags({
    bool reset = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !reset && stockTagPage >= 0 && stockTagsLast) return;
    final nextPage = reset || forceRefresh ? 0 : stockTagPage + 1;
    final query = Uri(queryParameters: {'page': '$nextPage', 'size': '100'}).query;
    final cacheKey = '${EastAppApi.stockTagsCachePrefix(widget.session.tenant.id)}$query';
    final result = await widget.api.stockTags(
      page: nextPage,
      size: 100,
      tenantId: widget.session.tenant.id,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      stockTags = nextPage == 0
          ? List<StockTag>.from(result.content)
          : [...stockTags, ...result.content];
      stockTagPage = result.page;
      stockTagsLast = result.last;
      stockTagsUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
    });
  }

  Future<void> loadKnowledgeData({bool forceRefresh = false}) async {
    if (knowledgeLoading || (!forceRefresh && knowledgeLoaded)) return;
    knowledgeLoading = true;
    try {
      final results = await Future.wait<Object?>([
        widget.api.stockTags(
          page: 0,
          size: 100,
          tenantId: widget.session.tenant.id,
        ),
        widget.api.knowledgeSops(page: 0, size: 100),
      ]);
      if (!mounted) return;
      final tagPage = results[0] as EastAppPage<StockTag>;
      final sopPage = results[1] as EastAppPage<KnowledgeItem>;
      setState(() {
        stockTags = List<StockTag>.from(tagPage.content);
        stockTagPage = tagPage.page;
        stockTagsLast = tagPage.last;
        knowledge = List<KnowledgeItem>.from(sopPage.content);
        knowledgeLoaded = true;
      });
    } on EastAppApiException {
      // The global API error handler already displays the request failure.
    } finally {
      knowledgeLoading = false;
    }
  }

  Future<void> loadStockSuppliers({
    bool reset = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !reset && stockSupplierPage >= 0 && stockSuppliersLast) return;
    final nextPage = reset || forceRefresh ? 0 : stockSupplierPage + 1;
    final query = Uri(queryParameters: {'page': '$nextPage', 'size': '50'}).query;
    final cacheKey = '${EastAppApi.stockSuppliersCachePrefix(widget.session.tenant.id)}$query';
    final result = await widget.api.stockSuppliers(
      page: nextPage,
      size: 50,
      tenantId: widget.session.tenant.id,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      suppliers = nextPage == 0
          ? List<SupplierProfile>.from(result.content)
          : [...suppliers, ...result.content];
      stockSupplierPage = result.page;
      stockSuppliersLast = result.last;
      stockSuppliersUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
    });
  }

  Future<void> loadStockSkus({
    bool reset = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !reset && stockSkuPage >= 0 && stockSkusLast) return;
    final nextPage = reset || forceRefresh ? 0 : stockSkuPage + 1;
    final query = Uri(queryParameters: {'page': '$nextPage', 'size': '50'}).query;
    final cacheKey = '${EastAppApi.stockSkusCachePrefix(widget.session.tenant.id)}$query';
    final result = await widget.api.stockSkus(
      page: nextPage,
      size: 50,
      tenantId: widget.session.tenant.id,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      stockSkus = nextPage == 0
          ? List<StockSku>.from(result.content)
          : [...stockSkus, ...result.content];
      stockSkuPage = result.page;
      stockSkusLast = result.last;
      stockSkusUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
    });
  }

  Future<void> loadStockCounts({
    required bool mine,
    bool reset = false,
  }) async {
    final scopeChanged = stockCountsMine != null && stockCountsMine != mine;
    final shouldReset = reset || scopeChanged;
    if (!shouldReset && stockCountPage >= 0 && stockCountsLast) return;
    final nextPage = shouldReset ? 0 : stockCountPage + 1;
    final result = await widget.api.stockCounts(
      mine: mine,
      page: nextPage,
      size: 50,
    );
    if (!mounted) return;
    setState(() {
      stockSubmissions = shouldReset
          ? List<StockSubmission>.from(result.content)
          : [...stockSubmissions, ...result.content];
      stockCountPage = result.page;
      stockCountsLast = result.last;
      stockCountsMine = mine;
    });
  }

  Future<void> loadStockReceivings({bool reset = false}) async {
    if (!reset && stockReceivingPage >= 0 && stockReceivingsLast) return;
    final nextPage = reset ? 0 : stockReceivingPage + 1;
    final result = await widget.api.stockReceivings(page: nextPage, size: 50);
    if (!mounted) return;
    setState(() {
      stockReceivingRecords = reset
          ? List<StockReceivingRecord>.from(result.content)
          : [...stockReceivingRecords, ...result.content];
      stockReceivingPage = result.page;
      stockReceivingsLast = result.last;
    });
  }

  Future<String?> loadStockPageData(StockPage page) async {
    try {
      switch (page) {
        case StockPage.dailyCount:
          await Future.wait([
            loadStockSkus(reset: stockSkuPage < 0),
            loadStockCounts(
              mine: widget.role == UserRole.staff,
              reset: stockCountPage < 0 ||
                  stockCountsMine != (widget.role == UserRole.staff),
            ),
          ]);
          break;
        case StockPage.receiving:
        case StockPage.restockMessage:
          await Future.wait([
            loadStockSuppliers(reset: stockSupplierPage < 0),
            loadStockSkus(reset: stockSkuPage < 0),
          ]);
          break;
        case StockPage.review:
          // On-demand: Review loads only after Status + Date + Search.
          break;
        case StockPage.skuSetup:
          await Future.wait([
            loadStockTags(reset: stockTagPage < 0),
            loadStockSuppliers(reset: stockSupplierPage < 0),
            loadStockSkus(reset: stockSkuPage < 0),
          ]);
          break;
        case StockPage.supplierSetup:
          await loadStockSuppliers(reset: stockSupplierPage < 0);
          break;
        case StockPage.tagSetup:
          await loadStockTags(reset: stockTagPage < 0);
          break;
        case StockPage.assigneeSetup:
          // On-demand: Assignee loads only after Assigned/Unassigned + Load.
          break;
        case StockPage.auditTrail:
        case StockPage.home:
          break;
      }
      return null;
    } on EastAppApiException catch (error) {
      return error.message;
    }
  }

  Future<EastAppPage<StockAuditEntry>> loadStockAuditEntries(
    DateTime rangeStart,
    DateTime rangeEnd,
    int page,
    int size,
  ) {
    return widget.api.stockAudit(
      from: rangeStart,
      to: rangeEnd,
      page: page,
      size: size,
    );
  }

  void goToTab(int index) {
    AppFeedback.select();
    setState(() {
      pageSlideDirection = index >= selectedIndex ? 1 : -1;
      if (index == 0) {
        homeRefreshSignal++;
        unawaited(loadPointsLeaderboard());
      }
      if (index == 1 && stockSkuPage < 0) {
        unawaited(loadStockSkus(reset: true));
      }
      if (index == 2 && selectedIndex == 2) {
        stockResetSignal++;
      }
      selectedIndex = index;
    });
    if (index == 4) {
      unawaited(loadKnowledgeData());
    }
  }

  void changeLanguage(AppLanguage value) {
    setState(() {
      language = value;
    });
    widget.onLanguageChanged(value);
  }

  void submitTask({
    required StaffTask task,
    required String remark,
  }) {
    setState(() {
      tasks = tasks.map((item) {
        if (item.id != task.id) return item;

        return item.copyWith(
          status: RewardTaskStatus.submitted,
          submittedText: 'Submitted just now',
          photoEvidenceName: '${task.id.toLowerCase()}_photo.jpg',
          staffRemark:
              remark.trim().isEmpty ? 'No additional remarks.' : remark.trim(),
        );
      }).toList();
    });
  }

  void approveTask({
    required StaffTask task,
    required int score,
  }) {
    setState(() {
      tasks = tasks.map((item) {
        if (item.id != task.id) return item;

        return item.copyWith(
          status: RewardTaskStatus.approved,
          awardedScore: score,
          approvedText: '+$score points earned',
          approvedBy: managerId,
        );
      }).toList();
    });
  }

  void rejectTask({
    required StaffTask task,
    required String reason,
  }) {
    setState(() {
      tasks = tasks.map((item) {
        if (item.id != task.id) return item;

        return item.copyWith(
          status: RewardTaskStatus.rejected,
          awardedScore: 0,
          rejectedText: reason.trim().isEmpty
              ? 'Rejected by manager. Please resubmit.'
              : reason.trim(),
          approvedBy: managerId,
        );
      }).toList();
    });
  }

  Future<KnowledgeItem> createSop(KnowledgeItem item) async {
    final saved = await widget.api.createKnowledgeSop(item);
    if (!mounted) return saved;
    setState(() {
      knowledge = [saved, ...knowledge.where((entry) => entry.id != saved.id)];
      knowledgeLoaded = true;
    });
    return saved;
  }

  void createStockTag(StockTag tag) {
    setState(() {
      stockTags = [tag, ...stockTags];
    });
  }

  void updateStockTag(StockTag updatedTag) {
    final existingTag = stockTags.firstWhere((tag) => tag.id == updatedTag.id);
    setState(() {
      stockTags = stockTags
          .map((tag) => tag.id == updatedTag.id ? updatedTag : tag)
          .toList();
      stockSkus = stockSkus.map((sku) {
        final nextCategory = sku.category == existingTag.tag
            ? updatedTag.tag
            : sku.category;
        final nextLocation = sku.location == existingTag.tag
            ? updatedTag.tag
            : sku.location;
        if (nextCategory == sku.category && nextLocation == sku.location) {
          return sku;
        }
        return sku.copyWith(
          category: nextCategory,
          location: nextLocation,
        );
      }).toList();
    });
  }

  bool deleteStockTags(Set<String> tagIds) {
    final selectedTags = stockTags.where((tag) => tagIds.contains(tag.id)).toList();
    final selectedNames = selectedTags.map((tag) => tag.tag).toSet();
    final assignedToSop = knowledge.any((item) => tagIds.contains(item.tagId));
    final assignedToSku = stockSkus.any(
      (sku) => selectedNames.contains(sku.category) || selectedNames.contains(sku.location),
    );
    if (assignedToSop || assignedToSku) return false;

    setState(() {
      stockTags = stockTags.where((tag) => !tagIds.contains(tag.id)).toList();
    });
    return true;
  }

  String auditTimestamp() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return 'Today $hour:$minute';
  }

  String formatAuditValue(Object? value) {
    if (value == null) return '-';
    if (value is String) return value.trim().isEmpty ? '-' : value.trim();
    if (value is double) {
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
    }
    if (value is int) return value.toString();
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is Iterable) {
      final values = value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
      return values.isEmpty ? '-' : values.join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  bool sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  void addAuditChange(
    List<StockAuditChange> changes,
    String field,
    Object? oldValue,
    Object? newValue,
  ) {
    final before = formatAuditValue(oldValue);
    final after = formatAuditValue(newValue);
    if (before == after) return;
    changes.add(StockAuditChange(field: field, oldValue: before, newValue: after));
  }

  String actorNameFor(String actor) {
    if (actor == headId) return headName;
    if (actor == managerId) return managerName;
    if (actor == staffId) return staffName;
    return actor.trim().isEmpty ? currentUserName : actor;
  }

  String actorRoleFor(String actor) {
    if (actor == headId) return 'head';
    if (actor == managerId) return 'manager';
    if (actor == staffId) return 'staff';
    return currentRoleName;
  }

  String skuNameFor(String skuId) {
    for (final sku in stockSkus) {
      if (sku.id == skuId) return sku.name;
    }
    return skuId;
  }

  StockAuditEntry buildAuditEntry({
    required String module,
    required String action,
    required String itemId,
    required String itemName,
    required List<StockAuditChange> changes,
    String? actorName,
    String? actorId,
    String? actorRole,
    String note = '',
  }) {
    final now = DateTime.now();
    return StockAuditEntry(
      id: 'AUD${now.microsecondsSinceEpoch}',
      module: module,
      action: action,
      itemId: itemId,
      itemName: itemName,
      actorName: actorName ?? currentUserName,
      actorId: actorId ?? currentUserId,
      actorRole: actorRole ?? currentRoleName,
      timestampText: auditTimestamp(),
      capturedAt: now,
      changes: List<StockAuditChange>.unmodifiable(changes),
      note: note,
    );
  }

  List<StockAuditChange> skuAuditChanges(StockSku before, StockSku after) {
    final changes = <StockAuditChange>[];
    addAuditChange(changes, 'SKU Name', before.name, after.name);
    addAuditChange(changes, 'Tag 1', before.category, after.category);
    addAuditChange(changes, 'Tag 2', before.location, after.location);
    addAuditChange(changes, 'Unit', before.unit, after.unit);
    addAuditChange(changes, 'Min Balance', before.minimumBalanceValue, after.minimumBalanceValue);
    addAuditChange(changes, 'Current Balance', before.currentBalanceValue, after.currentBalanceValue);
    addAuditChange(changes, 'Max Balance', before.maximumBalanceValue, after.maximumBalanceValue);
    addAuditChange(changes, 'Recovery', '${before.recoveryPercent}%', '${after.recoveryPercent}%');
    addAuditChange(changes, 'Min Price', 'RM ${formatAuditValue(before.minimumPriceRm)}', 'RM ${formatAuditValue(after.minimumPriceRm)}');
    addAuditChange(changes, 'Max Price', 'RM ${formatAuditValue(before.maximumPriceRm)}', 'RM ${formatAuditValue(after.maximumPriceRm)}');
    addAuditChange(changes, 'Supplier', before.supplierIds, after.supplierIds);
    addAuditChange(changes, 'Assignee', before.assignedStaffNames.isEmpty ? 'Unassigned' : before.assignedStaffNames, after.assignedStaffNames.isEmpty ? 'Unassigned' : after.assignedStaffNames);
    addAuditChange(changes, 'Receiving Checklist', before.receivingChecklist, after.receivingChecklist);
    addAuditChange(changes, 'Reset Time', before.resetTime, after.resetTime);
    addAuditChange(changes, 'Active', before.active, after.active);
    return changes;
  }

  List<StockAuditChange> createdSkuAuditChanges(StockSku sku) {
    final changes = <StockAuditChange>[];
    addAuditChange(changes, 'SKU Name', '-', sku.name);
    addAuditChange(changes, 'Tag 1', '-', sku.category);
    addAuditChange(changes, 'Tag 2', '-', sku.location);
    addAuditChange(changes, 'Unit', '-', sku.unit);
    addAuditChange(changes, 'Min Balance', '-', sku.minimumBalanceValue);
    addAuditChange(changes, 'Current Balance', '-', sku.currentBalanceValue);
    addAuditChange(changes, 'Max Balance', '-', sku.maximumBalanceValue);
    addAuditChange(changes, 'Recovery', '-', '${sku.recoveryPercent}%');
    addAuditChange(changes, 'Price Range', '-', 'RM ${formatAuditValue(sku.minimumPriceRm)} - RM ${formatAuditValue(sku.maximumPriceRm)}');
    addAuditChange(changes, 'Supplier', '-', sku.supplierIds);
    addAuditChange(changes, 'Assignee', '-', sku.assignedStaffNames.isEmpty ? 'Unassigned' : sku.assignedStaffNames);
    addAuditChange(changes, 'Reset Time', '-', sku.resetTime);
    return changes;
  }

  void submitStockCheck(StockSubmission submission) {
    final actorId = submission.submittedBy;
    final changes = <StockAuditChange>[];
    addAuditChange(changes, 'Previous Balance', '-', submission.previousBalanceValue);
    addAuditChange(changes, 'Current Balance', '-', submission.currentBalanceValue);
    addAuditChange(changes, 'Below Min', '-', submission.belowMinimumBalance);
    addAuditChange(changes, 'Checked Values', '-', submission.checkedItems.entries.map((entry) => '${entry.key}: ${entry.value ? 'Yes' : 'No'}').join(', '));
    addAuditChange(changes, 'Remarks', '-', submission.remarks.values.where((value) => value.trim().isNotEmpty).join('; '));
    setState(() {
      stockSubmissions = [submission, ...stockSubmissions];
      stockAuditEntries = [
        buildAuditEntry(
          module: 'Stock Count',
          action: 'Submitted count',
          itemId: submission.stockTaskId,
          itemName: skuNameFor(submission.stockTaskId),
          actorName: actorNameFor(actorId),
          actorId: actorId,
          actorRole: actorRoleFor(actorId),
          changes: changes,
        ),
        ...stockAuditEntries,
      ];
    });
  }

  void reviewStockCount(StockSubmission submission) {
    final previous = stockSubmissions.where((item) => item.id == submission.id).isEmpty
        ? null
        : stockSubmissions.firstWhere((item) => item.id == submission.id);
    final changes = <StockAuditChange>[];
    if (previous != null) {
      addAuditChange(changes, 'Review Status', previous.reviewStatus, submission.reviewStatus);
      addAuditChange(changes, 'Reviewed By', previous.reviewedBy, submission.reviewedBy);
      addAuditChange(changes, 'Review Note', previous.reviewNote, submission.reviewNote);
    }
    setState(() {
      stockSubmissions = stockSubmissions.map((item) {
        if (item.id != submission.id) return item;
        return submission;
      }).toList();
      if (changes.isNotEmpty) {
        stockAuditEntries = [
          buildAuditEntry(
            module: 'Stock Count',
            action: 'Reviewed count',
            itemId: submission.stockTaskId,
            itemName: skuNameFor(submission.stockTaskId),
            changes: changes,
          ),
          ...stockAuditEntries,
        ];
      }
    });
  }

  void createStockTask(StockTask task) {
    final changes = <StockAuditChange>[];
    addAuditChange(changes, 'Task Title', '-', task.title);
    addAuditChange(changes, 'Supplier', '-', task.supplierName);
    addAuditChange(changes, 'Checks', '-', task.checks.map((check) => check.question).join('; '));
    setState(() {
      stockTasks = [task, ...stockTasks];
      stockAuditEntries = [
        buildAuditEntry(
          module: 'Stock Task',
          action: 'Created task',
          itemId: task.id,
          itemName: task.title,
          changes: changes,
        ),
        ...stockAuditEntries,
      ];
    });
  }

  void createSupplier(SupplierProfile supplier) {
    final changes = <StockAuditChange>[];
    addAuditChange(changes, 'Supplier Name', '-', supplier.supplierName);
    addAuditChange(changes, 'Supplier Item', '-', supplier.supplierItem);
    addAuditChange(changes, 'Unit', '-', supplier.unit);
    addAuditChange(changes, 'Price', '-', 'RM ${formatAuditValue(supplier.pricingPerUnit)}');
    addAuditChange(changes, 'Min Balance', '-', supplier.minimumBalanceValue);
    addAuditChange(changes, 'Max Balance', '-', supplier.maximumBalanceValue);
    setState(() {
      suppliers = [supplier, ...suppliers];
      stockAuditEntries = [
        buildAuditEntry(
          module: 'Supplier',
          action: 'Created supplier',
          itemId: supplier.id,
          itemName: supplier.supplierName,
          changes: changes,
        ),
        ...stockAuditEntries,
      ];
    });
  }



  void createSku(StockSku sku) {
    final changes = createdSkuAuditChanges(sku);
    setState(() {
      stockSkus = [sku, ...stockSkus];
      stockAuditEntries = [
        buildAuditEntry(
          module: 'SKU',
          action: 'Created SKU',
          itemId: sku.id,
          itemName: sku.name,
          changes: changes,
        ),
        ...stockAuditEntries,
      ];
    });
  }

  void updateSku(StockSku updatedSku) {
    final previous = stockSkus.where((sku) => sku.id == updatedSku.id).isEmpty
        ? null
        : stockSkus.firstWhere((sku) => sku.id == updatedSku.id);
    final changes = previous == null ? <StockAuditChange>[] : skuAuditChanges(previous, updatedSku);
    setState(() {
      stockSkus = stockSkus.map((sku) {
        if (sku.id != updatedSku.id) return sku;
        return updatedSku.copyWith(
          lastUpdatedAt: 'Today just now',
          lastUpdatedBy: currentUserId,
        );
      }).toList();
      if (changes.isNotEmpty) {
        stockAuditEntries = [
          buildAuditEntry(
            module: 'SKU',
            action: 'Edited SKU',
            itemId: updatedSku.id,
            itemName: updatedSku.name,
            changes: changes,
          ),
          ...stockAuditEntries,
        ];
      }
    });
  }

  void updateSkuBalance(
    String skuId,
    double balance,
    String updatedBy,
  ) {
    final previous = stockSkus.where((sku) => sku.id == skuId).isEmpty
        ? null
        : stockSkus.firstWhere((sku) => sku.id == skuId);
    final changes = <StockAuditChange>[];
    if (previous != null) {
      addAuditChange(changes, 'Current Balance', previous.currentBalanceValue, balance);
    }
    setState(() {
      stockSkus = stockSkus.map((sku) {
        if (sku.id != skuId) return sku;

        return sku.copyWith(
          currentBalanceValue: balance,
          lastUpdatedAt: 'Today just now',
          lastUpdatedBy: updatedBy,
        );
      }).toList();
      if (changes.isNotEmpty) {
        stockAuditEntries = [
          buildAuditEntry(
            module: 'SKU Balance',
            action: 'Updated balance',
            itemId: skuId,
            itemName: previous?.name ?? skuId,
            actorName: actorNameFor(updatedBy),
            actorId: updatedBy,
            actorRole: actorRoleFor(updatedBy),
            changes: changes,
          ),
          ...stockAuditEntries,
        ];
      }
    });
  }

  void submitStockReceiving(StockReceivingRecord record) {
    final actorId = record.receivedBy;
    final changes = <StockAuditChange>[];
    addAuditChange(changes, 'Supplier', '-', record.supplierName);
    addAuditChange(changes, 'Items', '-', record.items.map((item) => '${item.skuName}: invoice ${formatAuditValue(item.invoiceQuantity)} ${item.unit}, received ${formatAuditValue(item.receivedQuantity)} ${item.unit}, ${item.condition}').join('; '));
    addAuditChange(changes, 'Invoice Photo', '-', record.invoicePhotoName);
    addAuditChange(changes, 'Goods Photo', '-', record.goodsPhotoName);
    setState(() {
      stockReceivingRecords = [record, ...stockReceivingRecords];
      stockAuditEntries = [
        buildAuditEntry(
          module: 'Receiving',
          action: 'Submitted receiving',
          itemId: record.id,
          itemName: record.supplierName,
          actorName: actorNameFor(actorId),
          actorId: actorId,
          actorRole: actorRoleFor(actorId),
          changes: changes,
        ),
        ...stockAuditEntries,
      ];
    });
  }

  void reviewStockReceiving(StockReceivingRecord record) {
    final previous = stockReceivingRecords.where((item) => item.id == record.id).isEmpty
        ? null
        : stockReceivingRecords.firstWhere((item) => item.id == record.id);
    final changes = <StockAuditChange>[];
    if (previous != null) {
      addAuditChange(changes, 'Review Status', previous.reviewStatus, record.reviewStatus);
      addAuditChange(changes, 'Reviewed By', previous.reviewedBy, record.reviewedBy);
      addAuditChange(changes, 'Review Note', previous.reviewNote, record.reviewNote);
    }
    setState(() {
      stockReceivingRecords = stockReceivingRecords.map((item) {
        if (item.id != record.id) return item;
        return record;
      }).toList();
      if (changes.isNotEmpty) {
        stockAuditEntries = [
          buildAuditEntry(
            module: 'Receiving',
            action: 'Reviewed receiving',
            itemId: record.id,
            itemName: record.supplierName,
            changes: changes,
          ),
          ...stockAuditEntries,
        ];
      }
    });
  }

  void updateSupplierBalance(
    String supplierId,
    double balance,
    String updatedBy,
  ) {
    final previous = suppliers.where((supplier) => supplier.id == supplierId).isEmpty
        ? null
        : suppliers.firstWhere((supplier) => supplier.id == supplierId);
    final changes = <StockAuditChange>[];
    if (previous != null) {
      addAuditChange(changes, 'Current Balance', previous.currentBalanceValue, balance);
    }
    setState(() {
      suppliers = suppliers.map((supplier) {
        if (supplier.id != supplierId) return supplier;

        return supplier.copyWith(
          currentBalanceValue: balance,
          lastBalanceUpdatedAt: 'Today just now',
          lastBalanceUpdatedBy: updatedBy,
        );
      }).toList();
      if (changes.isNotEmpty) {
        stockAuditEntries = [
          buildAuditEntry(
            module: 'Supplier Balance',
            action: 'Updated supplier balance',
            itemId: supplierId,
            itemName: previous?.supplierName ?? supplierId,
            actorName: actorNameFor(updatedBy),
            actorId: updatedBy,
            actorRole: actorRoleFor(updatedBy),
            changes: changes,
          ),
          ...stockAuditEntries,
        ];
      }
    });
  }

  Future<void> invalidateSetupCache(String prefix) async {
    await widget.api.invalidateFeatureCache(prefix);
  }

  Future<void> createStockTagRemote(StockTag tag) async {
    final saved = await widget.api.createStockTag(tag.tag);
    await invalidateSetupCache(EastAppApi.stockTagsCachePrefix(widget.session.tenant.id));
    if (!mounted) return;
    setState(() {
      stockTags = [saved, ...stockTags];
      stockTagsUpdatedAt = DateTime.now();
    });
  }

  Future<void> updateStockTagRemote(StockTag tag) async {
    final saved = await widget.api.updateStockTag(tag);
    await invalidateSetupCache(EastAppApi.stockTagsCachePrefix(widget.session.tenant.id));
    if (!mounted) return;
    setState(() {
      stockTagsUpdatedAt = DateTime.now();
      stockTags = stockTags
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  Future<bool> deleteStockTagsRemote(Set<String> tagIds) async {
    for (final tagId in tagIds) {
      await widget.api.deleteStockTag(tagId);
    }
    await invalidateSetupCache(EastAppApi.stockTagsCachePrefix(widget.session.tenant.id));
    if (!mounted) return true;
    setState(() {
      stockTagsUpdatedAt = DateTime.now();
      stockTags = stockTags.where((tag) => !tagIds.contains(tag.id)).toList();
    });
    return true;
  }

  Future<void> createSupplierRemote(SupplierProfile supplier) async {
    final saved = await widget.api.createStockSupplier(supplier);
    await invalidateSetupCache(EastAppApi.stockSuppliersCachePrefix(widget.session.tenant.id));
    if (!mounted) return;
    setState(() {
      suppliers = [saved, ...suppliers];
      stockSuppliersUpdatedAt = DateTime.now();
    });
  }

  Future<void> updateSupplierRemote(SupplierProfile supplier) async {
    final saved = await widget.api.updateStockSupplier(supplier);
    await invalidateSetupCache(EastAppApi.stockSuppliersCachePrefix(widget.session.tenant.id));
    if (!mounted) return;
    setState(() {
      stockSuppliersUpdatedAt = DateTime.now();
      suppliers = suppliers
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  Future<bool> deleteSuppliersRemote(Set<String> supplierIds) async {
    for (final supplierId in supplierIds) {
      await widget.api.deleteStockSupplier(supplierId);
    }
    await invalidateSetupCache(EastAppApi.stockSuppliersCachePrefix(widget.session.tenant.id));
    if (!mounted) return true;
    setState(() {
      stockSuppliersUpdatedAt = DateTime.now();
      suppliers = suppliers
          .where((supplier) => !supplierIds.contains(supplier.id))
          .toList();
    });
    return true;
  }

  Future<void> updateSupplierBalanceRemote(
    String supplierId,
    double balance,
    String _,
  ) async {
    final saved = await widget.api.updateStockSupplierBalance(
      supplierId: supplierId,
      balance: balance,
    );
    await invalidateSetupCache(
      EastAppApi.stockSuppliersCachePrefix(widget.session.tenant.id),
    );
    if (!mounted) return;
    setState(() {
      stockSuppliersUpdatedAt = DateTime.now();
      suppliers = suppliers
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  Future<void> createSkuRemote(StockSku sku) async {
    final saved = await widget.api.createStockSku(sku);
    await invalidateSetupCache(EastAppApi.stockSkusCachePrefix(widget.session.tenant.id));
    if (!mounted) return;
    setState(() {
      stockSkus = [saved, ...stockSkus];
      stockSkusUpdatedAt = DateTime.now();
    });
  }

  Future<void> updateSkuRemote(StockSku sku) async {
    final saved = await widget.api.updateStockSku(sku);
    await invalidateSetupCache(EastAppApi.stockSkusCachePrefix(widget.session.tenant.id));
    if (!mounted) return;
    setState(() {
      stockSkusUpdatedAt = DateTime.now();
      stockSkus = stockSkus
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  Future<void> updateSkuBalanceRemote(
    String skuId,
    double balance,
    String _,
  ) async {
    final saved = await widget.api.updateStockSkuBalance(
      skuId: skuId,
      balance: balance,
    );
    await invalidateSetupCache(
      EastAppApi.stockSkusCachePrefix(widget.session.tenant.id),
    );
    if (!mounted) return;
    setState(() {
      stockSkusUpdatedAt = DateTime.now();
      stockSkus = stockSkus
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  Future<void> submitStockCheckRemote(StockSubmission submission) async {
    final saved = await widget.api.createStockCount(submission);
    await invalidateSetupCache(
      EastAppApi.stockSkusCachePrefix(widget.session.tenant.id),
    );
    if (!mounted) return;
    setState(() {
      stockSkusUpdatedAt = DateTime.now();
      stockSubmissions = [saved, ...stockSubmissions];
      stockSkus = stockSkus.map((sku) {
        if (sku.id != saved.stockTaskId) return sku;
        return sku.copyWith(
          currentBalanceValue: saved.currentBalanceValue,
          lastUpdatedAt: saved.submittedAt,
          lastUpdatedBy: saved.submittedBy,
        );
      }).toList();
    });
  }

  Future<void> reviewStockCountRemote(StockSubmission submission) async {
    final saved = await widget.api.reviewStockCount(submission);
    if (!mounted) return;
    setState(() {
      stockSubmissions = stockSubmissions
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  Future<void> bulkReviewStockCountsRemote(
    List<StockSubmission> submissions,
  ) async {
    final saved = await widget.api.bulkReviewStockCounts(submissions);
    if (!mounted) return;
    final byId = {for (final item in saved) item.id: item};
    setState(() {
      stockSubmissions = stockSubmissions
          .map((item) => byId[item.id] ?? item)
          .toList();
    });
  }

  Future<void> submitStockReceivingRemote(
    StockReceivingRecord record,
  ) async {
    final saved = await widget.api.createStockReceiving(record);
    await invalidateSetupCache(
      EastAppApi.stockSkusCachePrefix(widget.session.tenant.id),
    );
    if (!mounted) return;
    final quantities = <String, double>{};
    for (final item in saved.items) {
      quantities[item.skuId] =
          (quantities[item.skuId] ?? 0) + item.receivedQuantity;
    }
    setState(() {
      stockSkusUpdatedAt = DateTime.now();
      stockReceivingRecords = [saved, ...stockReceivingRecords];
      stockSkus = stockSkus.map((sku) {
        final received = quantities[sku.id];
        if (received == null) return sku;
        return sku.copyWith(
          currentBalanceValue: sku.currentBalanceValue + received,
          lastUpdatedAt: saved.receivedAt,
          lastUpdatedBy: saved.receivedBy,
        );
      }).toList();
    });
  }

  Future<void> reviewStockReceivingRemote(
    StockReceivingRecord record,
  ) async {
    final saved = await widget.api.reviewStockReceiving(record);
    if (!mounted) return;
    setState(() {
      stockReceivingRecords = stockReceivingRecords
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
    });
  }

  void clockIn(AttendanceRecord record) {
    setState(() {
      attendanceRecords = [
        record,
        ...attendanceRecords.where((item) => item.staffId != record.staffId),
      ];
    });
  }

  void clockOut(AttendanceRecord record) {
    setState(() {
      attendanceRecords = attendanceRecords.map((item) {
        if (item.id != record.id) return item;

        return item.copyWith(
          clockOutTime: 'Server time just now',
          clockOutLatitude: currentWorkLocation.latitude + 0.0001,
          clockOutLongitude: currentWorkLocation.longitude + 0.0001,
          clockOutAccuracyMeters: 15,
          clockOutPhotoName: 'live_clock_out_selfie.jpg',
          totalWorkingTime: 'Completed today',
          status: AttendanceStatus.completed,
          managerReviewRequired: false,
          note:
              'Clock out captured with GPS location, live camera, server time and registered device.',
        );
      }).toList();
    });
  }

  Future<void> showLeaderboardSheet() async {
    final data = await loadPointsLeaderboard();
    if (!mounted || data == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return AppTextScope(
          language: language,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(child: RankingScreen(leaderboard: data)),
              ],
            ),
          ),
        );
      },
    );
  }

  String get currentUserName => widget.session.user.fullName;

  String get currentUserId => widget.session.user.employeeId;

  String get currentRoleName => widget.session.user.role.name;

  WorkLocation get currentWorkLocation => WorkLocation(
        id: widget.session.tenant.id,
        name: widget.session.tenant.workLocationName,
        latitude: widget.session.tenant.latitude,
        longitude: widget.session.tenant.longitude,
      );

  String get currentModeName => kReleaseMode
      ? 'release'
      : kProfileMode
          ? 'profile'
          : 'debug';

  String activeTabName(BuildContext context) {
    final text = AppTextScope.of(context);
    final labels = [
      text.t('Home'),
      text.t('Report'),
      text.t('Stock'),
      text.t('People'),
      text.t('Knowledge'),
    ];
    final safeIndex = selectedIndex.clamp(0, labels.length - 1);
    return labels[safeIndex];
  }

  String buildDebugReport(BuildContext context) {
    return AppDiagnostics.instance.buildReport(
      appVersion: 'east_app_v275',
      role: currentRoleName,
      userName: currentUserName,
      userId: currentUserId,
      activeTab: activeTabName(context),
      language: language.displayName,
      mode: currentModeName,
      tenantName: widget.session.tenant.businessName,
      tenantId: widget.session.tenant.id,
      backendBaseUrl: widget.api.baseUrl,
    );
  }

  Future<void> copyDebugReport(BuildContext context, String report) async {
    AppFeedback.tap();
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Debug report copied'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  void showHelpSheet() {
    AppFeedback.tap();
    final report = buildDebugReport(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return AppTextScope(
          language: language,
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColours.blue.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bug_report_outlined,
                          color: AppColours.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Help',
                          style: TextStyle(
                            color: AppColours.textMain,
                            fontSize: AppTextSize.s22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'Copy Debug Report',
                    icon: Icons.content_copy_rounded,
                    onPressed: () => copyDebugReport(sheetContext, report),
                  ),
                  const SizedBox(height: 12),
                  WhiteCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline_rounded, color: AppColours.textMuted, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ask the tester to paste this report into WhatsApp when something fails inside the app.',
                            style: TextStyle(
                              color: AppColours.textMuted,
                              fontSize: AppTextSize.s13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Report preview',
                    style: TextStyle(
                      color: AppColours.textMain,
                      fontSize: AppTextSize.s16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColours.mutedBox,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColours.border),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          report,
                          style: const TextStyle(
                            color: AppColours.textMain,
                            fontSize: AppTextSize.s12,
                            height: 1.35,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showRewardsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return AppTextScope(
          language: language,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(child: RewardsScreen(tasks: tasks)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> handleMainBackNavigation() async {
    if (selectedIndex != 0) {
      AppFeedback.select();
      setState(() {
        pageSlideDirection = -1;
        selectedIndex = 0;
      });
    }

    return false;
  }

  void handleMainSwipeStart(DragStartDetails details) {
    mainSwipeStartX = details.globalPosition.dx;
    mainSwipeDeltaX = 0;
  }

  void handleMainSwipeUpdate(DragUpdateDetails details) {
    mainSwipeDeltaX += details.delta.dx;
  }

  void handleMainSwipeEnd(DragEndDetails details) {
    final isRightSwipe = mainSwipeDeltaX > 72 || details.primaryVelocity != null && details.primaryVelocity! > 380;
    final isLeftEdgeSwipe = mainSwipeStartX <= 48 && (mainSwipeDeltaX > 32 || details.primaryVelocity != null && details.primaryVelocity! > 180);

    if ((isRightSwipe || isLeftEdgeSwipe) && selectedIndex != 0) {
      AppFeedback.swipeBack();
      setState(() {
        pageSlideDirection = -1;
        selectedIndex = 0;
      });
    }
  }

  Future<void> showContextSwitcher() async {
    if (!widget.session.user.role.isOwner) return;
    AppFeedback.tap();
    List<EastAppSession> contexts;
    try {
      contexts = await widget.api.availableContexts();
    } on EastAppApiException {
      return;
    }
    if (!mounted) return;

    if (contexts.length <= 1) {
      showSuccessSnackBar(
        context,
        '${widget.session.tenant.businessName} is the only available business.',
      );
      return;
    }

    final selected = await showModalBottomSheet<EastAppSession>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColours.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Switch business',
                      style: TextStyle(
                        fontSize: AppTextSize.s24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: contexts.map((item) {
                      final selectedContext =
                          item.user.id == widget.session.user.id;
                      return ListTile(
                        leading: Icon(
                          selectedContext
                              ? Icons.check_circle_rounded
                              : Icons.business_outlined,
                          color: selectedContext
                              ? AppColours.green
                              : AppColours.blue,
                        ),
                        title: Text(
                          item.tenant.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${item.user.fullName} · ${item.user.employeeId}',
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(item),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected.user.id == widget.session.user.id) {
      return;
    }

    await switchBusinessContext(selected);
  }


  Future<void> switchBusinessContext(EastAppSession selected) async {
    if (selected.user.id == widget.session.user.id) return;
    try {
      final switched = await widget.api.switchContext(selected.user.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text('Welcome to ${switched.tenant.businessName}'),
          content: Text(
            'The application will use ${switched.user.employeeId} and only data from this business.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      widget.onSessionChanged(switched);
    } on EastAppApiException {
      return;
    }
  }

  Future<void> switchToCreatedBusiness(EastAppTenant tenant) async {
    final contexts = await widget.api.availableContexts();
    EastAppSession? target;
    for (final item in contexts) {
      if (item.tenant.id == tenant.id) {
        target = item;
        break;
      }
    }
    if (target == null) {
      if (mounted) {
        showWarningSnackBar(
          context,
          'Business created, but its Owner membership is not available yet.',
        );
      }
      return;
    }
    await switchBusinessContext(target);
  }

  void logoutToLogin() {
    AppFeedback.tap();
    unawaited(widget.onLogout());
  }

  @override
  Widget build(BuildContext context) {
    return AppTextScope(
      language: language,
      child: Builder(
        builder: (context) {
          final text = AppTextScope.of(context);

          final knowledgeTabIndex = 4;
          final lowInventoryWarningCount = stockSkus
              .where((sku) => sku.isBelowMinimumBalance)
              .length;
          final pendingStockCheckCount = stockTasks
              .where(
                (task) => !stockSubmissions.any(
                  (submission) => submission.stockTaskId == task.id,
                ),
              )
              .length;
          final inventoryBadgeCount = widget.role == UserRole.head
              ? lowInventoryWarningCount
              : widget.role == UserRole.manager
                  ? pendingStockCheckCount
                  : 0;

          final pages = <Widget>[
            HomeScreen(
              role: widget.role,
              isOwner: widget.session.user.role.isOwner,
              api: widget.api,
              tenantId: widget.session.tenant.id,
              businessName: widget.session.tenant.businessName,
              tasks: tasks,
              googleRatingRefreshSignal: homeRefreshSignal,
              onViewTasks: widget.role == UserRole.staff
                  ? () => goToTab(1)
                  : openStockReviewFromHome,
              onReports: () => goToTab(1),
              onRewards: showRewardsSheet,
              onRanking: showLeaderboardSheet,
              onKnowledge: () => goToTab(knowledgeTabIndex),
            ),
            ReportScreen(
              api: widget.api,
              tenantId: widget.session.tenant.id,
              currentUser: widget.session.user,
              role: widget.role,
              stockSkus: stockSkus,
              onReportChanged: () {
                if (!mounted) return;
                setState(() => homeRefreshSignal++);
              },
            ),
            StockScreen(
              role: widget.role,
              api: widget.api,
              isOwner: widget.session.user.role.isOwner,
              currentTenantId: widget.session.tenant.id,
              currentTenantName: widget.session.tenant.businessName,
              onReloadAfterSkuCopy: () async {
                await Future.wait([
                  widget.api.invalidateFeatureCache(
                    EastAppApi.stockTagsCachePrefix(widget.session.tenant.id),
                  ),
                  widget.api.invalidateFeatureCache(
                    EastAppApi.stockSuppliersCachePrefix(widget.session.tenant.id),
                  ),
                  widget.api.invalidateFeatureCache(
                    EastAppApi.stockSkusCachePrefix(widget.session.tenant.id),
                  ),
                ]);
                await Future.wait([
                  loadStockTags(reset: true, forceRefresh: true),
                  loadStockSuppliers(reset: true, forceRefresh: true),
                  loadStockSkus(reset: true, forceRefresh: true),
                ]);
              },
              stockTasks: stockTasks,
              submissions: stockSubmissions,
              suppliers: suppliers,
              stockSkus: stockSkus,
              receivingRecords: stockReceivingRecords,
              tags: stockTags,
              tagsLastUpdatedAt: stockTagsUpdatedAt,
              suppliersLastUpdatedAt: stockSuppliersUpdatedAt,
              skusLastUpdatedAt: stockSkusUpdatedAt,
              onRefreshTags: () => loadStockTags(reset: true, forceRefresh: true),
              onRefreshSuppliers: () => loadStockSuppliers(reset: true, forceRefresh: true),
              onRefreshSkus: () => loadStockSkus(reset: true, forceRefresh: true),
              onLoadPageData: loadStockPageData,
              onLoadMoreTags: () => loadStockTags(),
              onLoadMoreSuppliers: () => loadStockSuppliers(),
              onLoadMoreSkus: () => loadStockSkus(),
              onLoadMoreCounts: () => loadStockCounts(
                mine: stockCountsMine ?? false,
              ),
              onLoadMoreReceivings: () => loadStockReceivings(),
              canLoadMoreTags: stockTagPage >= 0 && !stockTagsLast,
              canLoadMoreSuppliers:
                  stockSupplierPage >= 0 && !stockSuppliersLast,
              canLoadMoreSkus: stockSkuPage >= 0 && !stockSkusLast,
              canLoadMoreCounts: stockCountPage >= 0 && !stockCountsLast,
              canLoadMoreReceivings:
                  stockReceivingPage >= 0 && !stockReceivingsLast,
              onLoadAuditEntries: loadStockAuditEntries,
              onSubmitStockCheck: submitStockCheckRemote,
              onCreateStockTask: createStockTask,
              onUpdateSupplierBalance: updateSupplierBalanceRemote,
              onCreateSupplier: createSupplierRemote,
              onUpdateSupplier: updateSupplierRemote,
              onDeleteSuppliers: deleteSuppliersRemote,
              onCreateSku: createSkuRemote,
              onUpdateSku: updateSkuRemote,
              onUpdateSkuBalance: updateSkuBalanceRemote,
              onSubmitReceiving: submitStockReceivingRemote,
              onReviewReceiving: reviewStockReceivingRemote,
              onReviewStockCount: reviewStockCountRemote,
              onBulkReviewStockCounts: bulkReviewStockCountsRemote,
              onCreateTag: createStockTagRemote,
              onUpdateTag: updateStockTagRemote,
              onDeleteTags: deleteStockTagsRemote,
              initialPage: requestedStockPage,
              initialPageBackToMainHome: requestedStockPageBackToHome,
              onInitialPageConsumed: consumeRequestedStockPage,
              onExitToMainHome: exitStockToMainHome,
              resetSignal: stockResetSignal,
            ),
            AttendanceScreen(
              role: widget.role,
              api: widget.api,
              currentUser: widget.session.user,
              currentTenant: widget.session.tenant,
              pointsLeaderboard: pointsLeaderboard,
              onPointsChanged: handlePointsChanged,
              onCurrentUserChanged: widget.onCurrentUserChanged,
              onBusinessContextSelected: switchBusinessContext,
              onBusinessCreated: switchToCreatedBusiness,
              workLocation: currentWorkLocation,
              attendanceRecords: attendanceRecords,
              onClockIn: clockIn,
              onClockOut: clockOut,
            ),
            KnowledgeScreen(
              role: widget.role,
              knowledgeItems: knowledge,
              tags: stockTags,
              onCreateSop: createSop,
            ),
          ];

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) unawaited(handleMainBackNavigation());
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: handleMainSwipeStart,
              onHorizontalDragUpdate: handleMainSwipeUpdate,
              onHorizontalDragEnd: handleMainSwipeEnd,
              child: Scaffold(
              body: Stack(
                children: [
                  Column(
              children: [
                AppHeader(
                  businessName: widget.session.tenant.businessName,
                  language: language,
                  onLanguageChanged: changeLanguage,
                  onIdentityTap: widget.session.user.role.isOwner
                      ? showContextSwitcher
                      : null,
                  totalPoints:
                      pointsLeaderboard?.currentUserTotalPoints ?? 0,
                  onHelp: showHelpSheet,
                  onLogout: logoutToLogin,
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey<int>(selectedIndex),
                    child: pages[selectedIndex],
                  ),
                ),
              ],
            ),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                height: 66,
              backgroundColor: Colors.white,
              indicatorColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: goToTab,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(
                    Icons.home_outlined,
                    color: AppColours.blue,
                  ),
                  label: text.t('Home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.analytics_outlined),
                  selectedIcon: const Icon(
                    Icons.analytics_rounded,
                    color: AppColours.blue,
                  ),
                  label: text.t('Report'),
                ),
                NavigationDestination(
                  icon: _BadgedNavIcon(
                    icon: Icons.inventory_2_outlined,
                    count: inventoryBadgeCount,
                  ),
                  selectedIcon: _BadgedNavIcon(
                    icon: Icons.inventory_2_outlined,
                    count: inventoryBadgeCount,
                    colour: AppColours.blue,
                  ),
                  label: text.t('Stock'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  selectedIcon: const Icon(
                    Icons.groups_outlined,
                    color: AppColours.blue,
                  ),
                  label: text.t('People'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(
                    Icons.menu_book_outlined,
                    color: AppColours.blue,
                  ),
                  label: text.t('Knowledge'),
                ),
              ],
            ),
          ),
            ),
          );
        },
      ),
    );
  }
}


class _BadgedNavIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color? colour;

  const _BadgedNavIcon({
    required this.icon,
    required this.count,
    this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = count > 99 ? '99+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: colour),
        if (count > 0)
          Positioned(
            top: -8,
            right: -12,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColours.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(
                displayCount,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTextSize.s10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
