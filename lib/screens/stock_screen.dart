import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/sample_data.dart';
import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/api_models.dart';
import '../models/people_models.dart';
import '../models/organisation_models.dart';
import '../models/stock_api_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../utils/app_diagnostics.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';

List<SupplierProfile> _sortSuppliersAlphabetically(Iterable<SupplierProfile> source) {
  final items = source.toList();
  items.sort((a, b) {
    final result = a.supplierName.toLowerCase().compareTo(b.supplierName.toLowerCase());
    if (result != 0) return result;
    return a.id.compareTo(b.id);
  });
  return items;
}

Future<T?> showStockBottomSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext sheetContext) builder,
  double maxHeightFactor = 0.9,
}) {
  final mediaScope = context.getInheritedWidgetOfExactType<_StockMediaScope>();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
      Widget sheet = Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * maxHeightFactor,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: builder(sheetContext),
      );
      if (mediaScope != null) {
        sheet = _StockMediaScope(
          api: mediaScope.api,
          loadThumbnail: mediaScope.loadThumbnail,
          loadReceivingPhoto: mediaScope.loadReceivingPhoto,
          child: sheet,
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: sheet,
        ),
      );
    },
  );
}

Widget stockBottomSheetHandle() {
  return Center(
    child: Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFD8DEE8),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

Future<bool> runStockRequest(
  BuildContext context,
  Future<void> Function() request,
) async {
  try {
    await request();
    return true;
  } on EastAppApiException catch (_) {
    return false;
  }
}

class _SetupDataRefreshBar extends StatefulWidget {
  final DateTime? updatedAt;
  final Future<void> Function() onRefresh;

  const _SetupDataRefreshBar({required this.updatedAt, required this.onRefresh});

  @override
  State<_SetupDataRefreshBar> createState() => _SetupDataRefreshBarState();
}

class _SetupDataRefreshBarState extends State<_SetupDataRefreshBar> {
  bool refreshing = false;

  Future<void> refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  String get updatedText {
    final value = widget.updatedAt;
    if (value == null) return 'Not loaded';
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Last updated ${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(
          children: [
            const Icon(Icons.storage_rounded, size: 18, color: AppColours.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                updatedText,
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontSize: AppTextSize.s12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: refreshing ? null : refresh,
              icon: refreshing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockMediaScope extends InheritedWidget {
  final EastAppApi api;
  final Future<Uint8List> Function(String storageKey) loadThumbnail;
  final Future<Uint8List> Function(String storageKey) loadReceivingPhoto;

  const _StockMediaScope({
    required this.api,
    required this.loadThumbnail,
    required this.loadReceivingPhoto,
    required super.child,
  });

  static _StockMediaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_StockMediaScope>();
    assert(scope != null, 'Stock media scope is missing.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant _StockMediaScope oldWidget) {
    return api != oldWidget.api ||
        loadThumbnail != oldWidget.loadThumbnail ||
        loadReceivingPhoto != oldWidget.loadReceivingPhoto;
  }
}

class StockScreen extends StatefulWidget {
  final UserRole role;
  final EastAppApi api;
  final bool isOwner;
  final String currentTenantId;
  final String currentTenantName;
  final Future<void> Function() onReloadAfterSkuCopy;
  final List<StockTask> stockTasks;
  final List<StockSubmission> submissions;
  final List<SupplierProfile> suppliers;
  final List<StockSku> stockSkus;
  final List<StockReceivingRecord> receivingRecords;
  final List<StockTag> tags;
  final DateTime? tagsLastUpdatedAt;
  final DateTime? suppliersLastUpdatedAt;
  final DateTime? skusLastUpdatedAt;
  final Future<void> Function() onRefreshTags;
  final Future<void> Function() onRefreshSuppliers;
  final Future<void> Function() onRefreshSkus;
  final Future<String?> Function(StockPage page) onLoadPageData;
  final Future<void> Function() onLoadMoreTags;
  final Future<void> Function() onLoadMoreSuppliers;
  final Future<void> Function() onLoadMoreSkus;
  final Future<void> Function() onLoadMoreCounts;
  final Future<void> Function() onLoadMoreReceivings;
  final bool canLoadMoreTags;
  final bool canLoadMoreSuppliers;
  final bool canLoadMoreSkus;
  final bool canLoadMoreCounts;
  final bool canLoadMoreReceivings;
  final Future<EastAppPage<StockAuditEntry>> Function(
      DateTime rangeStart, DateTime rangeEnd, int page, int size) onLoadAuditEntries;
  final Future<void> Function(StockSubmission submission) onSubmitStockCheck;
  final void Function(StockTask task) onCreateStockTask;
  final Future<void> Function(String supplierId, double balance, String updatedBy)
      onUpdateSupplierBalance;
  final Future<void> Function(SupplierProfile supplier) onCreateSupplier;
  final Future<void> Function(SupplierProfile supplier) onUpdateSupplier;
  final Future<bool> Function(Set<String> supplierIds) onDeleteSuppliers;
  final Future<void> Function(StockSku sku) onCreateSku;
  final Future<void> Function(StockSku sku) onUpdateSku;
  final Future<void> Function(String skuId, double balance, String updatedBy)
      onUpdateSkuBalance;
  final Future<void> Function(StockReceivingRecord record) onSubmitReceiving;
  final Future<void> Function(StockReceivingRecord record) onReviewReceiving;
  final Future<void> Function(StockSubmission submission) onReviewStockCount;
  final Future<void> Function(List<StockSubmission> submissions) onBulkReviewStockCounts;
  final Future<void> Function(StockTag tag) onCreateTag;
  final Future<void> Function(StockTag tag) onUpdateTag;
  final Future<bool> Function(Set<String> tagIds) onDeleteTags;
  final StockPage? initialPage;
  final bool initialPageBackToMainHome;
  final VoidCallback onInitialPageConsumed;
  final VoidCallback onExitToMainHome;
  final int resetSignal;

  const StockScreen({
    super.key,
    required this.role,
    required this.api,
    required this.isOwner,
    required this.currentTenantId,
    required this.currentTenantName,
    required this.onReloadAfterSkuCopy,
    required this.stockTasks,
    required this.submissions,
    required this.suppliers,
    required this.stockSkus,
    required this.receivingRecords,
    required this.tags,
    required this.tagsLastUpdatedAt,
    required this.suppliersLastUpdatedAt,
    required this.skusLastUpdatedAt,
    required this.onRefreshTags,
    required this.onRefreshSuppliers,
    required this.onRefreshSkus,
    required this.onLoadPageData,
    required this.onLoadMoreTags,
    required this.onLoadMoreSuppliers,
    required this.onLoadMoreSkus,
    required this.onLoadMoreCounts,
    required this.onLoadMoreReceivings,
    required this.canLoadMoreTags,
    required this.canLoadMoreSuppliers,
    required this.canLoadMoreSkus,
    required this.canLoadMoreCounts,
    required this.canLoadMoreReceivings,
    required this.onLoadAuditEntries,
    required this.onSubmitStockCheck,
    required this.onCreateStockTask,
    required this.onUpdateSupplierBalance,
    required this.onCreateSupplier,
    required this.onUpdateSupplier,
    required this.onDeleteSuppliers,
    required this.onCreateSku,
    required this.onUpdateSku,
    required this.onUpdateSkuBalance,
    required this.onSubmitReceiving,
    required this.onReviewReceiving,
    required this.onReviewStockCount,
    required this.onBulkReviewStockCounts,
    required this.onCreateTag,
    required this.onUpdateTag,
    required this.onDeleteTags,
    required this.onInitialPageConsumed,
    required this.onExitToMainHome,
    this.initialPage,
    this.initialPageBackToMainHome = false,
    this.resetSignal = 0,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

enum StockPage {
  home,
  dailyCount,
  receiving,
  restockMessage,
  review,
  skuSetup,
  supplierSetup,
  tagSetup,
  assigneeSetup,
  auditTrail,
}

class _StockScreenState extends State<StockScreen> {
  final Map<String, Future<Uint8List>> _thumbnailCache = {};
  final Map<String, Future<Uint8List>> _receivingPhotoCache = {};
  StockPage page = StockPage.home;
  bool pageLoading = false;
  bool loadingMore = false;
  int stockPageSlideDirection = 1;
  double stockSwipeStartX = 0;
  double stockSwipeDeltaX = 0;
  bool returnToMainHomeOnBack = false;
  void resetCountTimers(List<String> skuIds) {
    // SKU reset is now based on each SKU's daily reset time, not a countdown timer.
  }

  Future<Uint8List> loadThumbnail(String storageKey) {
    return _thumbnailCache.putIfAbsent(
      storageKey,
      () => widget.api.stockSkuThumbnailBytes(storageKey),
    );
  }

  Future<Uint8List> loadReceivingPhoto(String storageKey) {
    return _receivingPhotoCache.putIfAbsent(
      storageKey,
      () => widget.api.stockReceivingPhotoBytes(storageKey),
    );
  }

  @override
  void initState() {
    super.initState();
    _scheduleInitialPage();
  }

  void _scheduleInitialPage() {
    final initialPage = widget.initialPage;
    if (initialPage == null) return;
    returnToMainHomeOnBack = widget.initialPageBackToMainHome;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      widget.onInitialPageConsumed();
      await openPage(initialPage);
      if (!mounted) return;
      if (page != initialPage && returnToMainHomeOnBack) {
        returnToMainHomeOnBack = false;
        widget.onExitToMainHome();
      }
    });
  }

  @override
  void didUpdateWidget(covariant StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetSignal != oldWidget.resetSignal && page != StockPage.home) {
      stockPageSlideDirection = -1;
      returnToMainHomeOnBack = false;
      page = StockPage.home;
    }
    if (widget.initialPage != null &&
        widget.initialPage != oldWidget.initialPage) {
      _scheduleInitialPage();
    }
  }

  bool get isHead => widget.role == UserRole.head;
  bool get isManager => widget.role == UserRole.manager;
  bool get isStaff => widget.role == UserRole.staff;
  bool get canReceiveStock => isManager || isHead;
  bool get canReviewStock => isManager || isHead;
  bool get canAccessAuditTrail => widget.isOwner || isHead;

  Future<void> openPage(StockPage nextPage) async {
    if (nextPage == StockPage.auditTrail && !canAccessAuditTrail) {
      showWarningSnackBar(
        context,
        'Only Owner and Head can view Stock Audit Trail.',
      );
      return;
    }
    if (page == nextPage || pageLoading) return;
    AppFeedback.select();
    setState(() => pageLoading = true);
    final error = await widget.onLoadPageData(nextPage);
    if (!mounted) return;
    if (error != null) {
      setState(() => pageLoading = false);
      return;
    }
    setState(() {
      pageLoading = false;
      stockPageSlideDirection = 1;
      page = nextPage;
    });
  }

  bool get canLoadMoreCurrentPage {
    switch (page) {
      case StockPage.dailyCount:
        return widget.canLoadMoreSkus || widget.canLoadMoreCounts;
      case StockPage.receiving:
      case StockPage.restockMessage:
        return widget.canLoadMoreSuppliers || widget.canLoadMoreSkus;
      case StockPage.review:
        return false;
      case StockPage.skuSetup:
        return widget.canLoadMoreTags ||
            widget.canLoadMoreSuppliers ||
            widget.canLoadMoreSkus;
      case StockPage.supplierSetup:
        return widget.canLoadMoreSuppliers;
      case StockPage.tagSetup:
        return widget.canLoadMoreTags;
      case StockPage.assigneeSetup:
        return false;
      case StockPage.auditTrail:
      case StockPage.home:
        return false;
    }
  }

  Future<void> loadMoreCurrentPage() async {
    if (loadingMore || !canLoadMoreCurrentPage) return;
    setState(() => loadingMore = true);
    try {
      switch (page) {
        case StockPage.dailyCount:
          await Future.wait([
            if (widget.canLoadMoreSkus) widget.onLoadMoreSkus(),
            if (widget.canLoadMoreCounts) widget.onLoadMoreCounts(),
          ]);
          break;
        case StockPage.receiving:
        case StockPage.restockMessage:
          await Future.wait([
            if (widget.canLoadMoreSuppliers) widget.onLoadMoreSuppliers(),
            if (widget.canLoadMoreSkus) widget.onLoadMoreSkus(),
          ]);
          break;
        case StockPage.skuSetup:
          await Future.wait([
            if (widget.canLoadMoreTags) widget.onLoadMoreTags(),
            if (widget.canLoadMoreSuppliers) widget.onLoadMoreSuppliers(),
            if (widget.canLoadMoreSkus) widget.onLoadMoreSkus(),
          ]);
          break;
        case StockPage.review:
          break;
        case StockPage.supplierSetup:
          await widget.onLoadMoreSuppliers();
          break;
        case StockPage.tagSetup:
          await widget.onLoadMoreTags();
          break;
        case StockPage.assigneeSetup:
          break;
        case StockPage.auditTrail:
        case StockPage.home:
          break;
      }
    } on EastAppApiException catch (_) {
      // The global API error dialog already presents the failure.
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void goHome({bool fromSwipe = false}) {
    if (page == StockPage.home) return;
    if (fromSwipe) {
      AppFeedback.swipeBack();
    } else {
      AppFeedback.select();
    }
    if (returnToMainHomeOnBack) {
      returnToMainHomeOnBack = false;
      widget.onExitToMainHome();
      return;
    }
    setState(() {
      stockPageSlideDirection = -1;
      page = StockPage.home;
    });
  }

  Future<bool> handleBackNavigation() async {
    if (page != StockPage.home) {
      goHome();
    }

    return false;
  }

  void handleStockSwipeStart(DragStartDetails details) {
    stockSwipeStartX = details.globalPosition.dx;
    stockSwipeDeltaX = 0;
  }

  void handleStockSwipeUpdate(DragUpdateDetails details) {
    stockSwipeDeltaX += details.delta.dx;
  }

  void handleStockSwipeEnd(DragEndDetails details) {
    if (page == StockPage.home) return;

    final isRightSwipe = stockSwipeDeltaX > 72 || details.primaryVelocity != null && details.primaryVelocity! > 380;
    final isLeftEdgeSwipe = stockSwipeStartX <= 48 && (stockSwipeDeltaX > 32 || details.primaryVelocity != null && details.primaryVelocity! > 180);

    if (isRightSwipe || isLeftEdgeSwipe) {
      goHome(fromSwipe: true);
    }
  }

  Widget _withSetupRefresh({
    required Widget child,
    required DateTime? updatedAt,
    required Future<void> Function() onRefresh,
  }) {
    return Column(
      children: [
        _SetupDataRefreshBar(updatedAt: updatedAt, onRefresh: onRefresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget buildCurrentPage() {
    switch (page) {
      case StockPage.dailyCount:
        return _DailyStockCountPage(
          role: widget.role,
          skus: widget.stockSkus,
          submissions: widget.submissions,
          onBack: goHome,
          onSubmitStockCheck: widget.onSubmitStockCheck,
          onUpdateSkuBalance: widget.onUpdateSkuBalance,
          onResetCountTimers: resetCountTimers,
        );
      case StockPage.receiving:
        return _StockReceivingPage(
          role: widget.role,
          suppliers: widget.suppliers,
          skus: widget.stockSkus,
          onBack: goHome,
          onSubmitReceiving: widget.onSubmitReceiving,
          onUpdateSkuBalance: widget.onUpdateSkuBalance,
        );
      case StockPage.restockMessage:
        return _RestockMessagePage(
          suppliers: widget.suppliers,
          skus: widget.stockSkus,
          onBack: goHome,
        );
      case StockPage.review:
        return _StockReviewPage(
          api: widget.api,
          role: widget.role,
          onBack: goHome,
          onReviewReceiving: widget.onReviewReceiving,
          onReviewStockCount: widget.onReviewStockCount,
          onBulkReviewStockCounts: widget.onBulkReviewStockCounts,
        );
      case StockPage.skuSetup:
        return _withSetupRefresh(
          updatedAt: widget.skusLastUpdatedAt,
          onRefresh: widget.onRefreshSkus,
          child: _SkuSetupPage(
            api: widget.api,
            isOwner: widget.isOwner,
            currentTenantId: widget.currentTenantId,
            currentTenantName: widget.currentTenantName,
            onReloadAfterSkuCopy: widget.onReloadAfterSkuCopy,
            tags: widget.tags,
            suppliers: widget.suppliers,
            skus: widget.stockSkus,
            onBack: goHome,
            onCreateSku: widget.onCreateSku,
            onUpdateSku: widget.onUpdateSku,
            onUpdateSkuBalance: widget.onUpdateSkuBalance,
          ),
        );
      case StockPage.supplierSetup:
        return _withSetupRefresh(
          updatedAt: widget.suppliersLastUpdatedAt,
          onRefresh: widget.onRefreshSuppliers,
          child: _SupplierSetupPage(
            suppliers: widget.suppliers,
            onBack: goHome,
            onCreateSupplier: widget.onCreateSupplier,
            onUpdateSupplier: widget.onUpdateSupplier,
            onDeleteSuppliers: widget.onDeleteSuppliers,
          ),
        );
      case StockPage.tagSetup:
        return _withSetupRefresh(
          updatedAt: widget.tagsLastUpdatedAt,
          onRefresh: widget.onRefreshTags,
          child: _TagSetupPage(
            tags: widget.tags,
            onBack: goHome,
            onCreateTag: widget.onCreateTag,
            onUpdateTag: widget.onUpdateTag,
            onDeleteTags: widget.onDeleteTags,
          ),
        );
      case StockPage.assigneeSetup:
        return _SkuAssigneePage(
          api: widget.api,
          onBack: goHome,
          onUpdateSku: widget.onUpdateSku,
        );
      case StockPage.auditTrail:
        return _AuditTrailPage(
          onLoadEntries: widget.onLoadAuditEntries,
          onBack: goHome,
        );
      case StockPage.home:
        return _StockHomePage(
          role: widget.role,
          isOwner: widget.isOwner,
          onOpenPage: openPage,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pageLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _StockMediaScope(
      api: widget.api,
      loadThumbnail: loadThumbnail,
      loadReceivingPhoto: loadReceivingPhoto,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(handleBackNavigation());
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: handleStockSwipeStart,
          onHorizontalDragUpdate: handleStockSwipeUpdate,
          onHorizontalDragEnd: handleStockSwipeEnd,
          child: KeyedSubtree(
            key: ValueKey<StockPage>(page),
            child: Column(
              children: [
                Expanded(child: buildCurrentPage()),
                if (canLoadMoreCurrentPage)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                      child: OutlinedButton.icon(
                        onPressed: loadingMore ? null : loadMoreCurrentPage,
                        icon: loadingMore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          AppTextScope.of(context).t(
                            loadingMore ? 'Loading...' : 'Load More',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockHomePage extends StatelessWidget {
  final UserRole role;
  final bool isOwner;
  final void Function(StockPage page) onOpenPage;

  const _StockHomePage({
    required this.role,
    required this.isOwner,
    required this.onOpenPage,
  });

  bool get isHead => role == UserRole.head;
  bool get isManager => role == UserRole.manager;
  bool get isStaff => role == UserRole.staff;
  bool get canReceiveStock => isManager || isHead;
  bool get canReviewStock => isManager || isHead;
  bool get canManageSetup => isOwner || isHead;
  bool get canAccessAuditTrail => isOwner || isHead;

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final todaySubtitle = isStaff
        ? text.t('Update daily physical stock balance')
        : text.t('Count stock / receive goods / prepare restock');

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PageTitle(
          title: text.t('Stock Dashboard'),
          subtitle: todaySubtitle,
        ),
        const SizedBox(height: 8),
        _SectionTitle(text.t('Operation')),
        _StockMenuGrid(
          children: [
            _StockMenuCard(
              title: text.t('Count'),
              subtitle: text.t('Stock Balance'),
              icon: Icons.fact_check_outlined,
              onTap: () => onOpenPage(StockPage.dailyCount),
            ),
            if (canReceiveStock)
              _StockMenuCard(
                title: text.t('Receiving'),
                subtitle: text.t('Invoice & goods check'),
                icon: Icons.assignment_turned_in_outlined,
                onTap: () => onOpenPage(StockPage.receiving),
              ),
            if (canReviewStock)
              _StockMenuCard(
                title: text.t('Purchase'),
                subtitle: text.t('Restock'),
                icon: Icons.content_copy_rounded,
                onTap: () => onOpenPage(StockPage.restockMessage),
              ),
            if (canReviewStock)
              _StockMenuCard(
                title: text.t('Review'),
                subtitle: text.t('Audit Inbound'),
                icon: Icons.manage_search_rounded,
                onTap: () => onOpenPage(StockPage.review),
              ),
          ],
        ),
        if (canManageSetup) ...[
          const SizedBox(height: 12),
          _SectionTitle(text.t('Setup - Owner & Head')),
          _StockMenuGrid(
            children: [
              _StockMenuCard(
                title: text.t('SKU'),
                subtitle: text.t('Create/list SKU'),
                icon: Icons.add_box_outlined,
                onTap: () => onOpenPage(StockPage.skuSetup),
              ),
              _StockMenuCard(
                title: text.t('Supplier'),
                subtitle: text.t('Create/list Supplier'),
                icon: Icons.add_business_outlined,
                onTap: () => onOpenPage(StockPage.supplierSetup),
              ),
              _StockMenuCard(
                title: text.t('Tag'),
                subtitle: text.t('Custom Category'),
                icon: Icons.sell_outlined,
                onTap: () => onOpenPage(StockPage.tagSetup),
              ),
              _StockMenuCard(
                title: text.t('Assignee'),
                subtitle: text.t('Assign SKU to user'),
                icon: Icons.assignment_ind_outlined,
                onTap: () => onOpenPage(StockPage.assigneeSetup),
              ),
              if (canAccessAuditTrail)
                _StockMenuCard(
                  title: text.t('Audit Trail'),
                  subtitle: text.t('Change log'),
                  icon: Icons.manage_history_rounded,
                  onTap: () => onOpenPage(StockPage.auditTrail),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: danger ? AppColours.red : AppColours.blue, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTextSize.s16,
              fontWeight: FontWeight.w700,
              color: danger ? AppColours.red : AppColours.textMain,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 7),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: AppTextSize.s15,
          fontWeight: FontWeight.w700,
          color: AppColours.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StockMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const _StockMenuGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 330;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: cardWidth, height: 100, child: child))
              .toList(),
        );
      },
    );
  }
}

class _StockMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _StockMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColours.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColours.blue, size: 22),
                  ),
                  const Spacer(),

                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColours.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? trailing;

  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: PageTitle(title: title, subtitle: subtitle),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: trailing!,
              ),
          ],
        ),
        ...children,
      ],
    );
  }
}

class _DailyStockCountPage extends StatefulWidget {
  final UserRole role;
  final List<StockSku> skus;
  final List<StockSubmission> submissions;
  final VoidCallback onBack;
  final Future<void> Function(StockSubmission submission) onSubmitStockCheck;
  final Future<void> Function(String skuId, double balance, String updatedBy)
      onUpdateSkuBalance;
  final void Function(List<String> skuIds) onResetCountTimers;

  const _DailyStockCountPage({
    required this.role,
    required this.skus,
    required this.submissions,
    required this.onBack,
    required this.onSubmitStockCheck,
    required this.onUpdateSkuBalance,
    required this.onResetCountTimers,
  });

  @override
  State<_DailyStockCountPage> createState() => _DailyStockCountPageState();
}

class _DailyStockCountPageState extends State<_DailyStockCountPage> {
  late final Map<String, TextEditingController> controllers;
  late final Map<String, TextEditingController> notes;
  late final Map<String, bool> completedBySku;
  late final Map<String, bool> autoSavedBySku;
  bool showCountErrors = false;
  String countTagFilter = 'All';

  String get submittedBy {
    if (widget.role == UserRole.head) return headId;
    if (widget.role == UserRole.manager) return managerId;
    return staffId;
  }

  void refreshProgressBars() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final sku in widget.skus)
        sku.id: TextEditingController(text: formatStockNumber(sku.currentBalanceValue)),
    };
    for (final controller in controllers.values) {
      controller.addListener(refreshProgressBars);
    }
    notes = {
      for (final sku in widget.skus) sku.id: TextEditingController(),
    };
    autoSavedBySku = {
      for (final sku in widget.skus) sku.id: !canEditCountSku(sku),
    };
    completedBySku = {
      for (final sku in widget.skus) sku.id: !canEditCountSku(sku),
    };
  }

  @override
  void didUpdateWidget(covariant _DailyStockCountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final sku in widget.skus) {
      if (controllers.containsKey(sku.id)) continue;
      final controller = TextEditingController(
        text: formatStockNumber(sku.currentBalanceValue),
      )..addListener(refreshProgressBars);
      controllers[sku.id] = controller;
      notes[sku.id] = TextEditingController();
      final editable = canEditCountSku(sku);
      autoSavedBySku[sku.id] = !editable;
      completedBySku[sku.id] = !editable;
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final controller in notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get countTagOptions {
    final tags = widget.skus
        .map((sku) => sku.location.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...tags];
  }

  List<StockSku> filteredCountSkus(String activeFilter) {
    if (activeFilter == 'All') return widget.skus;
    return widget.skus.where((sku) => sku.location == activeFilter).toList();
  }

  DateTime countCycleStart(StockSku sku, DateTime now) {
    final parts = sku.resetTime.split(':');
    final hour = parts.isEmpty ? 8 : int.tryParse(parts.first) ?? 8;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    var start = DateTime(now.year, now.month, now.day, hour, minute);
    if (now.isBefore(start)) start = start.subtract(const Duration(days: 1));
    return start;
  }

  StockSubmission? latestSubmissionFor(StockSku sku) {
    final start = countCycleStart(sku, DateTime.now());
    final end = start.add(const Duration(days: 1));
    for (final submission in widget.submissions) {
      if (submission.stockTaskId == sku.id &&
          !submission.capturedAt.isBefore(start) &&
          submission.capturedAt.isBefore(end)) {
        return submission;
      }
    }
    return null;
  }

  bool canEditCountSku(StockSku sku) {
    final alreadySubmitted = latestSubmissionFor(sku) != null;
    return sku.active && sku.coolingPeriod && !alreadySubmitted;
  }

  void openSkuPhotoPreview(StockSku sku) {
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.7,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stockBottomSheetHandle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sku.name,
                        style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(child: _SkuPhotoThumb(sku: sku, size: 260)),
              ],
            ),
          ),
        );
      },
    );
  }

  void openSkuBalanceKeypad(StockSku sku) {
    final text = AppTextScope.of(context);
    if (!canEditCountSku(sku)) {
      showWarningSnackBar(context, text.t('Submitted counts cannot be edited.'));
      return;
    }
    var enteredText = controllers[sku.id]!.text;
    var firstTap = true;
    String? keypadError;

    void addKey(String key, void Function(void Function()) setSheetState) {
      setSheetState(() {
        keypadError = null;
        if (key == 'back') {
          if (enteredText.isNotEmpty) {
            enteredText = enteredText.substring(0, enteredText.length - 1);
          }
          firstTap = false;
          return;
        }
        if (key == 'clear') {
          enteredText = '';
          firstTap = false;
          return;
        }
        if (key == '.' && enteredText.contains('.') && !firstTap) return;
        final base = firstTap ? '' : enteredText;
        final next = base == '0' && key != '.' ? key : base + key;
        if (RegExp(r'^\d*\.?\d{0,2}$').hasMatch(next)) {
          enteredText = next;
          firstTap = false;
        }
      });
    }

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.88,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final enteredBalance = double.tryParse(enteredText.trim()) ?? 0;
            final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  stockBottomSheetHandle(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sku.name,
                          style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${formatStockNumber(enteredBalance)} ${sku.unit}',
                    style: const TextStyle(
                      fontSize: AppTextSize.s34,
                      fontWeight: FontWeight.w700,
                      color: AppColours.textMain,
                    ),
                  ),
                  if (keypadError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      keypadError!,
                      style: const TextStyle(
                        color: AppColours.red,
                        fontSize: AppTextSize.s13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _SkuBalanceSummary(sku: sku, currentBalance: enteredBalance),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: keys.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.0,
                    ),
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      return _NumberPadButton(
                        label: key == 'back' ? '' : key,
                        icon: key == 'back' ? Icons.backspace_outlined : null,
                        onTap: () => addKey(key, setSheetState),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Clear'),
                          icon: Icons.clear_rounded,
                          outlined: true,
                          onPressed: () => addKey('clear', setSheetState),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Save'),
                          icon: Icons.check_rounded,
                          onPressed: () {
                            final parsedBalance = double.tryParse(enteredText.trim());
                            if (parsedBalance == null) {
                              AppFeedback.warning();
                              setSheetState(() => keypadError = text.t('Valid number required'));
                              return;
                            }
                            controllers[sku.id]!.text = formatStockNumber(parsedBalance);
                            setState(() {
                              completedBySku[sku.id] = true;
                              showCountErrors = false;
                            });
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> submit() async {
    final text = AppTextScope.of(context);
    var hasInvalid = false;
    var missingPhoto = false;

    final skusToSubmit = widget.skus.where(canEditCountSku).toList();

    for (final sku in skusToSubmit) {
      final entered = double.tryParse(controllers[sku.id]!.text.trim());
      if (entered == null) {
        hasInvalid = true;
        break;
      }
      if (completedBySku[sku.id] != true) {
        missingPhoto = true;
      }
    }

    if (hasInvalid || missingPhoto) {
      AppFeedback.warning();
      setState(() => showCountErrors = true);
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: 'Submit Daily Stock Count?',
      details:
          'This will create stock-count records and update the selected SKU balances.',
    );
    if (!confirmed || !mounted) return;

    for (final sku in skusToSubmit) {
      final currentBalance = double.parse(controllers[sku.id]!.text.trim());
      final note = notes[sku.id]!.text.trim();
      final belowMinimum = currentBalance < sku.minimumBalanceValue;
      final capturedAt = DateTime.now();
      final submitted = await runStockRequest(
        context,
        () => widget.onSubmitStockCheck(
          StockSubmission(
            id: 'COUNT${capturedAt.millisecondsSinceEpoch}_${sku.id}',
            stockTaskId: sku.id,
            submittedBy: submittedBy,
            submittedAt: 'Submitted just now',
            capturedAt: capturedAt,
            stockPhotoName: 'daily_${sku.id.toLowerCase()}_camera.jpg',
            invoicePhotoName: 'Not required for daily count',
            previousBalanceValue: sku.currentBalanceValue,
            currentBalanceValue: currentBalance,
            belowMinimumBalance: belowMinimum,
            checkedItems: const {'daily_count': true},
            remarks: {'note': note.isEmpty ? 'No remark provided.' : note},
          ),
        ),
      );
      if (!submitted || !mounted) return;
    }

    widget.onResetCountTimers(skusToSubmit.map((sku) => sku.id).toList());
    showSuccessSnackBar(context, text.t('Daily stock count submitted'));
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final tagOptions = countTagOptions;
    final activeTagFilter = tagOptions.contains(countTagFilter) ? countTagFilter : 'All';
    final visibleSkus = filteredCountSkus(activeTagFilter);
    final completedCount = widget.skus.where((sku) {
      final hasNumber = double.tryParse(controllers[sku.id]!.text.trim()) != null;
      return hasNumber && completedBySku[sku.id] == true;
    }).length;
    final requiredSkus = widget.skus.where(canEditCountSku).toList();
    final requiredCompleted = requiredSkus.every((sku) {
      final hasNumber = double.tryParse(controllers[sku.id]!.text.trim()) != null;
      return hasNumber && completedBySku[sku.id] == true;
    });
    final canSubmit = requiredSkus.isNotEmpty && requiredCompleted;

    return _PageScaffold(
      title: text.t('Count'),
      subtitle: text.t('Tap photo to view. Tap balance to update.'),
      onBack: widget.onBack,
      children: [
        WhiteCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${text.t('Today')}: $completedCount / ${widget.skus.length} ${text.t('completed')}',
                  style: const TextStyle(
                    fontSize: AppTextSize.s16,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SmallStatusPill(
                text: canSubmit ? text.t('Ready') : text.t('Pending'),
                textColour: canSubmit
                    ? AppColours.green
                    : AppColours.red,
                backgroundColour: canSubmit
                    ? AppColours.greenSoft
                    : AppColours.redSoft,
              ),
            ],
          ),
        ),
        _CountTagFilterChips(
          options: tagOptions,
          value: activeTagFilter,
          onChanged: (value) => setState(() => countTagFilter = value),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: visibleSkus.map((sku) {
                final enteredBalance = double.tryParse(controllers[sku.id]!.text.trim()) ??
                    sku.currentBalanceValue;
                final completed = completedBySku[sku.id] ?? false;
                final autoSaved = autoSavedBySku[sku.id] ?? false;
                final editable = canEditCountSku(sku);

                return SizedBox(
                  width: cardWidth,
                  child: _DailyStockMiniCard(
                    sku: sku,
                    currentBalance: enteredBalance,
                    completed: completed,
                    autoSaved: autoSaved,
                    editable: editable,
                    onPhotoTap: () => openSkuPhotoPreview(sku),
                    onBalanceTap: () => openSkuBalanceKeypad(sku),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (showCountErrors && !canSubmit) ...[
          const SizedBox(height: 10),
          const Text(
            'Complete all pending items',
            style: TextStyle(
              color: AppColours.red,
              fontSize: AppTextSize.s13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 8),
        PrimaryButton(
          text: text.t('Submit Daily Count'),
          icon: Icons.send_rounded,
          onPressed: canSubmit ? submit : null,
        ),
      ],
    );
  }
}

class _CountTagFilterChips extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _CountTagFilterChips({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final selected = option == value;
          final label = option == 'All' ? text.t('All') : option;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Pressable(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColours.blue : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? AppColours.blue : AppColours.border),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColours.blue.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTextSize.s13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColours.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NumberPadButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumberPadButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColours.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColours.border),
        ),
        child: icon == null
            ? Text(
                label,
                style: const TextStyle(
                  fontSize: AppTextSize.s26,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textMain,
                ),
              )
            : Icon(icon, size: 24, color: AppColours.textMain),
      ),
    );
  }
}

class _SkuPhotoThumb extends StatelessWidget {
  final StockSku sku;
  final double size;
  final bool showCountTick;
  final Uint8List? overrideBytes;
  final BoxFit fit;

  const _SkuPhotoThumb({
    required this.sku,
    required this.size,
    this.showCountTick = false,
    this.overrideBytes,
    this.fit = BoxFit.cover,
  });

  IconData get _fallbackIcon {
    final value = '${sku.name} ${sku.photoPath}'.toLowerCase();
    if (value.contains('chicken')) return Icons.set_meal_outlined;
    if (value.contains('rice')) return Icons.rice_bowl_outlined;
    if (value.contains('cup')) return Icons.local_drink_outlined;
    if (value.contains('egg')) return Icons.egg_outlined;
    if (value.contains('milk')) return Icons.local_drink_outlined;
    if (value.contains('oil')) return Icons.oil_barrel_outlined;
    if (value.contains('tomato') || value.contains('lettuce')) return Icons.eco_outlined;
    if (value.contains('meat')) return Icons.restaurant_menu_outlined;
    if (value.contains('pack')) return Icons.inventory_2_outlined;
    return Icons.image_outlined;
  }

  String? get _samplePhotoUrl {
    switch (sku.photoPath) {
      case 'sample:chicken':
        return 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=240&q=70';
      case 'sample:rice':
        return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=240&q=70';
      case 'sample:cold_cup':
        return 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=240&q=70';
      case 'sample:egg':
        return 'https://images.unsplash.com/photo-1587486913049-53fc88980cfc?auto=format&fit=crop&w=240&q=70';
      case 'sample:tomato':
        return 'https://images.unsplash.com/photo-1561136594-7f68413baa99?auto=format&fit=crop&w=240&q=70';
      case 'sample:lettuce':
        return 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?auto=format&fit=crop&w=240&q=70';
      case 'sample:milk':
        return 'https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=240&q=70';
      case 'sample:oil':
        return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=240&q=70';
      case 'sample:sugar':
        return 'https://images.unsplash.com/photo-1581268497089-7a975fb491a3?auto=format&fit=crop&w=240&q=70';
      case 'sample:sauce':
        return 'https://images.unsplash.com/photo-1472476443507-c7a5948772fc?auto=format&fit=crop&w=240&q=70';
      case 'sample:pasta':
        return 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=240&q=70';
      case 'sample:dairy':
        return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=240&q=70';
      case 'sample:coconut':
        return 'https://images.unsplash.com/photo-1580984969071-a8da5656c2fb?auto=format&fit=crop&w=240&q=70';
      case 'sample:flour':
        return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=240&q=70';
      case 'sample:frozen':
        return 'https://images.unsplash.com/photo-1518013431117-eb1465fa5752?auto=format&fit=crop&w=240&q=70';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = sku.photoPath.trim().isNotEmpty;
    final samplePhotoUrl = _samplePhotoUrl;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasPhoto ? const Color(0xFFEAF3FF) : AppColours.background,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColours.border),
      ),
      alignment: Alignment.center,
      child: Icon(_fallbackIcon, size: size * 0.56, color: hasPhoto ? AppColours.blue : AppColours.textMuted),
    );
    final storageKey = sku.photoPath.trim();
    final storedThumbnail = storageKey.endsWith('.jpg') || storageKey.endsWith('.png');
    final Widget photo;
    final localBytes = overrideBytes;
    if (localBytes != null && localBytes.isNotEmpty) {
      photo = Image.memory(
        localBytes,
        width: size,
        height: size,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (samplePhotoUrl != null) {
      photo = Image.network(
        samplePhotoUrl,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (storedThumbnail) {
      final mediaScope = _StockMediaScope.of(context);
      photo = FutureBuilder<Uint8List>(
        future: mediaScope.loadThumbnail(storageKey),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return fallback;
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    } else {
      photo = fallback;
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: photo,
        ),
        if (showCountTick)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: size * 0.34, height: size * 0.34,
              decoration: const BoxDecoration(color: AppColours.green, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: size * 0.24, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

Future<void> showSkuPhotoViewer(
  BuildContext context, {
  required StockSku sku,
  Uint8List? overrideBytes,
}) async {
  final mediaScope = context.getInheritedWidgetOfExactType<_StockMediaScope>();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) {
        Widget page = Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(sku.name),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(80),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _SkuPhotoThumb(
                    sku: sku,
                    size: MediaQuery.of(routeContext).size.width - 24,
                    overrideBytes: overrideBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
        if (mediaScope != null) {
          page = _StockMediaScope(
            api: mediaScope.api,
            loadThumbnail: mediaScope.loadThumbnail,
            loadReceivingPhoto: mediaScope.loadReceivingPhoto,
            child: page,
          );
        }
        return page;
      },
    ),
  );
}

class _DailyStockMiniCard extends StatelessWidget {
  final StockSku sku;
  final double currentBalance;
  final bool completed;
  final bool autoSaved;
  final bool editable;
  final VoidCallback onPhotoTap;
  final VoidCallback onBalanceTap;

  const _DailyStockMiniCard({
    required this.sku,
    required this.currentBalance,
    required this.completed,
    required this.autoSaved,
    required this.editable,
    required this.onPhotoTap,
    required this.onBalanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final maximum = sku.maximumBalanceValue <= 0 ? 1.0 : sku.maximumBalanceValue;
    final ratio = (currentBalance / maximum).clamp(0.0, 1.0).toDouble();
    final belowMinimum = currentBalance < sku.minimumBalanceValue;
    final statusColour = belowMinimum ? AppColours.red : AppColours.green;
    final countedNow = editable && completed;
    final pendingInput = editable && !completed;
    final statusIcon = countedNow
        ? Icons.check_circle_rounded
        : pendingInput
            ? Icons.radio_button_unchecked_rounded
            : Icons.lock_rounded;
    final statusIconColour = countedNow
        ? AppColours.green
        : pendingInput
            ? AppColours.orange
            : AppColours.textMuted;
    final statusIconBackground = countedNow
        ? const Color(0xFFCFF4DE)
        : pendingInput
            ? AppColours.orangeSoft
            : AppColours.background;

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: AnimatedOpacity(
        opacity: autoSaved ? 0.55 : 1,
        duration: const Duration(milliseconds: 180),
        child: Pressable(
          onTap: editable && !autoSaved ? onBalanceTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onPhotoTap,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: countedNow ? AppColours.greenSoft : AppColours.background,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _SkuPhotoThumb(sku: sku, size: 48, showCountTick: countedNow),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sku.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTextSize.s16,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              color: AppColours.textMain,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: AppColours.border),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 450),
                                          curve: Curves.easeOutCubic,
                                          width: constraints.maxWidth * ratio,
                                          decoration: BoxDecoration(
                                            color: statusColour,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${formatStockNumber(currentBalance)} ${sku.unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTextSize.s14,
                                  color: statusColour,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: statusIconBackground,
                        shape: BoxShape.circle,
                        border: Border.all(color: statusIconColour.withValues(alpha: countedNow ? 0.50 : 0.35)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(statusIcon, size: 17, color: statusIconColour),
                    ),
                  ],
                ),
                if (countedNow) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Icon(Icons.edit_outlined, size: 14, color: AppColours.blue),
                      SizedBox(width: 4),
                      Text(
                        'Tap to edit',
                        style: TextStyle(
                          fontSize: AppTextSize.s12,
                          color: AppColours.blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockReceivingPage extends StatefulWidget {
  final UserRole role;
  final List<SupplierProfile> suppliers;
  final List<StockSku> skus;
  final VoidCallback onBack;
  final Future<void> Function(StockReceivingRecord record) onSubmitReceiving;
  final Future<void> Function(String skuId, double balance, String updatedBy)
      onUpdateSkuBalance;

  const _StockReceivingPage({
    required this.role,
    required this.suppliers,
    required this.skus,
    required this.onBack,
    required this.onSubmitReceiving,
    required this.onUpdateSkuBalance,
  });

  @override
  State<_StockReceivingPage> createState() => _StockReceivingPageState();
}

class _ReceivingDraftItem {
  final StockSku sku;
  final StockReceivingItem item;

  const _ReceivingDraftItem({
    required this.sku,
    required this.item,
  });
}

class _StockReceivingPageState extends State<_StockReceivingPage> {
  SupplierProfile? selectedSupplier;
  StockSku? selectedSku;
  final searchController = TextEditingController();
  final invoiceQtyController = TextEditingController();
  final receivedQtyController = TextEditingController();
  final noteController = TextEditingController();
  bool checklistChecked = false;
  final Map<String, String> supplierInvoicePhotoNames = <String, String>{};
  final Map<String, String> supplierGoodsPhotoNames = <String, String>{};
  final Map<String, List<_ReceivingDraftItem>> supplierReceivingDrafts = <String, List<_ReceivingDraftItem>>{};
  final Set<String> submittedSupplierBatchIds = <String>{};
  final Set<String> selectedSupplierBatchIds = <String>{};
  bool selectingSupplierBatches = false;
  bool showReceivingErrors = false;

  String get receivedBy => widget.role == UserRole.head ? headId : managerId;

  @override
  void initState() {
    super.initState();
    selectedSupplier = null;
  }

  @override
  void dispose() {
    searchController.dispose();
    invoiceQtyController.dispose();
    receivedQtyController.dispose();
    noteController.dispose();
    super.dispose();
  }

  List<SupplierProfile> get filteredSuppliers {
    final query = searchController.text.trim().toLowerCase();
    final source = query.isEmpty
        ? widget.suppliers
        : widget.suppliers.where((supplier) {
            return [
              supplier.supplierName,
              supplier.contactPerson,
              supplier.phone,
              supplier.address,
              supplier.notes,
            ].join(' ').toLowerCase().contains(query);
          });
    return _sortSuppliersAlphabetically(source);
  }

  List<StockSku> get availableSkus {
    if (selectedSupplier == null) return widget.skus;
    final linked = widget.skus
        .where((sku) => sku.supplierIds.contains(selectedSupplier!.id))
        .toList();
    return linked.isEmpty ? widget.skus : linked;
  }

  List<StockSku> skusForSupplier(SupplierProfile supplier) {
    final linked = widget.skus
        .where((sku) => sku.supplierIds.contains(supplier.id))
        .toList();
    return linked.isEmpty ? widget.skus : linked;
  }

  bool hasSupplierInvoicePhoto(SupplierProfile supplier) {
    return supplierInvoicePhotoNames[supplier.id]?.isNotEmpty ?? false;
  }

  String supplierInvoicePhotoName(SupplierProfile supplier) {
    return supplierInvoicePhotoNames[supplier.id] ?? '';
  }

  Future<void> captureSupplierInvoicePhoto(SupplierProfile supplier) async {
    final text = AppTextScope.of(context);
    try {
      await showCameraOnlyCaptureDialog(
        context,
        title: text.t('Invoice Photo'),
        subtitle: text.t('Take a fresh photo of the supplier invoice.'),
        onCaptured: (filePath) async {
          final storageKey = await _StockMediaScope.of(context)
              .api
              .uploadStockReceivingPhoto(filePath);
          if (!mounted) return;
          setState(() {
            supplierInvoicePhotoNames[supplier.id] = storageKey;
            showReceivingErrors = false;
          });
          showSuccessSnackBar(context, text.t('Invoice photo captured'));
        },
      );
    } on EastAppApiException {
      // The API layer already surfaces the failure and clears processing state.
    }
  }

  bool hasSupplierGoodsPhoto(SupplierProfile supplier) {
    return supplierGoodsPhotoNames[supplier.id]?.isNotEmpty ?? false;
  }

  String supplierGoodsPhotoName(SupplierProfile supplier) {
    return supplierGoodsPhotoNames[supplier.id] ?? '';
  }

  Future<void> captureSupplierGoodsPhoto(SupplierProfile supplier) async {
    final text = AppTextScope.of(context);
    try {
      await showCameraOnlyCaptureDialog(
        context,
        title: text.t('Goods Received Photo'),
        subtitle: text.t('Take one photo showing the goods received for this supplier.'),
        onCaptured: (filePath) async {
          final storageKey = await _StockMediaScope.of(context)
              .api
              .uploadStockReceivingPhoto(filePath);
          if (!mounted) return;
          setState(() {
            supplierGoodsPhotoNames[supplier.id] = storageKey;
            showReceivingErrors = false;
          });
          showSuccessSnackBar(context, text.t('Goods received photo captured'));
        },
      );
    } on EastAppApiException {
      // The API layer already surfaces the failure and clears processing state.
    }
  }

  List<_ReceivingDraftItem> draftsForSupplier(SupplierProfile supplier) {
    return supplierReceivingDrafts[supplier.id] ?? const <_ReceivingDraftItem>[];
  }

  bool isSupplierBatchSubmitted(SupplierProfile supplier) {
    return submittedSupplierBatchIds.contains(supplier.id);
  }

  bool canSubmitSupplierBatch(SupplierProfile supplier) {
    return !isSupplierBatchSubmitted(supplier) &&
        hasSupplierInvoicePhoto(supplier) &&
        hasSupplierGoodsPhoto(supplier) &&
        draftsForSupplier(supplier).isNotEmpty;
  }

  List<SupplierProfile> selectedSubmittableSuppliersFrom(List<SupplierProfile> suppliers) {
    return suppliers
        .where((supplier) =>
            selectedSupplierBatchIds.contains(supplier.id) &&
            canSubmitSupplierBatch(supplier))
        .toList();
  }

  void startSupplierBatchSelection() {
    AppFeedback.select();
    setState(() {
      selectingSupplierBatches = true;
      selectedSupplierBatchIds.clear();
    });
  }

  void cancelSupplierBatchSelection() {
    AppFeedback.select();
    setState(() {
      selectingSupplierBatches = false;
      selectedSupplierBatchIds.clear();
    });
  }

  void toggleSupplierBatchSelection(SupplierProfile supplier) {
    if (!selectingSupplierBatches || !canSubmitSupplierBatch(supplier)) {
      if (selectingSupplierBatches) AppFeedback.warning();
      return;
    }

    setState(() {
      if (selectedSupplierBatchIds.contains(supplier.id)) {
        selectedSupplierBatchIds.remove(supplier.id);
      } else {
        selectedSupplierBatchIds.add(supplier.id);
      }
    });
  }

  bool syncSkuReceivingDraft({bool showFeedback = false}) {
    final supplier = selectedSupplier;
    final sku = selectedSku;
    final invoiceQty = double.tryParse(invoiceQtyController.text.trim());
    final receivedQty = double.tryParse(receivedQtyController.text.trim());

    final checklistRequired = sku?.receivingChecklist.isNotEmpty ?? false;

    if (supplier == null || sku == null || invoiceQty == null || receivedQty == null || (checklistRequired && !checklistChecked)) {
      if (showFeedback) {
        AppFeedback.warning();
        setState(() => showReceivingErrors = true);
      }
      return false;
    }

    if (isSupplierBatchSubmitted(supplier)) {
      if (showFeedback) AppFeedback.warning();
      return false;
    }

    final draft = _ReceivingDraftItem(
      sku: sku,
      item: StockReceivingItem(
        skuId: sku.id,
        skuName: sku.name,
        invoiceQuantity: invoiceQty,
        receivedQuantity: receivedQty,
        unit: sku.unit,
        condition: checklistChecked ? 'Checked' : 'Unchecked',
        note: noteController.text.trim().isEmpty
            ? 'No remark provided.'
            : noteController.text.trim(),
      ),
    );

    setState(() {
      final existing = List<_ReceivingDraftItem>.from(draftsForSupplier(supplier));
      final index = existing.indexWhere((entry) => entry.sku.id == sku.id);
      if (index >= 0) {
        existing[index] = draft;
      } else {
        existing.add(draft);
      }
      supplierReceivingDrafts[supplier.id] = existing;
      showReceivingErrors = false;
    });

    if (showFeedback) {
      AppFeedback.select();
    }
    return true;
  }

  Future<bool> applySupplierBatchSubmission(
    SupplierProfile supplier,
  ) async {
    final drafts = draftsForSupplier(supplier);
    final record = StockReceivingRecord(
      id: 'REC${supplier.id}_${DateTime.now().microsecondsSinceEpoch}',
      supplierId: supplier.id,
      supplierName: supplier.supplierName,
      receivedBy: receivedBy,
      receivedAt: 'Submitted just now',
      capturedAt: DateTime.now(),
      invoicePhotoName: supplierInvoicePhotoName(supplier),
      goodsPhotoName: supplierGoodsPhotoName(supplier),
      items: drafts.map((draft) => draft.item).toList(),
    );

    final submitted = await runStockRequest(
      context,
      () => widget.onSubmitReceiving(record),
    );
    if (submitted && mounted) {
      setState(() => submittedSupplierBatchIds.add(supplier.id));
    }
    return submitted;
  }

  Future<void> submitSupplierBatch(SupplierProfile supplier) async {
    final text = AppTextScope.of(context);
    if (!canSubmitSupplierBatch(supplier)) {
      AppFeedback.warning();
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: 'Submit Receiving?',
      details:
          'This will create the receiving record and update the received SKU balances.',
    );
    if (!confirmed || !mounted) return;

    final submitted = await applySupplierBatchSubmission(supplier);
    if (!submitted || !mounted) return;
    setState(() => showReceivingErrors = false);
    showSuccessSnackBar(context, text.t('Receiving submitted'));
  }

  Future<void> applyBulkSupplierBatchSubmission(
    List<SupplierProfile> suppliers,
  ) async {
    final text = AppTextScope.of(context);
    if (suppliers.isEmpty) {
      AppFeedback.warning();
      return;
    }

    for (final supplier in suppliers) {
      if (!canSubmitSupplierBatch(supplier)) continue;
      final submitted = await applySupplierBatchSubmission(supplier);
      if (!submitted || !mounted) return;
    }

    setState(() {
      selectingSupplierBatches = false;
      selectedSupplierBatchIds.clear();
      showReceivingErrors = false;
    });
    Navigator.of(context).pop();
    showSuccessSnackBar(context, text.t('Receiving submitted'));
  }

  void showBulkSupplierSubmitConfirmation(List<SupplierProfile> suppliers) {
    final text = AppTextScope.of(context);
    if (suppliers.isEmpty) {
      AppFeedback.warning();
      return;
    }

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.86,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stockBottomSheetHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.t('Confirm Submit All'),
                      style: const TextStyle(fontSize: AppTextSize.s22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColours.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColours.orange.withValues(alpha: 0.30)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColours.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bulk submission is risky. Check every record. This action cannot be undone.\n批量提交有风险。请逐项确认。此操作无法撤回。',
                        style: TextStyle(fontSize: AppTextSize.s12, color: AppColours.orange, fontWeight: FontWeight.w800, height: 1.25),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text.t('Please confirm these receiving records before submitting.'),
                style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: AppColours.border),
                    defaultColumnWidth: const FlexColumnWidth(),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppColours.background),
                        children: const [
                          _BulkSummaryCell('Supplier', header: true),
                          _BulkSummaryCell('SKU', header: true),
                          _BulkSummaryCell('Receive', header: true),
                          _BulkSummaryCell('Invoice', header: true),
                          _BulkSummaryCell('State', header: true),
                        ],
                      ),
                      ...suppliers.expand((supplier) {
                        return draftsForSupplier(supplier).map((draft) {
                          final item = draft.item;
                          return TableRow(
                            children: [
                              _BulkSummaryCell(supplier.supplierName),
                              _BulkSummaryCell(item.skuName),
                              _BulkSummaryCell('${formatStockNumber(item.receivedQuantity)} ${item.unit}'),
                              _BulkSummaryCell('${formatStockNumber(item.invoiceQuantity)} ${item.unit}'),
                              _BulkSummaryCell(item.condition),
                            ],
                          );
                        });
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: text.t('Cancel'),
                      icon: Icons.close_rounded,
                      outlined: true,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      text: text.t('Confirm'),
                      icon: Icons.send_rounded,
                      onPressed: () => applyBulkSupplierBatchSubmission(suppliers),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void resetReceivingForm(SupplierProfile supplier, StockSku sku) {
    selectedSupplier = supplier;
    selectedSku = sku;
    final existingDrafts = draftsForSupplier(supplier);
    final existingIndex = existingDrafts.indexWhere((entry) => entry.sku.id == sku.id);
    if (existingIndex >= 0) {
      final item = existingDrafts[existingIndex].item;
      invoiceQtyController.text = formatStockNumber(item.invoiceQuantity);
      receivedQtyController.text = formatStockNumber(item.receivedQuantity);
      noteController.text = item.note == 'No remark provided.' ? '' : item.note;
      checklistChecked = item.condition.toLowerCase() == 'checked' || item.condition.toLowerCase() == 'good';
    } else {
      invoiceQtyController.clear();
      receivedQtyController.clear();
      noteController.clear();
      checklistChecked = false;
    }
    showReceivingErrors = false;
  }

  Widget compactCardGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 330;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: cardWidth, height: 96, child: child))
              .toList(),
        );
      },
    );
  }

  Widget receivingSupplierGridCard(BuildContext context, SupplierProfile supplier) {
    final text = AppTextScope.of(context);

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: () => showReceivingSkuPicker(supplier),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColours.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColours.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      supplier.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text.t('Select SKU'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget receivingSkuGridCard(BuildContext context, StockSku sku, VoidCallback onTap) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SkuPhotoThumb(sku: sku, size: 56),
              const SizedBox(height: 8),
              Text(
                sku.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showReceivingSkuPicker(SupplierProfile supplier) {
    final skuOptions = skusForSupplier(supplier);

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.82,
      builder: (sheetContext) {
        return _ReceivingSkuPickerSheet(
          supplier: supplier,
          skuOptions: skuOptions,
          savedSkuIds: draftsForSupplier(supplier).map((entry) => entry.sku.id).toSet(),
          onSelectSku: (sku) {
            Navigator.of(sheetContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showReceivingForm(supplier, sku);
            });
          },
        );
      },
    );
  }

  Widget buildSupplierSubmissionToolbar(List<SupplierProfile> suppliers) {
    final text = AppTextScope.of(context);
    final selectableCount = suppliers.where(canSubmitSupplierBatch).length;
    final selectedCount = selectedSubmittableSuppliersFrom(suppliers).length;

    if (!selectingSupplierBatches) {
      return Row(
        children: [
          const Spacer(),
          TextButton.icon(
            onPressed: selectableCount == 0 ? null : startSupplierBatchSelection,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: Text(text.t('Select')),
          ),
        ],
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: cancelSupplierBatchSelection,
          child: Text(text.t('Cancel')),
        ),
        Expanded(
          child: Text(
            '$selectedCount selected',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTextSize.s13,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: selectedCount == 0
              ? null
              : () => showBulkSupplierSubmitConfirmation(selectedSubmittableSuppliersFrom(suppliers)),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(
            text.t('Submit All'),
            style: TextStyle(
              color: selectedCount == 0 ? AppColours.textMuted : AppColours.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  void showReceivingForm(SupplierProfile supplier, StockSku sku) {
    setState(() => resetReceivingForm(supplier, sku));
    final mediaScope = _StockMediaScope.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _StockMediaScope(
          api: mediaScope.api,
          loadThumbnail: mediaScope.loadThumbnail,
          loadReceivingPhoto: mediaScope.loadReceivingPhoto,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
            final text = AppTextScope.of(context);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            void updateSheet(VoidCallback action) {
              setState(action);
              setSheetState(() {});
            }

            void closeFormAndReopenSkuPicker({bool useTapFeedback = false, bool useBackFeedback = false}) {
              if (useTapFeedback) {
                AppFeedback.tap();
              } else if (useBackFeedback) {
                AppFeedback.swipeBack();
              }
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) showReceivingSkuPicker(supplier);
              });
            }

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  closeFormAndReopenSkuPicker(useBackFeedback: true);
                }
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8DEE8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => closeFormAndReopenSkuPicker(useTapFeedback: true),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: text.t('Back'),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text.t('Receiving'),
                                    style: const TextStyle(
                                      fontSize: AppTextSize.s22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    supplier.supplierName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: AppTextSize.s14,
                                      color: AppColours.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        WhiteCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(text.t('SKU')),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColours.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColours.border),
                                ),
                                child: Row(
                                  children: [
                                    _SkuPhotoThumb(sku: sku, size: 44),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sku.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: AppTextSize.s16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sku.unit,
                                            style: const TextStyle(
                                              fontSize: AppTextSize.s13,
                                              color: AppColours.textMuted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DialogInput(
                                      label: text.t('Invoice Qty'),
                                      controller: invoiceQtyController,
                                      hint: text.t('Qty on invoice'),
                                      suffixText: selectedSku?.unit,
                                      errorText: showReceivingErrors && double.tryParse(invoiceQtyController.text.trim()) == null
                                          ? text.t('Required')
                                          : null,
                                      onChanged: (_) {
                                        if (showReceivingErrors) updateSheet(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DialogInput(
                                      label: text.t('Received Qty'),
                                      controller: receivedQtyController,
                                      hint: text.t('Actual received'),
                                      suffixText: selectedSku?.unit,
                                      errorText: showReceivingErrors && double.tryParse(receivedQtyController.text.trim()) == null
                                          ? text.t('Required')
                                          : null,
                                      onChanged: (_) {
                                        if (showReceivingErrors) updateSheet(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _FieldLabel(text.t('Receiving Checklist')),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColours.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: showReceivingErrors && sku.receivingChecklist.isNotEmpty && !checklistChecked
                                        ? AppColours.red.withValues(alpha: 0.65)
                                        : AppColours.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (sku.receivingChecklist.isEmpty)
                                      const Text(
                                        'No checklist set.',
                                        style: TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w700),
                                      )
                                    else
                                      ...sku.receivingChecklist.asMap().entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 5),
                                          child: Text(
                                            '${entry.key + 1}. ${entry.value}',
                                            style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMain, fontWeight: FontWeight.w700, height: 1.25),
                                          ),
                                        );
                                      }),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => updateSheet(() => checklistChecked = !checklistChecked),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: checklistChecked,
                                            onChanged: (_) => updateSheet(() => checklistChecked = !checklistChecked),
                                          ),
                                          Expanded(
                                            child: Text(
                                              text.t('Checklist checked'),
                                              style: const TextStyle(fontSize: AppTextSize.s14, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (showReceivingErrors && sku.receivingChecklist.isNotEmpty && !checklistChecked) ...[
                                      const SizedBox(height: 4),
                                      Text(text.t('Required'), style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.red, fontWeight: FontWeight.w800)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _DialogInput(
                                label: text.t('Remark'),
                                controller: noteController,
                                hint: text.t('Example: 1kg damaged / item missing'),
                                onChanged: (_) {
                                  if (showReceivingErrors) updateSheet(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: 190,
                            child: PrimaryButton(
                              text: text.t('Save'),
                              icon: Icons.check_circle_outline_rounded,
                              onPressed: () {
                                setState(() => showReceivingErrors = true);
                                final saved = syncSkuReceivingDraft(showFeedback: false);
                                setSheetState(() {});
                                if (saved) closeFormAndReopenSkuPicker();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final items = filteredSuppliers;

    return _PageScaffold(
      title: text.t('Receiving'),
      subtitle: text.t('Capture photos, then SKU.'),
      onBack: widget.onBack,
      children: [
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(text.t('Search')).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 8),
        buildSupplierSubmissionToolbar(items),
        const SizedBox(height: 8),
        if (items.isEmpty)
          WhiteCard(
            padding: const EdgeInsets.all(22),
            child: Text(
              text.t('No supplier found'),
              style: const TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
            ),
          )
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ReceivingSupplierActionRow(
                    supplier: items[i],
                    invoiceCaptured: hasSupplierInvoicePhoto(items[i]),
                    goodsCaptured: hasSupplierGoodsPhoto(items[i]),
                    savedSkuCount: draftsForSupplier(items[i]).length,
                    skuCount: skusForSupplier(items[i]).length,
                    submitted: isSupplierBatchSubmitted(items[i]),
                    selecting: selectingSupplierBatches,
                    selected: selectedSupplierBatchIds.contains(items[i].id),
                    selectable: canSubmitSupplierBatch(items[i]),
                    canSubmit: canSubmitSupplierBatch(items[i]),
                    onCaptureInvoice: () => captureSupplierInvoicePhoto(items[i]),
                    onCaptureGoods: () => captureSupplierGoodsPhoto(items[i]),
                    onOpenSku: () => showReceivingSkuPicker(items[i]),
                    onSelectToggle: () => toggleSupplierBatchSelection(items[i]),
                    onSubmit: () => submitSupplierBatch(items[i]),
                  ),
                  if (i != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}




class _SupplierPhotoButton extends StatelessWidget {
  final bool isDone;
  final Color colour;
  final Color background;
  final IconData icon;
  final VoidCallback? onTap;

  const _SupplierPhotoButton({
    required this.isDone,
    required this.colour,
    required this.background,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 40,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colour.withValues(alpha: 0.28)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: colour, size: 20),
            if (isDone)
              Positioned(
                right: 5,
                bottom: 5,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: const BoxDecoration(
                    color: AppColours.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceivingSupplierActionRow extends StatelessWidget {
  final SupplierProfile supplier;
  final bool invoiceCaptured;
  final bool goodsCaptured;
  final VoidCallback onCaptureInvoice;
  final VoidCallback onCaptureGoods;
  final int savedSkuCount;
  final int skuCount;
  final bool submitted;
  final bool selecting;
  final bool selected;
  final bool selectable;
  final bool canSubmit;
  final VoidCallback onOpenSku;
  final VoidCallback onSelectToggle;
  final VoidCallback onSubmit;

  const _ReceivingSupplierActionRow({
    required this.supplier,
    required this.invoiceCaptured,
    required this.goodsCaptured,
    required this.savedSkuCount,
    required this.skuCount,
    required this.submitted,
    required this.selecting,
    required this.selected,
    required this.selectable,
    required this.canSubmit,
    required this.onCaptureInvoice,
    required this.onCaptureGoods,
    required this.onOpenSku,
    required this.onSelectToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (submitted) 'Submitted',
      if (!submitted && supplier.contactPerson.isNotEmpty) supplier.contactPerson,
      if (!submitted && supplier.phone.isNotEmpty) supplier.phone,
      if (!submitted && supplier.address.isNotEmpty) supplier.address,
    ].join(' · ');

    final disabled = submitted || (selecting && !selectable);
    final invoiceColour = invoiceCaptured ? AppColours.green : AppColours.orange;
    final invoiceBg = invoiceCaptured ? AppColours.greenSoft : AppColours.orangeSoft;
    final goodsColour = goodsCaptured ? AppColours.green : AppColours.orange;
    final goodsBg = goodsCaptured ? AppColours.greenSoft : AppColours.orangeSoft;

    return Opacity(
      opacity: disabled ? 0.48 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (selecting) ...[
              _SelectionCircle(selected: selected, enabled: selectable),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Pressable(
                onTap: selecting
                    ? selectable
                        ? onSelectToggle
                        : null
                    : submitted
                        ? null
                        : onOpenSku,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: submitted ? AppColours.background : AppColours.blueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_shipping_outlined,
                          color: submitted ? AppColours.textMuted : AppColours.blue,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.supplierName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTextSize.s17,
                                fontWeight: FontWeight.w700,
                                color: submitted ? AppColours.textMuted : AppColours.textMain,
                              ),
                            ),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTextSize.s12,
                                  color: submitted ? AppColours.textMuted.withValues(alpha: 0.80) : AppColours.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (!submitted && skuCount > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                savedSkuCount >= skuCount
                                    ? '$savedSkuCount SKU received'
                                    : '${skuCount - savedSkuCount} pending',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTextSize.s12,
                                  color: savedSkuCount >= skuCount ? AppColours.green : AppColours.orange,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ] else if (submitted && savedSkuCount > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '$savedSkuCount SKU saved',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s12,
                                  color: AppColours.textMuted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!selecting) ...[
              _SupplierPhotoButton(
                isDone: invoiceCaptured,
                colour: invoiceColour,
                background: invoiceBg,
                icon: Icons.receipt_long_outlined,
                onTap: submitted ? null : onCaptureInvoice,
              ),
              const SizedBox(width: 6),
              _SupplierPhotoButton(
                isDone: goodsCaptured,
                colour: goodsColour,
                background: goodsBg,
                icon: Icons.inventory_2_outlined,
                onTap: submitted ? null : onCaptureGoods,
              ),
              const SizedBox(width: 6),
            ],
            Pressable(
              onTap: selecting
                  ? selectable
                      ? onSelectToggle
                      : null
                  : submitted
                      ? null
                      : canSubmit
                          ? onSubmit
                          : () => AppFeedback.warning(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selecting
                      ? selected
                          ? AppColours.blueSoft
                          : AppColours.background
                      : canSubmit
                          ? AppColours.blueSoft
                          : AppColours.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selecting
                        ? selected
                            ? AppColours.blue.withValues(alpha: 0.32)
                            : AppColours.border
                        : canSubmit
                            ? AppColours.blue.withValues(alpha: 0.28)
                            : AppColours.border,
                  ),
                ),
                child: selecting
                    ? Icon(
                        selected ? Icons.check_rounded : Icons.circle_outlined,
                        color: selected && selectable ? AppColours.blue : AppColours.textMuted.withValues(alpha: 0.45),
                        size: 20,
                      )
                    : Icon(
                        submitted ? Icons.lock_outline_rounded : Icons.send_rounded,
                        color: canSubmit ? AppColours.blue : AppColours.textMuted.withValues(alpha: 0.45),
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivingSkuPickerSheet extends StatefulWidget {
  final SupplierProfile supplier;
  final List<StockSku> skuOptions;
  final Set<String> savedSkuIds;
  final void Function(StockSku sku) onSelectSku;

  const _ReceivingSkuPickerSheet({
    required this.supplier,
    required this.skuOptions,
    required this.savedSkuIds,
    required this.onSelectSku,
  });

  @override
  State<_ReceivingSkuPickerSheet> createState() => _ReceivingSkuPickerSheetState();
}

class _ReceivingSkuPickerSheetState extends State<_ReceivingSkuPickerSheet> {
  late final TextEditingController skuSearchController;

  @override
  void initState() {
    super.initState();
    skuSearchController = TextEditingController();
  }

  @override
  void dispose() {
    skuSearchController.dispose();
    super.dispose();
  }

  List<StockSku> get filteredSkuOptions {
    final query = skuSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.skuOptions;
    return widget.skuOptions.where((sku) {
      return [
        sku.name,
        sku.category,
        sku.location,
        sku.unit,
        sku.assignedStaffName,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Widget receivingSkuGridCard(BuildContext context, StockSku sku) {
    final saved = widget.savedSkuIds.contains(sku.id);

    return Stack(
      children: [
        WhiteCard(
          padding: EdgeInsets.zero,
          child: Pressable(
            onTap: () => widget.onSelectSku(sku),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkuPhotoThumb(sku: sku, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    sku.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s13,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (saved)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColours.greenSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColours.green.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.check_rounded, color: AppColours.green, size: 17),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final items = filteredSkuOptions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          stockBottomSheetHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t('Receiving'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.supplier.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s14,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text.t('Select SKU first.'),
            style: const TextStyle(
              fontSize: AppTextSize.s14,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: skuSearchController,
            style: AppTextStyles.formValue,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(text.t('Search')).copyWith(
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            WhiteCard(
              padding: const EdgeInsets.all(18),
              child: Text(
                text.t('No SKU found'),
                style: const TextStyle(
                  fontSize: AppTextSize.s16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 20) / 3;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items.map((sku) {
                    return SizedBox(
                      width: cardWidth,
                      child: receivingSkuGridCard(context, sku),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RestockMessagePage extends StatefulWidget {
  final List<SupplierProfile> suppliers;
  final List<StockSku> skus;
  final VoidCallback onBack;

  const _RestockMessagePage({
    required this.suppliers,
    required this.skus,
    required this.onBack,
  });

  @override
  State<_RestockMessagePage> createState() => _RestockMessagePageState();
}

class _RestockMessagePageState extends State<_RestockMessagePage> {
  bool lowStockOnly = true;

  SupplierProfile? supplierFor(String supplierId) {
    for (final supplier in widget.suppliers) {
      if (supplier.id == supplierId) return supplier;
    }
    return null;
  }

  List<StockSku> get lowSkus =>
      widget.skus.where((sku) => sku.isBelowMinimumBalance).toList();

  SupplierProfile? preferredSupplierFor(StockSku sku) {
    if (sku.supplierIds.isEmpty) return null;
    return supplierFor(sku.supplierIds.first);
  }

  List<StockSku> get visibleSkus => lowStockOnly ? lowSkus : widget.skus;

  List<_RestockSupplierGroup> supplierGroups({List<StockSku>? source}) {
    final grouped = <String, _RestockSupplierGroup>{};
    for (final sku in source ?? visibleSkus) {
      if (sku.supplierIds.isEmpty) {
        grouped.putIfAbsent(
          'UNASSIGNED',
          () => const _RestockSupplierGroup(supplier: null, skus: <StockSku>[]),
        );
        grouped['UNASSIGNED']!.skus.add(sku);
        continue;
      }

      for (final supplierId in sku.supplierIds) {
        final supplier = supplierFor(supplierId);
        final key = supplier?.id ?? 'UNASSIGNED';
        grouped.putIfAbsent(
          key,
          () => _RestockSupplierGroup(supplier: supplier, skus: <StockSku>[]),
        );
        grouped[key]!.skus.add(sku);
      }
    }
    final groups = grouped.values.toList();
    groups.sort((a, b) => a.supplierName.compareTo(b.supplierName));
    return groups;
  }

  String purchaseDateTime() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final suffix = now.hour >= 12 ? 'pm' : 'am';
    return '${two(now.day)}/${two(now.month)}/${now.year} ${two(hour12)}:${two(now.minute)}$suffix';
  }

  String buildSupplierMessage(_RestockSupplierGroup group) {
    final lines = <String>[];
    for (var i = 0; i < group.skus.length; i++) {
      final sku = group.skus[i];
      lines.add(
        '${i + 1}. ${sku.name} - ${formatStockNumber(sku.suggestedRestockAmount)} ${sku.unit}',
      );
    }
    lines.add('');
    lines.add(purchaseDateTime());
    lines.add('Please confirm availability and delivery time. Thank u.');
    return lines.join('\n');
  }

  String buildAllSupplierMessages() {
    final groups = supplierGroups();
    if (groups.isEmpty) return 'No restock needed today.';
    return groups.map(buildSupplierMessage).join('\n\n---\n\n');
  }

  void copySupplierMessage(BuildContext context, _RestockSupplierGroup group) {
    final text = AppTextScope.of(context);
    Clipboard.setData(ClipboardData(text: buildSupplierMessage(group)));
    showSuccessSnackBar(context, text.t('Supplier restock message copied'));
  }

  void copyAllSupplierMessages(BuildContext context) {
    final text = AppTextScope.of(context);
    Clipboard.setData(ClipboardData(text: buildAllSupplierMessages()));
    showSuccessSnackBar(context, text.t('All supplier messages copied'));
  }

  _RestockSupplierGroup supplierGroupForSku(StockSku sku) {
    final supplier = preferredSupplierFor(sku);
    final skus = visibleSkus.where((candidate) {
      final candidateSupplier = preferredSupplierFor(candidate);
      return candidateSupplier?.id == supplier?.id;
    }).toList();

    return _RestockSupplierGroup(supplier: supplier, skus: skus);
  }

  Widget restockSupplierGridCard(BuildContext context, _RestockSupplierGroup group) {
    final text = AppTextScope.of(context);
    final message = buildSupplierMessage(group);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: () => showRestockMessageDialog(context, message),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColours.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.skus.length} ${text.t('items')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget lowStockGridCard(BuildContext context, StockSku sku) {
    final text = AppTextScope.of(context);
    final group = supplierGroupForSku(sku);
    final supplier = preferredSupplierFor(sku);
    final message = buildSupplierMessage(group);

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: () => showRestockMessageDialog(context, message),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColours.redSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      color: AppColours.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sku.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatStockNumber(sku.suggestedRestockAmount)} ${sku.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s15,
                  color: AppColours.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                supplier?.supplierName ?? text.t('Unassigned Supplier'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${text.t('Current')}: ${formatStockNumber(sku.currentBalanceValue)} ${sku.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget compactCardGrid({
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 330;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: cardWidth, height: 62, child: child))
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final skus = visibleSkus;

    final groups = supplierGroups(source: skus);

    return _PageScaffold(
      title: text.t('Purchase'),
      subtitle: text.t('Tap supplier to preview message.'),
      onBack: widget.onBack,
      children: [
        WhiteCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: lowStockOnly,
              onChanged: (value) => setState(() => lowStockOnly = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                text.t('Low Stock Only'),
                style: const TextStyle(fontSize: AppTextSize.s18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          WhiteCard(
            padding: const EdgeInsets.all(22),
            child: Text(
              lowStockOnly ? text.t('No low-stock SKU today.') : text.t('No SKU found.'),
              style: const TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
            ),
          )
        else
          compactCardGrid(
            children: groups.map((group) => restockSupplierGridCard(context, group)).toList(),
          ),
      ],
    );
  }
}

class _RestockSupplierGroup {
  final SupplierProfile? supplier;
  final List<StockSku> skus;

  const _RestockSupplierGroup({
    required this.supplier,
    required this.skus,
  });

  String get supplierName => supplier?.supplierName ?? 'Unassigned Supplier';
}

void showRestockMessageDialog(BuildContext context, String message) {
  final text = AppTextScope.of(context);

  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.86,
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stockBottomSheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    text.t('Message'),
                    style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColours.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColours.border),
              ),
              child: SelectableText(
                message,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text.t('Review the message, then copy and paste it to supplier chat.'),
              style: const TextStyle(
                fontSize: AppTextSize.s16,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              text: text.t('Copy Message'),
              icon: Icons.content_copy_rounded,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                showSuccessSnackBar(context, text.t('Message copied to clipboard'));
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showCameraOnlyCaptureDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Future<void> Function(String filePath) onCaptured,
}) async {
  final filePath = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _StockCameraPage(
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
  if (filePath == null || filePath.trim().isEmpty || !context.mounted) return;
  await onCaptured(filePath);
}

class _StockReviewPage extends StatefulWidget {
  final EastAppApi api;
  final UserRole role;
  final VoidCallback onBack;
  final Future<void> Function(StockReceivingRecord record) onReviewReceiving;
  final Future<void> Function(StockSubmission submission) onReviewStockCount;
  final Future<void> Function(List<StockSubmission> submissions) onBulkReviewStockCounts;

  const _StockReviewPage({
    required this.api,
    required this.role,
    required this.onBack,
    required this.onReviewReceiving,
    required this.onReviewStockCount,
    required this.onBulkReviewStockCounts,
  });

  @override
  State<_StockReviewPage> createState() => _StockReviewPageState();
}

class _StockReviewPageState extends State<_StockReviewPage> {
  static const int _pageSize = 50;
  static const List<String> _statusOptions = [
    'Pending Review',
    'Approved',
    'Rejected',
  ];

  String? activeType;
  String statusFilter = 'Pending Review';
  late DateTime rangeStart;
  late DateTime rangeEnd;

  List<StockReceivingRecord> receivingRecords = const [];
  List<StockSubmission> countRecords = const [];
  bool receivingLoaded = false;
  bool countLoaded = false;
  bool loading = false;
  bool loadingMore = false;
  int loadedPage = -1;
  int totalElements = 0;
  bool lastPage = true;

  bool selecting = false;
  final Set<String> selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    rangeEnd = today;
    rangeStart = today.subtract(const Duration(days: 29));
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String get rangeLabel => '${_formatDate(rangeStart)} – ${_formatDate(rangeEnd)}';
  bool get isReceiving => activeType == 'receiving';
  bool get isCount => activeType == 'count';
  bool get hasLoaded => isReceiving ? receivingLoaded : countLoaded;
  bool get canReviewSelectedStatus => statusFilter == 'Pending Review';

  void openType(String type) {
    AppFeedback.select();
    setState(() {
      activeType = type;
      statusFilter = 'Pending Review';
      final today = _dateOnly(DateTime.now());
      rangeEnd = today;
      rangeStart = today.subtract(const Duration(days: 29));
      receivingRecords = const [];
      countRecords = const [];
      receivingLoaded = false;
      countLoaded = false;
      loadedPage = -1;
      totalElements = 0;
      lastPage = true;
      selecting = false;
      selectedIds.clear();
    });
  }

  void backToMenu() {
    AppFeedback.select();
    setState(() {
      activeType = null;
      selecting = false;
      selectedIds.clear();
    });
  }

  Future<void> selectDateRange() async {
    final text = AppTextScope.of(context);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: DateTimeRange(start: rangeStart, end: rangeEnd),
      helpText: text.t('Select Date Range'),
      saveText: text.t('Apply'),
      switchToInputEntryModeIcon: const Icon(Icons.edit_rounded),
      builder: (pickerContext, child) {
        final baseTheme = Theme.of(pickerContext);
        return Theme(
          data: baseTheme.copyWith(
            datePickerTheme: baseTheme.datePickerTheme.copyWith(
              rangePickerBackgroundColor: AppColours.background,
              rangePickerHeaderBackgroundColor: AppColours.card,
              rangePickerHeaderForegroundColor: AppColours.textMain,
              rangePickerHeaderHelpStyle: AppTextStyles.formLabel.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColours.textMain,
              ),
              rangePickerHeaderHeadlineStyle: const TextStyle(
                fontSize: AppTextSize.s22,
                fontWeight: FontWeight.w800,
                color: AppColours.textMain,
              ),
              confirmButtonStyle: FilledButton.styleFrom(
                backgroundColor: AppColours.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: AppColours.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColours.border,
                disabledForegroundColor: AppColours.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected == null || !mounted) return;

    final start = _dateOnly(selected.start);
    final end = _dateOnly(selected.end);
    if (end.difference(start).inDays + 1 > 30) {
      await AppFeedback.warning();
      if (!mounted) return;
      showWarningSnackBar(context, text.t('Maximum 30 days.'));
      return;
    }

    setState(() {
      rangeStart = start;
      rangeEnd = end;
      _clearLoadedResults();
    });
  }

  void _clearLoadedResults() {
    receivingRecords = const [];
    countRecords = const [];
    receivingLoaded = false;
    countLoaded = false;
    loadedPage = -1;
    totalElements = 0;
    lastPage = true;
    selecting = false;
    selectedIds.clear();
  }

  Future<void> loadRecords({bool reset = true}) async {
    if (activeType == null || loading || loadingMore || (!reset && lastPage)) return;
    setState(() {
      if (reset) {
        loading = true;
        selecting = false;
        selectedIds.clear();
      } else {
        loadingMore = true;
      }
    });

    try {
      final page = reset ? 0 : loadedPage + 1;
      if (isReceiving) {
        final result = await widget.api.stockReceivings(
          reviewStatus: statusFilter,
          from: rangeStart,
          to: rangeEnd,
          page: page,
          size: _pageSize,
        );
        if (!mounted) return;
        setState(() {
          receivingRecords = reset
              ? List<StockReceivingRecord>.from(result.content)
              : [...receivingRecords, ...result.content];
          receivingLoaded = true;
          loadedPage = result.page;
          totalElements = result.totalElements;
          lastPage = result.last;
        });
      } else {
        final result = await widget.api.stockCounts(
          mine: false,
          reviewStatus: statusFilter,
          from: rangeStart,
          to: rangeEnd,
          page: page,
          size: _pageSize,
        );
        if (!mounted) return;
        setState(() {
          countRecords = reset
              ? List<StockSubmission>.from(result.content)
              : [...countRecords, ...result.content];
          countLoaded = true;
          loadedPage = result.page;
          totalElements = result.totalElements;
          lastPage = result.last;
        });
      }
    } on EastAppApiException catch (_) {
      // Global API error UI already presents the failure.
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  StockSku skuForSubmission(StockSubmission submission) {
    return StockSku(
      id: submission.stockTaskId,
      name: submission.skuName.isEmpty ? submission.stockTaskId : submission.skuName,
      category: submission.skuCategory,
      unit: submission.skuUnit,
      minimumBalanceValue: submission.skuMinimumBalanceValue,
      maximumBalanceValue: submission.skuMaximumBalanceValue,
      currentBalanceValue: submission.currentBalanceValue,
      supplierIds: const [],
      photoPath: submission.skuPhotoPath,
      location: submission.skuLocation,
      lastUpdatedAt: submission.submittedAt,
      lastUpdatedBy: submission.submittedBy,
    );
  }

  Color reviewStatusColour(String status) {
    if (status == 'Approved') return AppColours.green;
    if (status == 'Rejected') return AppColours.red;
    return AppColours.blue;
  }

  Color receivingConditionColour(StockReceivingRecord record) {
    final condition = record.items.isEmpty ? '' : record.items.first.condition.toLowerCase();
    if (condition.contains('good') || condition.contains('pass') || condition.contains('ok')) {
      return AppColours.green;
    }
    if (condition.contains('bad') || condition.contains('reject') || condition.contains('damag')) {
      return AppColours.red;
    }
    return AppColours.orange;
  }

  String recordDateLabel(DateTime value) => _formatDate(_dateOnly(value));

  void toggleSelection(String id) {
    if (!canReviewSelectedStatus) return;
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void startSelection() {
    if (!canReviewSelectedStatus) return;
    AppFeedback.select();
    setState(() {
      selecting = true;
      selectedIds.clear();
    });
  }

  void cancelSelection() {
    AppFeedback.select();
    setState(() {
      selecting = false;
      selectedIds.clear();
    });
  }

  Future<void> reviewReceiving(StockReceivingRecord record, String status) async {
    final confirmed = await confirmDataChange(
      context,
      action: status == 'Approved' ? 'Approve Receiving Record?' : 'Reject Receiving Record?',
      details: 'This will update the review status of this receiving record.',
    );
    if (!confirmed || !mounted) return;
    final updated = record.copyWith(
      reviewStatus: status,
      reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
    );
    final saved = await runStockRequest(context, () => widget.onReviewReceiving(updated));
    if (!saved || !mounted) return;
    setState(() {
      receivingRecords = receivingRecords.where((item) => item.id != record.id).toList();
      totalElements = totalElements > 0 ? totalElements - 1 : 0;
      selectedIds.remove(record.id);
    });
    Navigator.of(context).pop();
    showSuccessSnackBar(context, status == 'Approved' ? 'Receiving record approved' : 'Receiving record rejected');
  }

  Future<void> reviewCount(StockSubmission submission, String status) async {
    final confirmed = await confirmDataChange(
      context,
      action: status == 'Approved' ? 'Approve Daily Count?' : 'Reject Daily Count?',
      details: 'This will update the review status of this daily stock count.',
    );
    if (!confirmed || !mounted) return;
    final updated = submission.copyWith(
      reviewStatus: status,
      reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
    );
    final saved = await runStockRequest(context, () => widget.onReviewStockCount(updated));
    if (!saved || !mounted) return;
    setState(() {
      countRecords = countRecords.where((item) => item.id != submission.id).toList();
      totalElements = totalElements > 0 ? totalElements - 1 : 0;
      selectedIds.remove(submission.id);
    });
    Navigator.of(context).pop();
    showSuccessSnackBar(context, status == 'Approved' ? 'Daily count approved' : 'Daily count rejected');
  }

  Future<void> bulkReview(String status) async {
    if (selectedIds.isEmpty || !canReviewSelectedStatus) return;
    final selectedCount = selectedIds.length;
    final confirmed = await confirmDataChange(
      context,
      action: status == 'Approved' ? 'Approve $selectedCount records?' : 'Reject $selectedCount records?',
      details: 'This will update all selected records.',
    );
    if (!confirmed || !mounted) return;

    if (isReceiving) {
      final selected = receivingRecords.where((item) => selectedIds.contains(item.id)).toList();
      final ok = await runStockRequest(context, () async {
        for (final record in selected) {
          await widget.onReviewReceiving(record.copyWith(
            reviewStatus: status,
            reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
          ));
        }
      });
      if (!ok || !mounted) return;
      setState(() {
        receivingRecords = receivingRecords.where((item) => !selectedIds.contains(item.id)).toList();
        totalElements = (totalElements - selected.length).clamp(0, totalElements).toInt();
      });
    } else {
      final selected = countRecords.where((item) => selectedIds.contains(item.id)).toList();
      final updated = selected.map((item) => item.copyWith(
        reviewStatus: status,
        reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
      )).toList();
      final ok = await runStockRequest(context, () => widget.onBulkReviewStockCounts(updated));
      if (!ok || !mounted) return;
      setState(() {
        countRecords = countRecords.where((item) => !selectedIds.contains(item.id)).toList();
        totalElements = (totalElements - selected.length).clamp(0, totalElements).toInt();
      });
    }

    setState(() {
      selecting = false;
      selectedIds.clear();
    });
    showSuccessSnackBar(context, status == 'Approved' ? 'Selected records approved' : 'Selected records rejected');
  }

  void showReceivingDetails(StockReceivingRecord record) {
    final conditionColour = receivingConditionColour(record);
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.92,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                stockBottomSheetHandle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Receiving Review', style: TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewInfoRows(rows: [
                        _ReviewInfoRow(label: 'Review Status', value: record.reviewStatus, valueColour: reviewStatusColour(record.reviewStatus)),
                        _ReviewInfoRow(label: 'Supplier', value: record.supplierName),
                        _ReviewInfoRow(label: 'Captured', value: recordDateLabel(record.capturedAt)),
                        _ReviewInfoRow(label: 'Received By', value: record.receivedBy),
                        for (final item in record.items)
                          _ReviewInfoRow(label: item.skuName, value: '${formatStockNumber(item.receivedQuantity)} ${item.unit} · ${item.condition}'),
                        if (record.reviewedBy.isNotEmpty) _ReviewInfoRow(label: 'Reviewed By', value: record.reviewedBy),
                        if (record.reviewedAt.isNotEmpty) _ReviewInfoRow(label: 'Reviewed At', value: record.reviewedAt),
                        if (record.reviewNote.isNotEmpty) _ReviewInfoRow(label: 'Review Note', value: record.reviewNote),
                      ]),
                      const SizedBox(height: 12),
                      _ReviewPhotoGrid(record: record, conditionColour: conditionColour),
                    ],
                  ),
                ),
                if (record.reviewStatus == 'Pending Review') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: PrimaryButton(text: 'Reject', outlined: true, icon: Icons.close_rounded, onPressed: () => reviewReceiving(record, 'Rejected'))),
                      const SizedBox(width: 10),
                      Expanded(child: PrimaryButton(text: 'Approve', icon: Icons.check_rounded, onPressed: () => reviewReceiving(record, 'Approved'))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void showCountDetails(StockSubmission submission) {
    final sku = skuForSubmission(submission);
    final increased = submission.increasedValue;
    final increasedText = '${increased >= 0 ? '+' : ''}${formatStockNumber(increased)} ${sku.unit}';
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.92,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                stockBottomSheetHandle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Daily Count Review', style: TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewInfoRows(rows: [
                        _ReviewInfoRow(label: 'Review Status', value: submission.reviewStatus, valueColour: reviewStatusColour(submission.reviewStatus)),
                        _ReviewInfoRow(label: 'SKU', value: sku.name),
                        _ReviewInfoRow(label: 'Current Balance', value: '${formatStockNumber(submission.currentBalanceValue)} ${sku.unit}'),
                        _ReviewInfoRow(label: 'Min', value: '${formatStockNumber(sku.minimumBalanceValue)} ${sku.unit}'),
                        _ReviewInfoRow(label: 'Max', value: '${formatStockNumber(sku.maximumBalanceValue)} ${sku.unit}'),
                        _ReviewInfoRow(label: 'Changed Value', value: increasedText, valueColour: increased >= 0 ? AppColours.green : AppColours.red),
                        _ReviewInfoRow(label: 'Previous Value', value: '${formatStockNumber(submission.previousBalanceValue)} ${sku.unit}'),
                        _ReviewInfoRow(label: 'Captured', value: recordDateLabel(submission.capturedAt)),
                        _ReviewInfoRow(label: 'Counted By', value: submission.submittedBy),
                        if ((submission.remarks['note'] ?? '').trim().isNotEmpty) _ReviewInfoRow(label: 'Remark', value: submission.remarks['note']!),
                        if (submission.reviewedBy.isNotEmpty) _ReviewInfoRow(label: 'Reviewed By', value: submission.reviewedBy),
                        if (submission.reviewedAt.isNotEmpty) _ReviewInfoRow(label: 'Reviewed At', value: submission.reviewedAt),
                        if (submission.reviewNote.isNotEmpty) _ReviewInfoRow(label: 'Review Note', value: submission.reviewNote),
                      ]),
                      const SizedBox(height: 12),
                      _CountReviewPhotoPreview(sku: sku, onTap: () {}),
                    ],
                  ),
                ),
                if (submission.reviewStatus == 'Pending Review') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: PrimaryButton(text: 'Reject', outlined: true, icon: Icons.close_rounded, onPressed: () => reviewCount(submission, 'Rejected'))),
                      const SizedBox(width: 10),
                      Expanded(child: PrimaryButton(text: 'Approve', icon: Icons.check_rounded, onPressed: () => reviewCount(submission, 'Approved'))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget statusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: statusFilter,
      isExpanded: true,
      decoration: _inputDecoration('Status').copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
      onChanged: (value) {
        if (value == null || value == statusFilter) return;
        setState(() {
          statusFilter = value;
          _clearLoadedResults();
        });
      },
    );
  }

  Widget selectionToolbar() {
    return WhiteCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${selectedIds.length} selected',
              style: const TextStyle(fontSize: AppTextSize.s14, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: cancelSelection, child: const Text('Cancel')),
          const SizedBox(width: 4),
          FilledButton.tonal(onPressed: selectedIds.isEmpty ? null : () => bulkReview('Rejected'), child: const Text('Reject')),
          const SizedBox(width: 6),
          FilledButton(onPressed: selectedIds.isEmpty ? null : () => bulkReview('Approved'), child: const Text('Approve')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    if (activeType == null) {
      return _PageScaffold(
        title: text.t('Review'),
        subtitle: text.t('Review daily counts and receiving records.'),
        onBack: widget.onBack,
        children: [
          _StockMenuGrid(
            children: [
              _StockMenuCard(
                title: text.t('Receiving Records'),
                subtitle: text.t('Review submitted receiving records'),
                icon: Icons.inventory_2_outlined,
                onTap: () => openType('receiving'),
              ),
              _StockMenuCard(
                title: text.t('Daily Count Records'),
                subtitle: text.t('Review submitted daily stock counts'),
                icon: Icons.fact_check_outlined,
                onTap: () => openType('count'),
              ),
            ],
          ),
        ],
      );
    }

    final recordsCount = isReceiving ? receivingRecords.length : countRecords.length;
    return _PageScaffold(
      title: text.t(isReceiving ? 'Receiving Records' : 'Daily Count Records'),
      subtitle: text.t('Select Status AND Date, then press Search.'),
      onBack: backToMenu,
      trailing: hasLoaded && canReviewSelectedStatus && recordsCount > 0 && !selecting
          ? TextButton.icon(
              onPressed: startSelection,
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('Select'),
            )
          : null,
      children: [
        statusDropdown(),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: selectDateRange,
            icon: const Icon(Icons.date_range_rounded, size: 20),
            label: Row(
              children: [
                Expanded(
                  child: Text(
                    rangeLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          text: loading ? 'Searching...' : hasLoaded ? 'Search Again' : 'Search',
          icon: loading ? null : Icons.search_rounded,
          onPressed: loading ? null : () => loadRecords(reset: true),
        ),
        const SizedBox(height: 14),
        if (!hasLoaded)
          WhiteCard(
            child: Text(
              'No records are loaded by default. Select Status and Date, then press Search.',
              style: const TextStyle(fontSize: AppTextSize.s15, color: AppColours.textMuted, fontWeight: FontWeight.w600),
            ),
          )
        else ...[
          if (selecting) ...[
            selectionToolbar(),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(child: _MiniMetric(label: 'Results', value: '$totalElements', icon: Icons.manage_search_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _MiniMetric(label: 'Loaded', value: '$recordsCount', icon: Icons.download_done_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          if (recordsCount == 0)
            WhiteCard(
              child: Text(
                isReceiving ? 'No receiving records found.' : 'No daily count records found.',
                style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700),
              ),
            )
          else
            WhiteCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: isReceiving
                    ? receivingRecords.map((record) {
                        final selected = selectedIds.contains(record.id);
                        return _ReceivingReviewRow(
                          record: record,
                          timerText: recordDateLabel(record.capturedAt),
                          statusText: record.reviewStatus,
                          statusColour: reviewStatusColour(record.reviewStatus),
                          conditionColour: receivingConditionColour(record),
                          selectMode: selecting,
                          selectable: canReviewSelectedStatus,
                          selected: selected,
                          onTap: () => showReceivingDetails(record),
                          onSelectToggle: () => toggleSelection(record.id),
                        );
                      }).toList()
                    : countRecords.map((submission) {
                        final sku = skuForSubmission(submission);
                        final selected = selectedIds.contains(submission.id);
                        return _DailyCountReviewRow(
                          submission: submission,
                          sku: sku,
                          timerText: recordDateLabel(submission.capturedAt),
                          statusText: submission.reviewStatus,
                          statusColour: reviewStatusColour(submission.reviewStatus),
                          selectMode: selecting,
                          selectable: canReviewSelectedStatus,
                          selected: selected,
                          onTap: () => showCountDetails(submission),
                          onSelectToggle: () => toggleSelection(submission.id),
                        );
                      }).toList(),
              ),
            ),
          if (!lastPage) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              text: loadingMore ? 'Loading...' : 'Load More',
              icon: loadingMore ? null : Icons.expand_more_rounded,
              onPressed: loadingMore ? null : () => loadRecords(reset: false),
            ),
          ],
        ],
      ],
    );
  }
}


class _ReviewEmptyMessage extends StatelessWidget {
  final String text;

  const _ReviewEmptyMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: AppTextSize.s15, color: AppColours.textMuted, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ReviewSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;

  const _ReviewSearchBar({
    required this.searchController,
    required this.searchHint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      decoration: _inputDecoration(searchHint).copyWith(
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: searchController.clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _ReviewFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final String filterLabel;
  final String filterValue;
  final List<String> filterOptions;
  final ValueChanged<String> onFilterChanged;

  const _ReviewFilterBar({
    required this.searchController,
    required this.searchHint,
    required this.filterLabel,
    required this.filterValue,
    required this.filterOptions,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = filterOptions.contains(filterValue) ? filterValue : 'All';

    return Column(
      children: [
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          decoration: _inputDecoration(searchHint).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: searchController.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: currentValue,
          isExpanded: true,
          decoration: _inputDecoration(filterLabel),
          items: filterOptions
              .map((value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            onFilterChanged(value);
          },
        ),
      ],
    );
  }
}

class _ReviewFolderRow extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _ReviewFolderRow({
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s16,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
            ),
            SmallStatusPill(
              text: '$count',
              textColour: AppColours.textMuted,
              backgroundColour: AppColours.background,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ReviewGroupHeader extends StatelessWidget {
  final String title;
  final int count;

  const _ReviewGroupHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
      color: AppColours.background,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSize.s13,
                fontWeight: FontWeight.w800,
                color: AppColours.textMain,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w800,
              color: AppColours.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}


class _SelectionCircle extends StatelessWidget {
  final bool selected;
  final bool enabled;

  const _SelectionCircle({
    required this.selected,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final colour = enabled
        ? selected
            ? AppColours.blue
            : AppColours.border
        : const Color(0xFFD6DCE6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected && enabled ? AppColours.blue : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: colour, width: 2),
      ),
      child: selected && enabled
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _BulkSummaryCell extends StatelessWidget {
  final String text;
  final bool header;

  const _BulkSummaryCell(this.text, {this.header = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTextSize.s10,
          color: header ? AppColours.textMain : AppColours.textMuted,
          fontWeight: header ? FontWeight.w800 : FontWeight.w700,
          height: 1.05,
        ),
      ),
    );
  }
}

class _ReceivingReviewRow extends StatelessWidget {
  final StockReceivingRecord record;
  final String timerText;
  final String statusText;
  final Color statusColour;
  final Color conditionColour;
  final bool selectMode;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;

  const _ReceivingReviewRow({
    required this.record,
    required this.timerText,
    required this.statusText,
    required this.statusColour,
    required this.conditionColour,
    required this.selectMode,
    required this.selectable,
    required this.selected,
    required this.onTap,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final item = record.items.isNotEmpty ? record.items.first : null;
    final condition = item?.condition ?? 'Unknown';
    final qty = item == null ? '-' : '${formatStockNumber(item.receivedQuantity)} ${item.unit}';

    final disabledInSelectMode = selectMode && !selectable;

    return Opacity(
      opacity: disabledInSelectMode ? 0.42 : 1,
      child: Pressable(
        onTap: selectMode ? (selectable ? onSelectToggle : null) : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (selectMode) ...[
                _SelectionCircle(selected: selected, enabled: selectable),
                const SizedBox(width: 8),
              ],
              _ReceivingGoodsThumb(
                record: record,
                size: 46,
                conditionColour: conditionColour,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item?.skuName ?? record.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTextSize.s16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: AppTextSize.s12,
                            color: statusColour,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qty · ${record.receivedBy} · $timerText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            condition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTextSize.s12,
                              color: conditionColour,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                disabledInSelectMode ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                color: AppColours.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyCountReviewRow extends StatelessWidget {
  final StockSubmission submission;
  final StockSku sku;
  final String timerText;
  final String statusText;
  final Color statusColour;
  final bool selectMode;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;

  const _DailyCountReviewRow({
    required this.submission,
    required this.sku,
    required this.timerText,
    required this.statusText,
    required this.statusColour,
    required this.selectMode,
    required this.selectable,
    required this.selected,
    required this.onTap,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final disabledInSelectMode = selectMode && !selectable;

    return Opacity(
      opacity: disabledInSelectMode ? 0.42 : 1,
      child: Pressable(
        onTap: selectMode ? (selectable ? onSelectToggle : null) : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (selectMode) ...[
                _SelectionCircle(selected: selected, enabled: selectable),
                const SizedBox(width: 8),
              ],
              _SkuPhotoThumb(sku: sku, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sku.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: AppTextSize.s12,
                            color: statusColour,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatStockNumber(submission.currentBalanceValue)} ${sku.unit} · ${submission.submittedBy} · $timerText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                disabledInSelectMode ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                color: AppColours.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ReceivingPhotoImage extends StatelessWidget {
  final String storageKey;
  final BoxFit fit;
  final Widget fallback;
  final double? width;
  final double? height;

  const _ReceivingPhotoImage({
    required this.storageKey,
    required this.fit,
    required this.fallback,
    this.width,
    this.height,
  });

  bool get hasStoredPhoto {
    final value = storageKey.trim().toLowerCase();
    return value.endsWith('.jpg') || value.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    if (!hasStoredPhoto) return fallback;
    final scope = _StockMediaScope.of(context);
    return FutureBuilder<Uint8List>(
      future: scope.loadReceivingPhoto(storageKey.trim()),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return fallback;
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }
}

class _ReceivingGoodsThumb extends StatelessWidget {
  final StockReceivingRecord record;
  final double size;
  final Color conditionColour;

  const _ReceivingGoodsThumb({
    required this.record,
    required this.size,
    required this.conditionColour,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: conditionColour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: conditionColour.withValues(alpha: 0.42)),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          color: conditionColour,
          size: size * 0.46,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: _ReceivingPhotoImage(
        storageKey: record.goodsPhotoName,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}

class _CountReviewPhotoPreview extends StatelessWidget {
  final StockSku sku;
  final VoidCallback onTap;

  const _CountReviewPhotoPreview({
    required this.sku,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _SkuPhotoThumb(sku: sku, size: 118),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            text.t('SKU Photo'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSize.s12,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPhotoGrid extends StatelessWidget {
  final StockReceivingRecord record;
  final Color conditionColour;

  const _ReviewPhotoGrid({
    required this.record,
    required this.conditionColour,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return Row(
      children: [
        Expanded(
          child: _ReviewPhotoPreview(
            label: text.t('Goods Received'),
            record: record,
            conditionColour: conditionColour,
            isInvoice: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReviewPhotoPreview(
            label: text.t('Invoice'),
            record: record,
            conditionColour: AppColours.blue,
            isInvoice: true,
          ),
        ),
      ],
    );
  }
}

class _ReviewPhotoPreview extends StatelessWidget {
  final String label;
  final StockReceivingRecord record;
  final Color conditionColour;
  final bool isInvoice;

  const _ReviewPhotoPreview({
    required this.label,
    required this.record,
    required this.conditionColour,
    required this.isInvoice,
  });

  String get storageKey =>
      isInvoice ? record.invoicePhotoName : record.goodsPhotoName;

  Widget fallback({double? height}) {
    return Container(
      height: height,
      color: conditionColour.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Icon(
        isInvoice ? Icons.receipt_long_outlined : Icons.photo_camera_outlined,
        color: conditionColour,
        size: 34,
      ),
    );
  }

  void showZoom(BuildContext context) {
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.92,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stockBottomSheetHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: AppTextSize.s22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: _ReceivingPhotoImage(
                      storageKey: storageKey,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      fallback: fallback(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewFallback = Container(
      height: 118,
      decoration: BoxDecoration(
        color: conditionColour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: conditionColour.withValues(alpha: 0.34)),
      ),
      child: Icon(
        isInvoice ? Icons.receipt_long_outlined : Icons.photo_camera_outlined,
        color: conditionColour,
        size: 34,
      ),
    );

    return Pressable(
      onTap: () => showZoom(context),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _ReceivingPhotoImage(
                  storageKey: storageKey,
                  height: 118,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fallback: previewFallback,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSize.s12,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewInfoRows extends StatelessWidget {
  final List<_ReviewInfoRow> rows;

  const _ReviewInfoRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      fontSize: AppTextSize.s13,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: TextStyle(
                      fontSize: AppTextSize.s13,
                      color: row.valueColour ?? AppColours.textMain,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewInfoRow {
  final String label;
  final String value;
  final Color? valueColour;

  const _ReviewInfoRow({
    required this.label,
    required this.value,
    this.valueColour,
  });
}

class _SkuSetupPage extends StatefulWidget {
  final EastAppApi api;
  final bool isOwner;
  final String currentTenantId;
  final String currentTenantName;
  final Future<void> Function() onReloadAfterSkuCopy;
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final List<StockSku> skus;
  final VoidCallback onBack;
  final Future<void> Function(StockSku sku) onCreateSku;
  final Future<void> Function(StockSku sku) onUpdateSku;
  final Future<void> Function(String skuId, double balance, String updatedBy) onUpdateSkuBalance;
  const _SkuSetupPage({
    required this.api,
    required this.isOwner,
    required this.currentTenantId,
    required this.currentTenantName,
    required this.onReloadAfterSkuCopy,
    required this.tags,
    required this.suppliers,
    required this.skus,
    required this.onBack,
    required this.onCreateSku,
    required this.onUpdateSku,
    required this.onUpdateSkuBalance,
  });

  @override
  State<_SkuSetupPage> createState() => _SkuSetupPageState();
}

class _SkuSetupPageState extends State<_SkuSetupPage> {
  final searchController = TextEditingController();
  String warningFilter = 'All';
  String tag1Filter = 'All';
  String tag2Filter = 'All';
  String assignedFilter = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<String> get tag1Options {
    final values = widget.skus.map((sku) => sku.category).where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<String> get tag2Options {
    final values = widget.skus.map((sku) => sku.location).where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<String> get assignedStaff {
    final values = widget.skus.expand((sku) => sku.assignedStaffNames).where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', 'Unassigned', ...values];
  }

  List<StockSku> get filteredSkus {
    final query = searchController.text.trim().toLowerCase();
    return widget.skus.where((sku) {
      final matchesSearch = query.isEmpty ||
          sku.name.toLowerCase().contains(query) ||
          sku.category.toLowerCase().contains(query) ||
          sku.location.toLowerCase().contains(query) ||
          sku.assignedStaffName.toLowerCase().contains(query);
      final matchesWarning = warningFilter == 'All' ||
          (warningFilter == 'Low' && sku.isBelowMinimumBalance) ||
          (warningFilter == 'Normal' && !sku.isBelowMinimumBalance);
      final matchesTag1 = tag1Filter == 'All' || sku.category == tag1Filter;
      final matchesTag2 = tag2Filter == 'All' || sku.location == tag2Filter;
      final matchesAssigned = assignedFilter == 'All' ||
          (assignedFilter == 'Unassigned' && sku.assignedStaffNames.isEmpty) ||
          sku.assignedStaffNames.contains(assignedFilter);
      return matchesSearch && matchesWarning && matchesTag1 && matchesTag2 && matchesAssigned;
    }).toList();
  }

  Widget filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppTextSize.s13,
              fontWeight: FontWeight.w500,
              color: AppColours.textMuted,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          isDense: true,
          style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13),
          selectedItemBuilder: (context) => options.map((option) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13),
              ),
            );
          }).toList(),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13, fontWeight: FontWeight.w500),
                  ),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            if (newValue == null) return;
            onChanged(newValue);
          },
          decoration: _inputDecoration('').copyWith(
            isDense: true,
            hintText: null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          ),
        ),
      ],
    );
  }

  Future<void> openCopySkuSheet() async {
    AppFeedback.tap();
    final result = await showStockBottomSheet<StockSkuCopyResult>(
      context,
      maxHeightFactor: 0.94,
      builder: (_) => _CopySkuSheet(
        api: widget.api,
        targetTenantId: widget.currentTenantId,
        targetTenantName: widget.currentTenantName,
      ),
    );
    if (result == null || !mounted) return;
    await widget.onReloadAfterSkuCopy();
    if (!mounted) return;
    showSuccessSnackBar(
      context,
      '${result.skusCopied} SKU, ${result.tagsCopied} tags and '
      '${result.suppliersCopied} suppliers copied.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final skus = filteredSkus;
    final lowCount = widget.skus.where((sku) => sku.isBelowMinimumBalance).length;

    return _PageScaffold(
      title: text.t('SKU'),
      subtitle: text.t('Search, filter and edit SKU.'),
      onBack: widget.onBack,
      trailing: SizedBox(
        width: 150,
        child: PrimaryButton(
          text: text.t('Add SKU'),
          icon: Icons.add_rounded,
          onPressed: () => showAddSkuDialog(
            context,
            tags: widget.tags,
            suppliers: widget.suppliers,
            onCreateSku: widget.onCreateSku,
          ),
        ),
      ),
      children: [
        if (widget.isOwner) ...[
          WhiteCard(
            child: Row(
              children: [
                const Icon(Icons.copy_all_rounded, color: AppColours.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copy from another business',
                        style: TextStyle(
                          fontSize: AppTextSize.s16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Copy selected SKUs with their tags and suppliers.',
                        style: TextStyle(
                          color: AppColours.textMuted,
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: openCopySkuSheet,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: _MiniMetric(label: text.t('Total SKU'), value: '${widget.skus.length}', icon: Icons.inventory_2_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _MiniMetric(label: text.t('Low'), value: '$lowCount', icon: Icons.warning_amber_rounded, danger: lowCount > 0)),
            const SizedBox(width: 10),
            Expanded(child: _MiniMetric(label: text.t('Showing'), value: '${skus.length}', icon: Icons.filter_alt_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(text.t('Search')).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final filterWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: filterWidth, child: filterDropdown(label: text.t('Status'), value: warningFilter, options: const ['All', 'Low', 'Normal'], onChanged: (value) => setState(() => warningFilter = value))),
                SizedBox(width: filterWidth, child: filterDropdown(label: text.t('Tag 1'), value: tag1Options.contains(tag1Filter) ? tag1Filter : 'All', options: tag1Options, onChanged: (value) => setState(() => tag1Filter = value))),
                SizedBox(width: filterWidth, child: filterDropdown(label: text.t('Assigned'), value: assignedStaff.contains(assignedFilter) ? assignedFilter : 'All', options: assignedStaff, onChanged: (value) => setState(() => assignedFilter = value))),
                SizedBox(width: filterWidth, child: filterDropdown(label: text.t('Tag 2'), value: tag2Options.contains(tag2Filter) ? tag2Filter : 'All', options: tag2Options, onChanged: (value) => setState(() => tag2Filter = value))),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (skus.isEmpty)
          WhiteCard(child: Text(text.t('No SKU matches the selected filters.'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)))
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...skus.map((sku) {
                  return _SkuCompactRow(
                    sku: sku,
                    onTap: () => showSkuDetailDialog(
                      context,
                      sku: sku,
                      tags: widget.tags,
                      suppliers: widget.suppliers,
                      onUpdateSku: widget.onUpdateSku,
                      onUpdateSkuBalance: widget.onUpdateSkuBalance,
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}



class _CopySkuSheet extends StatefulWidget {
  final EastAppApi api;
  final String targetTenantId;
  final String targetTenantName;

  const _CopySkuSheet({
    required this.api,
    required this.targetTenantId,
    required this.targetTenantName,
  });

  @override
  State<_CopySkuSheet> createState() => _CopySkuSheetState();
}

class _CopySkuSheetState extends State<_CopySkuSheet> {
  final searchController = TextEditingController();
  List<EastAppTenant> sourceTenants = const [];
  List<StockSku> sourceSkus = const [];
  final Set<String> selectedSkuIds = <String>{};
  String? sourceTenantId;
  bool loading = true;
  bool copying = false;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(loadTenants());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  EastAppTenant? get sourceTenant {
    for (final tenant in sourceTenants) {
      if (tenant.id == sourceTenantId) return tenant;
    }
    return null;
  }

  List<StockSku> get filteredSkus {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return sourceSkus;
    return sourceSkus.where((sku) {
      return sku.name.toLowerCase().contains(query) ||
          sku.category.toLowerCase().contains(query) ||
          sku.location.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> loadTenants() async {
    try {
      final tenants = (await widget.api.availableContexts())
          .map((context) => context.tenant)
          .where(
            (tenant) => tenant.active && tenant.id != widget.targetTenantId,
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        sourceTenants = tenants;
        sourceTenantId = tenants.isEmpty ? null : tenants.first.id;
        loading = tenants.isNotEmpty;
        error = tenants.isEmpty
            ? 'No other business is available.'
            : null;
      });
      if (tenants.isNotEmpty) await loadSkus(tenants.first.id);
    } on EastAppApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = apiError.message;
      });
    }
  }

  Future<void> loadSkus(String tenantId) async {
    setState(() {
      loading = true;
      error = null;
      sourceSkus = const [];
      selectedSkuIds.clear();
    });
    try {
      final result = await widget.api.stockCopySourceSkus(
        tenantId: tenantId,
        active: true,
        size: 100,
      );
      if (!mounted || sourceTenantId != tenantId) return;
      setState(() {
        sourceSkus = result.content;
        loading = false;
      });
    } on EastAppApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = apiError.message;
      });
    }
  }

  Future<void> proceed() async {
    final source = sourceTenant;
    if (source == null || selectedSkuIds.isEmpty || copying) {
      AppFeedback.warning();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Copy SKUs to ${widget.targetTenantName}?'),
          content: Text(
            'The selected SKUs, tags and suppliers will be duplicated from '
            '${source.businessName} into ${widget.targetTenantName}.\n\n'
            'This may create duplicate tags, suppliers or SKU records. '
            'Copied records are independent and future changes will not stay '
            'synchronised.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => copying = true);
    try {
      final result = await widget.api.copyStockSkus(
        sourceTenantId: source.id,
        skuIds: selectedSkuIds.toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on EastAppApiException {
      if (!mounted) return;
      setState(() => copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSkus = filteredSkus;
    final allVisibleSelected = visibleSkus.isNotEmpty &&
        visibleSkus.every((sku) => selectedSkuIds.contains(sku.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          stockBottomSheetHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Copy SKUs from Business',
                  style: TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: copying ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: sourceTenantId,
            isExpanded: true,
            decoration: _inputDecoration('Source business'),
            items: sourceTenants
                .map(
                  (tenant) => DropdownMenuItem<String>(
                    value: tenant.id,
                    child: Text(tenant.businessName),
                  ),
                )
                .toList(growable: false),
            onChanged: copying || sourceTenants.isEmpty
                ? null
                : (value) {
                    if (value == null || value == sourceTenantId) return;
                    AppFeedback.select();
                    setState(() => sourceTenantId = value);
                    unawaited(loadSkus(value));
                  },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            enabled: !copying,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('Search source SKU').copyWith(
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${selectedSkuIds.length} selected',
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: loading || copying || visibleSkus.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (allVisibleSelected) {
                            selectedSkuIds.removeAll(
                              visibleSkus.map((sku) => sku.id),
                            );
                          } else {
                            selectedSkuIds.addAll(
                              visibleSkus.map((sku) => sku.id),
                            );
                          }
                        });
                      },
                child: Text(allVisibleSelected ? 'Clear visible' : 'Select visible'),
              ),
            ],
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : visibleSkus.isEmpty
                        ? const Center(
                            child: Text(
                              'No SKU found.',
                              style: TextStyle(
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: visibleSkus.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final sku = visibleSkus[index];
                              final selected = selectedSkuIds.contains(sku.id);
                              return CheckboxListTile(
                                value: selected,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  sku.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text('${sku.category} · ${sku.unit}'),
                                onChanged: copying
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value == true) {
                                            selectedSkuIds.add(sku.id);
                                          } else {
                                            selectedSkuIds.remove(sku.id);
                                          }
                                        });
                                      },
                              );
                            },
                          ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: copying ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: selectedSkuIds.isEmpty || copying ? null : proceed,
                  child: Text(copying ? 'Copying…' : 'Proceed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String formatCountTimer(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${days}d ${hours}h ${minutes}m ${seconds}s';
}

class _SkuCompactRow extends StatelessWidget {
  final StockSku sku;
  final VoidCallback onTap;

  const _SkuCompactRow({
    required this.sku,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final isLow = sku.isBelowMinimumBalance;
    final statusText = isLow ? text.t('Low') : text.t('Good');
    final statusColour = isLow ? AppColours.red : AppColours.green;
    final statusBackground = isLow ? AppColours.redSoft : AppColours.greenSoft;
    final balanceColour = isLow ? AppColours.red : AppColours.green;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColours.border)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => showSkuPhotoViewer(context, sku: sku),
              child: _SkuPhotoThumb(sku: sku, size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sku.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sku.category} · ${sku.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sku.assignedStaffName} · ${text.t('Reset')} ${sku.resetTime}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTextSize.s13,
                      fontWeight: FontWeight.w700,
                      color: AppColours.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SmallStatusPill(
                  text: statusText,
                  textColour: statusColour,
                  backgroundColour: statusBackground,
                ),
                const SizedBox(height: 8),
                _SkuTripleValue(sku: sku, balanceColour: balanceColour, fontSize: AppTextSize.s15),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SkuTripleValue extends StatelessWidget {
  final StockSku sku;
  final Color balanceColour;
  final double fontSize;

  const _SkuTripleValue({
    required this.sku,
    required this.balanceColour,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final unit = sku.unit;
    final min = formatStockNumber(sku.minimumBalanceValue);
    final current = formatStockNumber(sku.currentBalanceValue);
    final max = formatStockNumber(sku.maximumBalanceValue);
    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, color: AppColours.textMain, fontWeight: FontWeight.w700),
        children: [
          TextSpan(text: '$min / '),
          TextSpan(text: current, style: TextStyle(color: balanceColour)),
          TextSpan(text: ' / $max $unit'),
        ],
      ),
    );
  }
}

void showSkuDetailDialog(
  BuildContext context, {
  required StockSku sku,
  required List<StockTag> tags,
  required List<SupplierProfile> suppliers,
  required Future<void> Function(StockSku sku) onUpdateSku,
  required Future<void> Function(String skuId, double balance, String updatedBy) onUpdateSkuBalance,
}) {
  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.94,
    builder: (sheetContext) {
      return _SkuDetailContent(
        sku: sku,
        tags: tags,
        suppliers: suppliers,
        onUpdateSku: onUpdateSku,
        onUpdateSkuBalance: onUpdateSkuBalance,
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class _SkuDetailContent extends StatefulWidget {
  final StockSku sku;
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final Future<void> Function(StockSku sku) onUpdateSku;
  final Future<void> Function(String skuId, double balance, String updatedBy) onUpdateSkuBalance;
  final VoidCallback onClose;

  const _SkuDetailContent({
    required this.sku,
    required this.tags,
    required this.suppliers,
    required this.onUpdateSku,
    required this.onUpdateSkuBalance,
    required this.onClose,
  });

  @override
  State<_SkuDetailContent> createState() => _SkuDetailContentState();
}

class _SkuDetailContentState extends State<_SkuDetailContent> {
  late StockSku localSku;
  late double currentBalance;
  late final TextEditingController nameController;
  late final TextEditingController categoryController;
  late final TextEditingController locationController;
  late final TextEditingController unitController;
  late final List<TextEditingController> receivingChecklistControllers;
  late final TextEditingController resetTimeController;
  late final TextEditingController recoveryController;
  late final TextEditingController minPriceController;
  late final TextEditingController maxPriceController;
  late final TextEditingController minBalanceController;
  late final TextEditingController balanceController;
  late final TextEditingController maxBalanceController;
  late List<String> selectedSupplierIds;
  bool editing = false;
  bool showErrors = false;
  String? pendingPhotoFilePath;
  Uint8List? pendingPhotoBytes;
  final ImagePicker imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    localSku = widget.sku;
    currentBalance = widget.sku.currentBalanceValue;
    nameController = TextEditingController(text: localSku.name);
    categoryController = TextEditingController(text: localSku.category);
    locationController = TextEditingController(text: localSku.location);
    unitController = TextEditingController(text: localSku.unit);
    receivingChecklistControllers = List<TextEditingController>.generate(5, (index) {
      final value = index < localSku.receivingChecklist.length ? localSku.receivingChecklist[index] : '';
      return TextEditingController(text: value);
    });
    resetTimeController = TextEditingController(text: localSku.resetTime);
    recoveryController = TextEditingController(text: localSku.recoveryPercent.toString());
    minPriceController = TextEditingController(text: formatStockNumber(localSku.minimumPriceRm));
    maxPriceController = TextEditingController(text: formatStockNumber(localSku.maximumPriceRm));
    minBalanceController = TextEditingController(text: formatStockNumber(localSku.minimumBalanceValue));
    balanceController = TextEditingController(text: formatStockNumber(currentBalance));
    maxBalanceController = TextEditingController(text: formatStockNumber(localSku.maximumBalanceValue));
    selectedSupplierIds = [...localSku.supplierIds];
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    locationController.dispose();
    unitController.dispose();
    for (final controller in receivingChecklistControllers) {
      controller.dispose();
    }
    resetTimeController.dispose();
    recoveryController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    minBalanceController.dispose();
    balanceController.dispose();
    maxBalanceController.dispose();
    super.dispose();
  }

  double readDouble(TextEditingController controller, double fallback) {
    return double.tryParse(controller.text.trim()) ?? fallback;
  }

  int readInt(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  StockSku get displaySku => localSku.copyWith(currentBalanceValue: currentBalance);

  void refreshEditValidation() {
    if (showErrors) setState(() {});
  }

  String? requiredTextError(String label, TextEditingController controller) {
    return editing && showErrors && controller.text.trim().isEmpty ? AppTextScope.of(context).t('$label required') : null;
  }

  String? requiredNumberError(String label, TextEditingController controller) {
    final raw = controller.text.trim();
    return editing && showErrors && (raw.isEmpty || double.tryParse(raw) == null) ? AppTextScope.of(context).t('$label required') : null;
  }

  String? requiredResetTimeError() {
    return editing && showErrors && !isValidStockResetTime(resetTimeController.text.trim()) ? AppTextScope.of(context).t('Reset Time required') : null;
  }

  String? get supplierError => editing && showErrors && selectedSupplierIds.isEmpty ? AppTextScope.of(context).t('Supplier required') : null;

  void resetEditFields() {
    setState(() {
      currentBalance = localSku.currentBalanceValue;
      nameController.text = localSku.name;
      categoryController.text = localSku.category;
      locationController.text = localSku.location;
      unitController.text = localSku.unit;
      for (var index = 0; index < receivingChecklistControllers.length; index++) {
        receivingChecklistControllers[index].text = index < localSku.receivingChecklist.length ? localSku.receivingChecklist[index] : '';
      }
      resetTimeController.text = localSku.resetTime;
      recoveryController.text = localSku.recoveryPercent.toString();
      minPriceController.text = formatStockNumber(localSku.minimumPriceRm);
      maxPriceController.text = formatStockNumber(localSku.maximumPriceRm);
      minBalanceController.text = formatStockNumber(localSku.minimumBalanceValue);
      balanceController.text = formatStockNumber(localSku.currentBalanceValue);
      maxBalanceController.text = formatStockNumber(localSku.maximumBalanceValue);
      selectedSupplierIds = [...localSku.supplierIds];
      pendingPhotoFilePath = null;
      pendingPhotoBytes = null;
      showErrors = false;
      editing = false;
    });
  }

  List<String> get linkedSupplierNames {
    return widget.suppliers
        .where((supplier) => selectedSupplierIds.contains(supplier.id))
        .map((supplier) => supplier.supplierName)
        .toList();
  }

  void syncBalance(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return;
    final max = readDouble(maxBalanceController, localSku.maximumBalanceValue);
    setState(() => currentBalance = parsed.clamp(0, max <= 0 ? 1 : max).toDouble());
  }

  Future<void> pickResetTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: parseStockResetTime(resetTimeController.text),
    );
    if (picked == null) return;
    setState(() => resetTimeController.text = formatStockResetTime(picked));
    refreshEditValidation();
  }

  Future<void> pickSuppliers() async {
    final result = await showStockBottomSheet<List<String>>(
      context,
      maxHeightFactor: 0.72,
      builder: (sheetContext) {
        final temp = selectedSupplierIds.toSet();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Column(
                    children: [
                      stockBottomSheetHandle(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppTextScope.of(context).t('Suppliers'),
                              style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: widget.suppliers.map((supplier) {
                      final selected = temp.contains(supplier.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(supplier.supplierName),
                        onChanged: (value) {
                          setSheetState(() {
                            if (value == true) {
                              temp.add(supplier.id);
                            } else {
                              temp.remove(supplier.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: AppTextScope.of(context).t('Cancel'),
                          outlined: true,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          text: AppTextScope.of(context).t('Save'),
                          icon: Icons.save_outlined,
                          onPressed: () => Navigator.of(sheetContext).pop(temp.toList()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    setState(() => selectedSupplierIds = result);
  }

  Future<void> selectSkuPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        await showCameraOnlyCaptureDialog(
          context,
          title: AppTextScope.of(context).t('SKU Photo'),
          subtitle: AppTextScope.of(context).t('Take a clear photo of this SKU.'),
          onCaptured: (filePath) async {
            final bytes = await File(filePath).readAsBytes();
            if (!mounted) return;
            setState(() {
              pendingPhotoFilePath = filePath;
              pendingPhotoBytes = bytes;
            });
          },
        );
        return;
      }

      final selected = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      setState(() {
        pendingPhotoFilePath = selected.path;
        pendingPhotoBytes = bytes;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      showWarningSnackBar(context, 'Unable to access photo source: ${error.message ?? error.code}');
    } on FileSystemException catch (error) {
      if (!mounted) return;
      showWarningSnackBar(context, 'Unable to read the selected photo: ${error.message}');
    }
  }

  Future<void> showSkuPhotoSourcePicker() async {
    final source = await showStockBottomSheet<ImageSource>(
      context,
      maxHeightFactor: 0.42,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stockBottomSheetHandle(),
            const SizedBox(height: 14),
            const Text(
              'Replace SKU Photo',
              style: TextStyle(fontSize: AppTextSize.s22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await selectSkuPhoto(source);
  }

  Future<void> saveSku() async {
    final text = AppTextScope.of(context);
    setState(() => showErrors = true);
    final name = nameController.text.trim();
    final category = categoryController.text.trim();
    final location = locationController.text.trim();
    final unit = unitController.text.trim();
    final resetTime = resetTimeController.text.trim();
    final recovery = int.tryParse(recoveryController.text.trim());
    final minPrice = double.tryParse(minPriceController.text.trim());
    final maxPrice = double.tryParse(maxPriceController.text.trim());
    final minBalance = double.tryParse(minBalanceController.text.trim());
    final nextBalance = double.tryParse(balanceController.text.trim());
    final maxBalance = double.tryParse(maxBalanceController.text.trim());

    if (name.isEmpty ||
        category.isEmpty ||
        location.isEmpty ||
        unit.isEmpty ||
        !isValidStockResetTime(resetTime) ||
        recovery == null ||
        minPrice == null ||
        maxPrice == null ||
        minBalance == null ||
        nextBalance == null ||
        maxBalance == null ||
        selectedSupplierIds.isEmpty) {
      AppFeedback.warning();
      return;
    }

    if (recovery < 1 || recovery > 100 || maxBalance <= 0 || minBalance < 0 || nextBalance < 0) {
      showWarningSnackBar(context, text.t('Please enter valid numbers.'));
      return;
    }

    if (maxBalance < minBalance) {
      showWarningSnackBar(context, text.t('Balance must be Min / Max.'));
      return;
    }

    if (minPrice < 0 || maxPrice < minPrice) {
      showWarningSnackBar(context, text.t('Price must be Min / Max.'));
      return;
    }

    final tag1 = widget.tags.firstWhere((tag) => tag.tag == category);
    final tag2 = widget.tags.firstWhere((tag) => tag.tag == location);
    var updated = localSku.copyWith(
      name: name,
      tag1Id: tag1.id,
      category: tag1.tag,
      tag2Id: tag2.id,
      location: tag2.tag,
      unit: unit,
      receivingChecklist: receivingChecklistControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .take(5)
          .toList(),
      resetTime: resetTime,
      recoveryPercent: recovery.clamp(1, 100).toInt(),
      minimumPriceRm: minPrice,
      maximumPriceRm: maxPrice,
      minimumBalanceValue: minBalance,
      currentBalanceValue: nextBalance,
      maximumBalanceValue: maxBalance,
      supplierIds: selectedSupplierIds,
    );
    final confirmed = await confirmDataChange(
      context,
      action: 'Update SKU?',
      details: 'This will save the edited SKU details and stock settings.',
    );
    if (!confirmed || !mounted) return;

    final saved = await runStockRequest(
      context,
      () async {
        final pendingPath = pendingPhotoFilePath;
        if (pendingPath != null && pendingPath.trim().isNotEmpty) {
          final storageKey = await _StockMediaScope.of(context)
              .api
              .uploadStockSkuThumbnail(pendingPath);
          updated = updated.copyWith(photoPath: storageKey);
        }
        await widget.onUpdateSku(updated);
      },
    );
    if (!saved || !mounted) return;
    setState(() {
      localSku = updated;
      currentBalance = nextBalance;
      balanceController.text = formatStockNumber(nextBalance);
      pendingPhotoFilePath = null;
      pendingPhotoBytes = null;
      showErrors = false;
      editing = false;
    });
    showSuccessSnackBar(context, text.t('Saved'));
  }


  Widget detailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.formLabel)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.formValue,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration inlineEditDecoration({String? suffix}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: editing ? AppColours.blueSoft.withValues(alpha: 0.55) : Colors.transparent,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColours.blue, width: 1.2)),
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  BoxDecoration editableBoxDecoration() {
    return BoxDecoration(
      color: AppColours.blueSoft.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColours.blue.withValues(alpha: 0.18)),
    );
  }

  Widget editTextRow(
    String label,
    TextEditingController controller, {
    String? suffix,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.formLabel)),
          const SizedBox(width: 14),
          Expanded(
            child: editing
                ? TextField(
                    controller: controller,
                    textAlign: TextAlign.right,
                    keyboardType: keyboardType,
                    onChanged: (value) {
                      onChanged?.call(value);
                      refreshEditValidation();
                    },
                    style: AppTextStyles.formValue,
                    decoration: inlineEditDecoration(suffix: suffix).copyWith(errorText: errorText),
                  )
                : Text(
                    suffix == null ? controller.text : '${controller.text} $suffix',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.formValue,
                  ),
          ),
        ],
      ),
    );
  }

  Widget tagEditRow(String label, TextEditingController controller) {
    final options = widget.tags
        .map((tag) => tag.tag.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final current = controller.text.trim();
    final errorText = requiredTextError(label, controller);
    if (!editing) {
      return detailRow(label, current.isEmpty ? '-' : current);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColours.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.formLabel)),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: options.contains(current) ? current : null,
              isExpanded: true,
              items: options
                  .map((tag) => DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(growable: false),
              onChanged: options.isEmpty
                  ? null
                  : (value) {
                      setState(() => controller.text = value ?? '');
                      refreshEditValidation();
                    },
              decoration: inlineEditDecoration().copyWith(
                hintText: options.isEmpty ? 'Create tag first' : 'Select Tag',
                errorText: errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget resetTimeRow(String label) {
    if (!editing) return detailRow(label, resetTimeController.text);
    final errorText = requiredResetTimeError();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.formLabel)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: pickResetTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: editableBoxDecoration(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(resetTimeController.text, style: AppTextStyles.formValue),
                        const SizedBox(width: 6),
                        const Icon(Icons.schedule_rounded, size: 18, color: AppColours.textMuted),
                      ],
                    ),
                  ),
                ),
                if (errorText != null) _InlineError(errorText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget tagRow(String label) {
    final current = locationController.text.trim();
    return detailRow(label, current.isEmpty ? '-' : current);
  }

  Widget receivingChecklistRow(String label) {
    final values = receivingChecklistControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .take(5)
        .toList();

    if (!editing) {
      return detailRow(label, values.isEmpty ? '-' : values.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n'));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.formLabel),
          const SizedBox(height: 8),
          ...List.generate(5, (index) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: TextField(
                controller: receivingChecklistControllers[index],
                style: AppTextStyles.formValue,
                decoration: inlineEditDecoration().copyWith(hintText: 'Checklist ${index + 1}'),
              ),
            );
          }),
        ],
      ),
    );
  }


  Widget suppliersRow(String label) {
    final value = linkedSupplierNames.isEmpty ? 'None' : linkedSupplierNames.join(', ');
    final errorText = supplierError;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.formLabel)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: editing ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8) : EdgeInsets.zero,
                  decoration: editing
                      ? editableBoxDecoration().copyWith(
                          border: Border.all(color: errorText == null ? AppColours.blue.withValues(alpha: 0.18) : AppColours.red),
                        )
                      : null,
                  child: InkWell(
                    onTap: editing ? pickSuppliers : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            style: AppTextStyles.formValue.copyWith(color: errorText == null ? AppColours.textMain : AppColours.red),
                          ),
                        ),
                        if (editing) const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                if (errorText != null) _InlineError(errorText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final sku = displaySku;
    final isLow = currentBalance < sku.minimumBalanceValue;
    final statusText = isLow ? text.t('Low') : text.t('Good');
    final statusColour = isLow ? AppColours.red : AppColours.green;
    final statusBackground = isLow ? AppColours.redSoft : AppColours.greenSoft;
    final balanceColour = isLow ? AppColours.red : AppColours.green;
    final minPriceError = requiredNumberError(text.t('Min Price'), minPriceController);
    final maxPriceError = requiredNumberError(text.t('Max Price'), maxPriceController);
    final minBalanceError = requiredNumberError(text.t('Min Balance'), minBalanceController);
    final currentBalanceError = requiredNumberError(text.t('Current Balance'), balanceController);
    final maxBalanceError = requiredNumberError(text.t('Max Balance'), maxBalanceController);
    final priceLabel = '${text.t("Price")} (RM)';
    final balanceLabel = '${text.t("Balance")} (${sku.unit})';

    return Padding(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stockBottomSheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(sku.name, style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700))),
                IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        InkWell(
                          onTap: () => showSkuPhotoViewer(
                            context,
                            sku: sku,
                            overrideBytes: pendingPhotoBytes,
                          ),
                          borderRadius: BorderRadius.circular(34),
                          child: _SkuPhotoThumb(
                            sku: sku,
                            size: 118,
                            overrideBytes: pendingPhotoBytes,
                          ),
                        ),
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 19),
                          ),
                        ),
                      ],
                    ),
                    if (editing) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: showSkuPhotoSourcePicker,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                        label: const Text('Replace Photo'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: SmallStatusPill(text: statusText, textColour: statusColour, backgroundColour: statusBackground),
                      ),
                      const SizedBox(height: 18),
                      _SkuTripleValue(sku: sku, balanceColour: balanceColour, fontSize: AppTextSize.s22),
                      const SizedBox(height: 8),
                      Text(text.t('Current Stock'), style: const TextStyle(fontSize: AppTextSize.s14, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SkuBalanceSummary(sku: sku, currentBalance: currentBalance),
            const SizedBox(height: 18),
            editTextRow(text.t('SKU Name'), nameController, errorText: requiredTextError(text.t('SKU Name'), nameController)),
            tagEditRow(text.t('Tag 1'), categoryController),
            tagEditRow(text.t('Tag 2'), locationController),
            editTextRow(text.t('Unit'), unitController, errorText: requiredTextError(text.t('Unit'), unitController)),
            receivingChecklistRow(text.t('Receiving Checklist')),
            resetTimeRow(text.t('Reset Time')),
            editTextRow(text.t('Recovery'), recoveryController, suffix: '%', keyboardType: TextInputType.number, errorText: requiredNumberError(text.t('Recovery'), recoveryController)),
            if (editing)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(priceLabel, style: AppTextStyles.formLabel)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: editableBoxDecoration(),
                          width: 86,
                          child: TextField(
                            controller: minPriceController,
                            style: AppTextStyles.formValue,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => refreshEditValidation(),
                            decoration: _inputDecoration('').copyWith(
                              isDense: true,
                              labelText: text.t('Min'),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              errorText: minPriceError,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('/')),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: editableBoxDecoration(),
                          width: 86,
                          child: TextField(
                            controller: maxPriceController,
                            style: AppTextStyles.formValue,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => refreshEditValidation(),
                            decoration: _inputDecoration('').copyWith(
                              isDense: true,
                              labelText: text.t('Max'),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              errorText: maxPriceError,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              detailRow(priceLabel, '${text.t('Min')} ${formatStockNumber(sku.minimumPriceRm)} / ${text.t('Max')} ${formatStockNumber(sku.maximumPriceRm)}'),
            if (editing)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
                child: Row(
                  children: [
                    Expanded(child: Text(balanceLabel, style: AppTextStyles.formLabel)),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: editableBoxDecoration(),
                      width: 72,
                      child: TextField(
                        controller: minBalanceController,
                        style: AppTextStyles.formValue,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => refreshEditValidation(),
                        decoration: _inputDecoration('').copyWith(
                          isDense: true,
                          labelText: text.t('Min'),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          errorText: minBalanceError,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text('/')),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: editableBoxDecoration(),
                      width: 72,
                      child: TextField(
                        controller: balanceController,
                        style: AppTextStyles.formValue,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          syncBalance(value);
                          refreshEditValidation();
                        },
                        decoration: _inputDecoration('').copyWith(
                          isDense: true,
                          labelText: text.t('Current'),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          errorText: currentBalanceError,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text('/')),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: editableBoxDecoration(),
                      width: 88,
                      child: TextField(
                        controller: maxBalanceController,
                        style: AppTextStyles.formValue,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          syncBalance(balanceController.text);
                          refreshEditValidation();
                        },
                        decoration: _inputDecoration('').copyWith(
                          isDense: true,
                          labelText: text.t('Max'),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          errorText: maxBalanceError,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              detailRow(balanceLabel, '${text.t('Min')} ${formatStockNumber(sku.minimumBalanceValue)} / ${text.t('Current')} ${formatStockNumber(currentBalance)} / ${text.t('Max')} ${formatStockNumber(sku.maximumBalanceValue)}'),
            suppliersRow(text.t('Suppliers')),
            detailRow(text.t('Created By'), sku.lastUpdatedBy),
            detailRow(text.t('Created Date'), '12 Mar 2024'),
            detailRow(text.t('Last Updated'), sku.lastUpdatedAt),
            const SizedBox(height: 16),
            if (editing)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: resetEditFields,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(text.t('Cancel')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColours.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        unawaited(AppFeedback.tap());
                        saveSku();
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(text.t('Save')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(text.t('Delete')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColours.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => editing = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(text.t('Edit')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}



class _AuditTrailPage extends StatefulWidget {
  final Future<EastAppPage<StockAuditEntry>> Function(
      DateTime rangeStart, DateTime rangeEnd, int page, int size) onLoadEntries;
  final VoidCallback onBack;

  const _AuditTrailPage({
    required this.onLoadEntries,
    required this.onBack,
  });

  @override
  State<_AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<_AuditTrailPage> {
  final searchController = TextEditingController();
  String moduleFilter = 'All';
  String actorFilter = 'All';
  late DateTime rangeStart;
  late DateTime rangeEnd;
  List<StockAuditEntry> loadedEntries = const [];
  bool hasLoaded = false;
  bool loading = false;
  bool loadingMore = false;
  int loadedPage = -1;
  int totalEntries = 0;
  bool lastPage = true;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    rangeEnd = today;
    rangeStart = today.subtract(const Duration(days: 29));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month && left.day == right.day;

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String get rangeLabel => '${_formatDate(rangeStart)} – ${_formatDate(rangeEnd)}';

  List<String> get moduleOptions {
    final values = loadedEntries
        .map((entry) => entry.module)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<String> get actorOptions {
    final values = loadedEntries
        .map((entry) => entry.actorName)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<StockAuditEntry> get filteredEntries {
    final query = searchController.text.trim().toLowerCase();
    final entries = loadedEntries.where((entry) {
      final matchesSearch = query.isEmpty ||
          entry.module.toLowerCase().contains(query) ||
          entry.action.toLowerCase().contains(query) ||
          entry.itemName.toLowerCase().contains(query) ||
          entry.itemId.toLowerCase().contains(query) ||
          entry.actorName.toLowerCase().contains(query) ||
          entry.actorId.toLowerCase().contains(query) ||
          entry.changes.any((change) =>
              change.field.toLowerCase().contains(query) ||
              change.oldValue.toLowerCase().contains(query) ||
              change.newValue.toLowerCase().contains(query));
      final matchesModule = moduleFilter == 'All' || entry.module == moduleFilter;
      final matchesActor = actorFilter == 'All' || entry.actorName == actorFilter;
      return matchesSearch && matchesModule && matchesActor;
    }).toList();
    entries.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return entries;
  }

  Future<void> selectDateRange() async {
    final text = AppTextScope.of(context);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: DateTimeRange(start: rangeStart, end: rangeEnd),
      helpText: text.t('Select Date Range'),
      saveText: text.t('Apply'),
      switchToInputEntryModeIcon: const Icon(Icons.edit_rounded),
      builder: (pickerContext, child) {
        final baseTheme = Theme.of(pickerContext);
        return Theme(
          data: baseTheme.copyWith(
            datePickerTheme: baseTheme.datePickerTheme.copyWith(
              rangePickerBackgroundColor: AppColours.background,
              rangePickerHeaderBackgroundColor: AppColours.card,
              rangePickerHeaderForegroundColor: AppColours.textMain,
              rangePickerHeaderHelpStyle: AppTextStyles.formLabel.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColours.textMain,
              ),
              rangePickerHeaderHeadlineStyle: const TextStyle(
                fontSize: AppTextSize.s22,
                fontWeight: FontWeight.w800,
                color: AppColours.textMain,
              ),
              confirmButtonStyle: FilledButton.styleFrom(
                backgroundColor: AppColours.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: AppColours.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColours.border,
                disabledForegroundColor: AppColours.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected == null || !mounted) return;

    final selectedStart = _dateOnly(selected.start);
    final selectedEnd = _dateOnly(selected.end);
    final selectedDays = selectedEnd.difference(selectedStart).inDays + 1;
    if (selectedDays > 30) {
      await AppFeedback.warning();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.t('Maximum 30 days.'))),
      );
      return;
    }

    setState(() {
      rangeStart = selectedStart;
      rangeEnd = selectedEnd;
      moduleFilter = 'All';
      actorFilter = 'All';
      searchController.clear();
      loadedEntries = const [];
      hasLoaded = false;
      loadedPage = -1;
      totalEntries = 0;
      lastPage = true;
    });
  }

  Future<void> loadAuditEntries({bool reset = true}) async {
    if (loading || loadingMore || (!reset && lastPage)) return;
    setState(() {
      if (reset) {
        loading = true;
      } else {
        loadingMore = true;
      }
    });
    try {
      final nextPage = reset ? 0 : loadedPage + 1;
      final result = await widget.onLoadEntries(
        rangeStart,
        rangeEnd,
        nextPage,
        50,
      );
      if (!mounted) return;
      setState(() {
        loadedEntries = reset
            ? result.content
            : [...loadedEntries, ...result.content];
        hasLoaded = true;
        loadedPage = result.page;
        totalEntries = result.totalElements;
        lastPage = result.last;
        if (reset) {
          moduleFilter = 'All';
          actorFilter = 'All';
          searchController.clear();
        }
      });
    } on EastAppApiException catch (_) {
      // The global API error dialog already presents the failure.
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Widget auditDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = options.contains(value) ? value : 'All';
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      isDense: true,
      style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13, fontWeight: FontWeight.w500),
              ),
            ),
          )
          .toList(),
      onChanged: (newValue) {
        if (newValue == null) return;
        onChanged(newValue);
      },
      decoration: _inputDecoration(label).copyWith(
        isDense: true,
        hintText: null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      ),
    );
  }

  List<Widget> auditRows(List<StockAuditEntry> entries) {
    final rows = <Widget>[];
    DateTime? previousDate;

    for (final entry in entries) {
      final entryDate = _dateOnly(entry.capturedAt);
      if (previousDate == null || !_sameDate(previousDate, entryDate)) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 4));
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            child: Text(
              _formatDate(entryDate),
              style: const TextStyle(
                fontSize: AppTextSize.s13,
                fontWeight: FontWeight.w800,
                color: AppColours.textMuted,
              ),
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AuditEntryCard(entry: entry),
        ),
      );
      previousDate = entryDate;
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final entries = hasLoaded ? filteredEntries : const <StockAuditEntry>[];
    final rangeEntries = loadedEntries;
    final actorCount = rangeEntries.map((entry) => entry.actorId).where((value) => value.trim().isNotEmpty).toSet().length;

    return _PageScaffold(
      title: text.t('Audit Trail'),
      subtitle: text.t('State changes only. Select up to 30 days.'),
      onBack: widget.onBack,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: selectDateRange,
            icon: const Icon(Icons.date_range_rounded, size: 20),
            label: Row(
              children: [
                Expanded(
                  child: Text(
                    rangeLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          text: loading ? text.t('Loading...') : text.t(hasLoaded ? 'Reload Audit' : 'Load Audit'),
          icon: loading ? null : Icons.download_rounded,
          onPressed: loading ? null : () => loadAuditEntries(),
        ),
        const SizedBox(height: 12),
        if (!hasLoaded)
          WhiteCard(
            child: Text(
              text.t('Select a date range, then load the audit trail.'),
              style: const TextStyle(
                fontSize: AppTextSize.s15,
                fontWeight: FontWeight.w600,
                color: AppColours.textMuted,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(child: _MiniMetric(label: text.t('Entries'), value: '$totalEntries', icon: Icons.manage_history_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _MiniMetric(label: text.t('Actors'), value: '$actorCount', icon: Icons.people_outline_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _MiniMetric(label: text.t('Showing'), value: '${entries.length}', icon: Icons.filter_alt_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            style: AppTextStyles.formValue,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(text.t('Search audit trail')).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: width, child: auditDropdown(label: text.t('Actor'), value: actorFilter, options: actorOptions, onChanged: (value) => setState(() => actorFilter = value))),
                  SizedBox(width: width, child: auditDropdown(label: text.t('Module'), value: moduleFilter, options: moduleOptions, onChanged: (value) => setState(() => moduleFilter = value))),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            WhiteCard(
              child: Text(
                text.t('No audit trail found.'),
                style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700),
              ),
            )
          else
            ...auditRows(entries),
          if (!lastPage) ...[
            const SizedBox(height: 4),
            PrimaryButton(
              text: loadingMore ? text.t('Loading...') : text.t('Load More'),
              icon: loadingMore ? null : Icons.expand_more_rounded,
              onPressed: loadingMore
                  ? null
                  : () => loadAuditEntries(reset: false),
            ),
          ],
        ],
      ],
    );
  }
}

class _AuditEntryCard extends StatefulWidget {
  final StockAuditEntry entry;

  const _AuditEntryCard({required this.entry});

  @override
  State<_AuditEntryCard> createState() => _AuditEntryCardState();
}

class _AuditEntryCardState extends State<_AuditEntryCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final roleText = entry.actorRole.isEmpty ? '-' : entry.actorRole.toUpperCase();
    final hasDetails = entry.changes.isNotEmpty || entry.note.trim().isNotEmpty;

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: hasDetails ? () => setState(() => expanded = !expanded) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.action,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w800, color: AppColours.textMain),
                                ),
                              ),
                              SmallStatusPill(
                                text: entry.module,
                                textColour: AppColours.blue,
                                backgroundColour: AppColours.blueSoft,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: AppTextSize.s14, fontWeight: FontWeight.w700, color: AppColours.textMain),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${entry.actorName} · ${entry.actorId} · $roleText · ${entry.timestampText}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w600, color: AppColours.textMuted, height: 1.25),
                          ),
                          if (hasDetails) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  entry.changes.isEmpty ? 'Details' : '${entry.changes.length} change${entry.changes.length == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w800, color: AppColours.blue),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 18,
                                  color: AppColours.blue,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (expanded && entry.changes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColours.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColours.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < entry.changes.length; i++) ...[
                          _AuditChangeRow(change: entry.changes[i]),
                          if (i != entry.changes.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ],
                if (expanded && entry.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.note,
                    style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w600, color: AppColours.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditChangeRow extends StatelessWidget {
  final StockAuditChange change;

  const _AuditChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              change.field,
              style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w800, color: AppColours.textMuted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.oldValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w600, color: AppColours.textMuted),
                ),
                const SizedBox(height: 3),
                Row(
                  children: const [
                    Icon(Icons.arrow_downward_rounded, size: 13, color: AppColours.blue),
                    SizedBox(width: 4),
                    Text('changed to', style: TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w700, color: AppColours.blue)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  change.newValue,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w800, color: AppColours.textMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkuAssigneePage extends StatefulWidget {
  final EastAppApi api;
  final VoidCallback onBack;
  final Future<void> Function(StockSku sku) onUpdateSku;

  const _SkuAssigneePage({
    required this.api,
    required this.onBack,
    required this.onUpdateSku,
  });

  @override
  State<_SkuAssigneePage> createState() => _SkuAssigneePageState();
}

class _SkuAssigneePageState extends State<_SkuAssigneePage> {
  static const int _pageSize = 50;

  final searchController = TextEditingController();
  final List<StockSku> loadedSkus = [];
  final List<EastAppUser> availableUsers = [];

  String assignmentFilter = 'Assigned';
  bool hasLoaded = false;
  bool skusLoading = false;
  bool skusLoadingMore = false;
  String? skusError;
  int skusPage = 0;
  int totalSkus = 0;
  bool skusLastPage = true;

  bool usersLoaded = false;
  int usersPage = 0;
  bool usersLastPage = true;
  bool usersLoading = false;
  bool usersLoadingMore = false;
  String? usersError;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _clearLoadedResults() {
    if (!hasLoaded && loadedSkus.isEmpty && skusError == null) return;
    setState(() {
      hasLoaded = false;
      loadedSkus.clear();
      skusError = null;
      skusPage = 0;
      totalSkus = 0;
      skusLastPage = true;
    });
  }

  Future<void> loadSkus({required bool reset}) async {
    if (skusLoading || skusLoadingMore) return;
    final nextPage = reset ? 0 : skusPage + 1;
    setState(() {
      if (reset) {
        skusLoading = true;
        skusError = null;
      } else {
        skusLoadingMore = true;
      }
    });

    try {
      final result = await widget.api.stockSkus(
        search: searchController.text.trim(),
        active: true,
        assigned: assignmentFilter == 'Assigned',
        page: nextPage,
        size: _pageSize,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        if (reset) loadedSkus.clear();
        loadedSkus.addAll(result.content);
        skusPage = result.page;
        totalSkus = result.totalElements;
        skusLastPage = result.last;
        hasLoaded = true;
        skusLoading = false;
        skusLoadingMore = false;
      });
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        skusError = error.message;
        hasLoaded = true;
        skusLoading = false;
        skusLoadingMore = false;
      });
    }
  }

  Future<bool> loadUsers({required bool reset}) async {
    if (usersLoading || usersLoadingMore) return false;
    final nextPage = reset ? 0 : usersPage + 1;
    setState(() {
      if (reset) {
        usersLoading = true;
        usersError = null;
      } else {
        usersLoadingMore = true;
      }
    });
    try {
      final result = await widget.api.listUsers(
        active: true,
        page: nextPage,
        size: _pageSize,
      );
      if (!mounted) return false;
      setState(() {
        if (reset) availableUsers.clear();
        availableUsers.addAll(result.content);
        usersPage = result.page;
        usersLastPage = result.last;
        usersLoaded = true;
        usersLoading = false;
        usersLoadingMore = false;
        usersError = null;
      });
      return true;
    } on EastAppApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        usersError = error.message;
        usersLoading = false;
        usersLoadingMore = false;
      });
      return false;
    }
  }

  List<String> get assigneeOptions {
    final values = <String>{
      ...availableUsers
          .map((user) => user.fullName.trim())
          .where((value) => value.isNotEmpty),
    };
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Future<void> openAssigneePicker(StockSku sku) async {
    final text = AppTextScope.of(context);

    // Users are intentionally loaded only after the user explicitly opens
    // the assignee action. Opening the Assignee page itself performs no fetch.
    if (!usersLoaded) {
      final loaded = await loadUsers(reset: true);
      if (!mounted) return;
      if (!loaded && usersError != null) {
        showErrorSnackBar(context, usersError!);
        return;
      }
    }

    final result = await showStockBottomSheet<List<String>>(
      context,
      maxHeightFactor: 0.72,
      builder: (sheetContext) {
        final temp = sku.assignedStaffNames.toSet();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final options = assigneeOptions;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Column(
                    children: [
                      stockBottomSheetHandle(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text.t('Assignee'),
                              style: const TextStyle(
                                fontSize: AppTextSize.s24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          sku.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTextSize.s14,
                            color: AppColours.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: options.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            text.t('No user available.'),
                            style: AppTextStyles.formValue,
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            ...options.map((user) {
                              final selected = temp.contains(user);
                              return CheckboxListTile(
                                value: selected,
                                title: Text(user),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value == true) {
                                      temp.add(user);
                                    } else {
                                      temp.remove(user);
                                    }
                                  });
                                },
                              );
                            }),
                            if (!usersLastPage)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: OutlinedButton.icon(
                                  onPressed: usersLoadingMore
                                      ? null
                                      : () async {
                                          await loadUsers(reset: false);
                                          if (sheetContext.mounted) {
                                            setSheetState(() {});
                                          }
                                        },
                                  icon: usersLoadingMore
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    usersLoadingMore
                                        ? text.t('Loading...')
                                        : text.t('Load more users'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Clear'),
                          outlined: true,
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(<String>[]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Save'),
                          icon: Icons.save_outlined,
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(temp.toList()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;

    final confirmed = await confirmDataChange(
      context,
      action: 'Update SKU Assignees?',
      details: 'This will replace the assignee list for the selected SKU.',
    );
    if (!confirmed || !mounted) return;

    final updatedSku = sku.copyWith(assignedStaffNames: result);
    final saved = await runStockRequest(
      context,
      () => widget.onUpdateSku(updatedSku),
    );
    if (!saved || !mounted) return;

    final stillMatches = assignmentFilter == 'Assigned'
        ? updatedSku.assignedStaffNames.isNotEmpty
        : updatedSku.assignedStaffNames.isEmpty;
    setState(() {
      final index = loadedSkus.indexWhere((item) => item.id == sku.id);
      if (index >= 0) {
        if (stillMatches) {
          loadedSkus[index] = updatedSku;
        } else {
          loadedSkus.removeAt(index);
          if (totalSkus > 0) totalSkus -= 1;
        }
      }
    });
    showSuccessSnackBar(context, text.t('Assignee updated'));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return _PageScaffold(
      title: text.t('Assignee'),
      subtitle: text.t('Load Assigned or Unassigned SKU only when needed.'),
      onBack: widget.onBack,
      children: [
        DropdownButtonFormField<String>(
          initialValue: assignmentFilter,
          isExpanded: true,
          decoration: _inputDecoration(text.t('Assignment status')),
          items: const ['Assigned', 'Unassigned']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(text.t(value)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null || value == assignmentFilter) return;
            setState(() => assignmentFilter = value);
            _clearLoadedResults();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => _clearLoadedResults(),
          onSubmitted: (_) {},
          textInputAction: TextInputAction.search,
          decoration: _inputDecoration(text.t('Search SKU (optional)')).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          text: text.t('Load'),
          icon: Icons.download_rounded,
          onPressed: skusLoading ? null : () => loadSkus(reset: true),
        ),
        const SizedBox(height: 14),
        if (skusLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (skusError != null)
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColours.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        skusError!,
                        style: const TextStyle(
                          color: AppColours.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: text.t('Retry'),
                  outlined: true,
                  onPressed: () => loadSkus(reset: true),
                ),
              ],
            ),
          )
        else if (!hasLoaded)
          WhiteCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.touch_app_outlined, color: AppColours.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.t(
                      'Nothing is loaded by default. Select Assigned or Unassigned, then press Load.',
                    ),
                    style: const TextStyle(
                      fontSize: AppTextSize.s14,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (loadedSkus.isEmpty)
          WhiteCard(
            child: Text(
              text.t('No SKU matches the selected criteria.'),
              style: const TextStyle(
                fontSize: AppTextSize.s16,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${text.t('Results')}: $totalSkus',
              style: const TextStyle(
                fontSize: AppTextSize.s13,
                fontWeight: FontWeight.w700,
                color: AppColours.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: loadedSkus.map((sku) {
                final currentAssignee = sku.assignedStaffName;
                final selectedCount = sku.assignedStaffNames.length;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColours.border),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SkuPhotoThumb(sku: sku, size: 46),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sku.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.s16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${sku.category} · ${sku.location}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.s13,
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentAssignee,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.s12,
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 116,
                        child: OutlinedButton.icon(
                          onPressed: () => openAssigneePicker(sku),
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: Text(
                            selectedCount == 0
                                ? text.t('Assign')
                                : '$selectedCount ${text.t('user')}',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (!skusLastPage) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              text: skusLoadingMore
                  ? text.t('Loading...')
                  : text.t('Load more'),
              outlined: true,
              icon: Icons.expand_more_rounded,
              onPressed:
                  skusLoadingMore ? null : () => loadSkus(reset: false),
            ),
          ],
        ],
      ],
    );
  }
}


class _SupplierSetupPage extends StatefulWidget {
  final List<SupplierProfile> suppliers;
  final VoidCallback onBack;
  final Future<void> Function(SupplierProfile supplier) onCreateSupplier;
  final Future<void> Function(SupplierProfile supplier) onUpdateSupplier;
  final Future<bool> Function(Set<String> supplierIds) onDeleteSuppliers;

  const _SupplierSetupPage({
    required this.suppliers,
    required this.onBack,
    required this.onCreateSupplier,
    required this.onUpdateSupplier,
    required this.onDeleteSuppliers,
  });

  @override
  State<_SupplierSetupPage> createState() => _SupplierSetupPageState();
}

class _SupplierSetupPageState extends State<_SupplierSetupPage> {
  late List<SupplierProfile> suppliers;
  final searchController = TextEditingController();
  final Set<String> selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    suppliers = _sortSuppliersAlphabetically(widget.suppliers);
  }

  @override
  void didUpdateWidget(covariant _SupplierSetupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suppliers != widget.suppliers) {
      suppliers = _sortSuppliersAlphabetically(widget.suppliers);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<SupplierProfile> get filteredSuppliers {
    final query = searchController.text.trim().toLowerCase();
    final source = query.isEmpty
        ? suppliers
        : suppliers.where((supplier) {
            return [
              supplier.supplierName,
              supplier.contactPerson,
              supplier.phone,
              supplier.address,
              supplier.notes,
            ].join(' ').toLowerCase().contains(query);
          });
    return _sortSuppliersAlphabetically(source);
  }

  void addSupplier() {
    showAddSupplierDialog(
      context,
      onCreateSupplier: widget.onCreateSupplier,
    );
  }

  Future<void> deleteSelected() async {
    final confirmed = await confirmDataChange(
      context,
      action: 'Delete Selected Suppliers?',
      details: 'This will permanently delete the selected unassigned suppliers.',
    );
    if (!confirmed || !mounted) return;

    try {
      final deleted = await widget.onDeleteSuppliers(Set<String>.from(selectedIds));
      if (!mounted) return;
      if (!deleted) {
        showErrorSnackBar(context, 'Assigned suppliers cannot be deleted');
        return;
      }
      setState(selectedIds.clear);
      showSuccessSnackBar(context, 'Deleted');
    } on EastAppApiException catch (_) {
      // The global API error dialog already presents the failure.
    }
  }

  void toggleSelected(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void showSupplierDetail(SupplierProfile supplier) {
    final text = AppTextScope.of(context);
    final nameController = TextEditingController(text: supplier.supplierName);
    final contactController = TextEditingController(text: supplier.contactPerson);
    final phoneController = TextEditingController(text: supplier.phone);
    final addressController = TextEditingController(text: supplier.address);
    final notesController = TextEditingController(text: supplier.notes);
    bool isEditing = false;

    SupplierProfile buildUpdatedSupplier() {
      return SupplierProfile(
        id: supplier.id,
        supplierName: nameController.text.trim().isEmpty ? supplier.supplierName : nameController.text.trim(),
        supplierItem: supplier.supplierItem,
        contactPerson: contactController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        notes: notesController.text.trim(),
        unit: supplier.unit,
        recommendedPurchaseAmount: supplier.recommendedPurchaseAmount,
        recommendedPurchaseFrequency: supplier.recommendedPurchaseFrequency,
        pricingPerUnit: supplier.pricingPerUnit,
        minimumBalanceValue: supplier.minimumBalanceValue,
        maximumBalanceValue: supplier.maximumBalanceValue,
        currentBalanceValue: supplier.currentBalanceValue,
        lastBalanceUpdatedAt: 'Today just now',
        lastBalanceUpdatedBy: headId,
      );
    }

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.86,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final title = nameController.text.trim().isEmpty
                ? supplier.supplierName
                : nameController.text.trim();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  stockBottomSheetHandle(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700))),
                      IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SetupDetailRow(label: text.t('Supplier Name'), value: supplier.supplierName, controller: nameController, isEditing: isEditing),
                  _SetupDetailRow(label: text.t('Contact Person'), value: supplier.contactPerson, controller: contactController, isEditing: isEditing),
                  _SetupDetailRow(label: text.t('Phone'), value: supplier.phone, controller: phoneController, isEditing: isEditing, keyboardType: TextInputType.phone),
                  _SetupDetailRow(label: text.t('Address'), value: supplier.address, controller: addressController, isEditing: isEditing),
                  _SetupDetailRow(label: text.t('Notes'), value: supplier.notes, controller: notesController, isEditing: isEditing),
                  _SetupDetailRow(label: text.t('Created By'), value: supplier.lastBalanceUpdatedBy),
                  _SetupDetailRow(label: text.t('Created Date'), value: '12 Mar 2024'),
                  _SetupDetailRow(label: text.t('Last Updated'), value: supplier.lastBalanceUpdatedAt),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (!isEditing) {
                              setSheetState(() => isEditing = true);
                              return;
                            }
                            final updated = buildUpdatedSupplier();
                            final confirmed = await confirmDataChange(
                              context,
                              action: 'Update Supplier?',
                              details: 'This will save the edited supplier information.',
                            );
                            if (!confirmed || !context.mounted) return;

                            final saved = await runStockRequest(
                              context,
                              () => widget.onUpdateSupplier(updated),
                            );
                            if (!saved || !context.mounted || !sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            showSuccessSnackBar(context, text.t('Saved'));
                          },
                          icon: Icon(isEditing ? Icons.save_outlined : Icons.edit_outlined),
                          label: Text(text.t(isEditing ? 'Save' : 'Edit')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isEditing ? AppColours.textMuted : AppColours.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (isEditing) {
                              setSheetState(() => isEditing = false);
                              return;
                            }
                            final confirmed = await confirmDataChange(
                              context,
                              action: 'Delete Supplier?',
                              details: 'This will permanently delete this unassigned supplier.',
                            );
                            if (!confirmed || !context.mounted) return;

                            try {
                              final deleted = await widget.onDeleteSuppliers({supplier.id});
                              if (!context.mounted || !sheetContext.mounted) return;
                              if (!deleted) {
                                showErrorSnackBar(context, 'Assigned suppliers cannot be deleted');
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                              showSuccessSnackBar(context, text.t('Deleted'));
                            } on EastAppApiException catch (_) {
                              // The global API error dialog already presents the failure.
                            }
                          },
                          icon: Icon(isEditing ? Icons.close_rounded : Icons.delete_outline),
                          label: Text(text.t(isEditing ? 'Cancel' : 'Delete')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final items = filteredSuppliers;
    final selecting = selectedIds.isNotEmpty;

    return _PageScaffold(
      title: text.t('Supplier'),
      subtitle: text.t('Create/list Supplier'),
      onBack: widget.onBack,
      trailing: SizedBox(
        width: selecting ? 120 : 150,
        child: selecting
            ? ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColours.red, foregroundColor: Colors.white),
                onPressed: deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text(text.t('Delete')),
              )
            : PrimaryButton(
                text: text.t('Add Supplier'),
                icon: Icons.add_business_outlined,
                onPressed: addSupplier,
              ),
      ),
      children: [
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(text.t('Search')).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          WhiteCard(child: Text(text.t('No supplier found'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)))
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _CompactSupplierRow(
                    supplier: items[i],
                    selected: selectedIds.contains(items[i].id),
                    selecting: selecting,
                    onTap: () => selecting ? toggleSelected(items[i].id) : showSupplierDetail(items[i]),
                    onLongPress: () => toggleSelected(items[i].id),
                  ),
                  if (i != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CompactSupplierRow extends StatelessWidget {
  final SupplierProfile supplier;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CompactSupplierRow({
    required this.supplier,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (supplier.contactPerson.isNotEmpty) supplier.contactPerson,
      if (supplier.phone.isNotEmpty) supplier.phone,
      if (supplier.address.isNotEmpty) supplier.address,
    ].join(' · ');

    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? AppColours.blue : const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(selected ? Icons.check_rounded : Icons.local_shipping_outlined, color: selected ? Colors.white : AppColours.blue, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.supplierName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w700)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            if (selecting)
              Checkbox(value: selected, onChanged: (_) => onTap())
            else
              const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
          ],
        ),
      ),
      ),
    );
  }
}



class _TagSetupPage extends StatefulWidget {
  final List<StockTag> tags;
  final VoidCallback onBack;
  final Future<void> Function(StockTag tag) onCreateTag;
  final Future<void> Function(StockTag tag) onUpdateTag;
  final Future<bool> Function(Set<String> tagIds) onDeleteTags;

  const _TagSetupPage({
    required this.tags,
    required this.onBack,
    required this.onCreateTag,
    required this.onUpdateTag,
    required this.onDeleteTags,
  });

  @override
  State<_TagSetupPage> createState() => _TagSetupPageState();
}

class _TagSetupPageState extends State<_TagSetupPage> {
  final searchController = TextEditingController();
  final Set<String> selectedIds = <String>{};

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<StockTag> get filteredTags {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.tags;
    return widget.tags
        .where((tag) => tag.tag.toLowerCase().contains(query))
        .toList();
  }

  void addTag() {
    final text = AppTextScope.of(context);
    final tagController = TextEditingController();

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.55,
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stockBottomSheetHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.t('Add Tag'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DialogInput(
                label: text.t('Tag'),
                controller: tagController,
                hint: text.t('Example: Chiller'),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                text: text.t('Save'),
                icon: Icons.save_outlined,
                onPressed: () async {
                  final nextTag = tagController.text.trim();
                  if (nextTag.isEmpty) return;
                  final alreadyExists = widget.tags.any(
                    (tag) => tag.tag.toLowerCase() == nextTag.toLowerCase(),
                  );
                  if (alreadyExists) {
                    showErrorSnackBar(context, text.t('Tag already exists'));
                    return;
                  }
                  final confirmed = await confirmDataChange(
                    context,
                    action: 'Create Tag?',
                    details: 'This will create a new Stock tag for the this business.',
                  );
                  if (!confirmed || !mounted) return;

                  final saved = await runStockRequest(
                    context,
                    () => widget.onCreateTag(
                      StockTag(
                        id: 'TAG${DateTime.now().millisecondsSinceEpoch}',
                        tag: nextTag,
                        createdBy: headId,
                        createdDate: 'Today',
                        lastUpdated: 'Today just now',
                      ),
                    ),
                  );
                  if (!saved || !mounted || !sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  showSuccessSnackBar(context, text.t('Saved'));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void toggleSelected(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  Future<void> deleteSelected() async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: 'Delete Selected Tags?',
      details: 'This will permanently delete the selected unassigned tags.',
    );
    if (!confirmed || !mounted) return;

    try {
      final deleted = await widget.onDeleteTags(Set<String>.from(selectedIds));
      if (!mounted) return;
      if (!deleted) {
        showErrorSnackBar(
          context,
          text.t('Assigned tags cannot be deleted'),
        );
        return;
      }
      setState(selectedIds.clear);
      showSuccessSnackBar(context, text.t('Deleted'));
    } on EastAppApiException catch (_) {
      // The global API error dialog already presents the failure.
    }
  }

  void showTagDetail(StockTag tag) {
    final text = AppTextScope.of(context);
    final tagController = TextEditingController(text: tag.tag);
    bool isEditing = false;

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.7,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentValue = tagController.text.trim().isEmpty
                ? tag.tag
                : tagController.text.trim();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  stockBottomSheetHandle(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          currentValue,
                          style: const TextStyle(
                            fontSize: AppTextSize.s26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SetupDetailRow(
                    label: text.t('Tag'),
                    value: tag.tag,
                    controller: tagController,
                    isEditing: isEditing,
                  ),
                  _SetupDetailRow(
                    label: text.t('Created By'),
                    value: tag.createdBy,
                  ),
                  _SetupDetailRow(
                    label: text.t('Created Date'),
                    value: tag.createdDate,
                  ),
                  _SetupDetailRow(
                    label: text.t('Last Updated'),
                    value: tag.lastUpdated,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (!isEditing) {
                              setSheetState(() => isEditing = true);
                              return;
                            }
                            final nextTag = tagController.text.trim();
                            if (nextTag.isEmpty) return;
                            final alreadyExists = widget.tags.any(
                              (item) =>
                                  item.id != tag.id &&
                                  item.tag.toLowerCase() == nextTag.toLowerCase(),
                            );
                            if (alreadyExists) {
                              showErrorSnackBar(
                                context,
                                text.t('Tag already exists'),
                              );
                              return;
                            }
                            final confirmed = await confirmDataChange(
                              context,
                              action: 'Update Tag?',
                              details: 'This will rename the selected tag.',
                            );
                            if (!confirmed || !context.mounted) return;

                            final saved = await runStockRequest(
                              context,
                              () => widget.onUpdateTag(
                                tag.copyWith(
                                  tag: nextTag,
                                  lastUpdated: 'Today just now',
                                ),
                              ),
                            );
                            if (!saved || !context.mounted || !sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            showSuccessSnackBar(context, text.t('Saved'));
                          },
                          icon: Icon(
                            isEditing
                                ? Icons.save_outlined
                                : Icons.edit_outlined,
                          ),
                          label: Text(text.t(isEditing ? 'Save' : 'Edit')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isEditing
                                ? AppColours.textMuted
                                : AppColours.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (isEditing) {
                              setSheetState(() => isEditing = false);
                              return;
                            }
                            final confirmed = await confirmDataChange(
                              context,
                              action: 'Delete Tag?',
                              details: 'This will permanently delete this unassigned tag.',
                            );
                            if (!confirmed || !context.mounted) return;

                            try {
                              final deleted = await widget.onDeleteTags({tag.id});
                              if (!context.mounted || !sheetContext.mounted) return;
                              if (!deleted) {
                                showErrorSnackBar(
                                  context,
                                  text.t('Assigned tags cannot be deleted'),
                                );
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                              showSuccessSnackBar(context, text.t('Deleted'));
                            } on EastAppApiException catch (_) {
                              // The global API error dialog already presents the failure.
                            }
                          },
                          icon: Icon(
                            isEditing
                                ? Icons.close_rounded
                                : Icons.delete_outline,
                          ),
                          label: Text(
                            text.t(isEditing ? 'Cancel' : 'Delete'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final items = filteredTags;
    final selecting = selectedIds.isNotEmpty;

    return _PageScaffold(
      title: text.t('Tag'),
      subtitle: text.t('Custom Category'),
      onBack: widget.onBack,
      trailing: SizedBox(
        width: selecting ? 120 : 150,
        child: selecting
            ? ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text(text.t('Delete')),
              )
            : PrimaryButton(
                text: text.t('Add Tag'),
                icon: Icons.add_rounded,
                onPressed: addTag,
              ),
      ),
      children: [
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(text.t('Search')).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          WhiteCard(
            child: Text(
              text.t('No tag found'),
              style: const TextStyle(
                fontSize: AppTextSize.s16,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _CompactTagRow(
                    tag: items[i],
                    selected: selectedIds.contains(items[i].id),
                    selecting: selecting,
                    onTap: () => selecting
                        ? toggleSelected(items[i].id)
                        : showTagDetail(items[i]),
                    onLongPress: () => toggleSelected(items[i].id),
                  ),
                  if (i != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CompactTagRow extends StatelessWidget {
  final StockTag tag;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CompactTagRow({
    required this.tag,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: selected ? AppColours.blue : const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(12)),
              child: Icon(selected ? Icons.check_rounded : Icons.sell_outlined, color: selected ? Colors.white : AppColours.blue, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(tag.tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w700))),
            if (selecting)
              Checkbox(value: selected, onChanged: (_) => onTap())
            else
              const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
          ],
        ),
      ),
      ),
    );
  }
}

class _SetupDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextEditingController? controller;
  final bool isEditing;
  final TextInputType? keyboardType;

  const _SetupDetailRow({
    required this.label,
    required this.value,
    this.controller,
    this.isEditing = false,
    this.keyboardType,
  });

  BoxDecoration editableBoxDecoration() {
    return BoxDecoration(
      color: AppColours.blueSoft.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColours.blue.withValues(alpha: 0.18)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = isEditing && controller != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.formLabel,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: editable ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
              decoration: editable ? editableBoxDecoration() : null,
              child: editable
                  ? TextField(
                      controller: controller,
                      textAlign: TextAlign.right,
                      keyboardType: keyboardType,
                      style: AppTextStyles.formValue,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                    )
                  : Text(
                      value.isEmpty ? '-' : value,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.formValue,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkuBalanceSummary extends StatelessWidget {
  final StockSku sku;
  final double? currentBalance;

  const _SkuBalanceSummary({
    required this.sku,
    this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final current = currentBalance ?? sku.currentBalanceValue;
    final maximum = sku.maximumBalanceValue <= 0 ? 1.0 : sku.maximumBalanceValue;
    final currentRatio = (current / maximum).clamp(0.0, 1.0).toDouble();
    final belowMinimum = current < sku.minimumBalanceValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: belowMinimum ? AppColours.redSoft : AppColours.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: belowMinimum ? AppColours.red : AppColours.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text.t('Stock Level'),
                  style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${formatStockNumber(current)} / ${formatStockNumber(sku.maximumBalanceValue)} ${sku.unit}',
                style: TextStyle(
                  fontSize: AppTextSize.s15,
                  color: belowMinimum ? AppColours.red : AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColours.border),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    height: 18,
                    width: constraints.maxWidth * currentRatio,
                    decoration: BoxDecoration(
                      color: belowMinimum ? AppColours.red : AppColours.green,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${text.t('Current')}: ${formatStockNumber(current)} ${sku.unit}',
                  style: TextStyle(
                    fontSize: AppTextSize.s14,
                    color: belowMinimum ? AppColours.red : AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${text.t('Minimum')}: ${formatStockNumber(sku.minimumBalanceValue)} ${sku.unit}',
                    style: const TextStyle(
                      fontSize: AppTextSize.s14,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${text.t('Maximum')}: ${formatStockNumber(sku.maximumBalanceValue)} ${sku.unit}',
                    style: const TextStyle(
                      fontSize: AppTextSize.s14,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.formLabel,
      ),
    );
  }
}


class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColours.red,
          fontSize: AppTextSize.s12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint, {String? suffixText, String? prefixText}) {
  return AppInputStyle.decoration(hint, suffixText: suffixText, prefixText: prefixText);
}

class _DialogInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? suffixText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _DialogInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.suffixText,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextField(
          controller: controller,
          style: AppTextStyles.formValue,
          textInputAction: TextInputAction.done,
          keyboardType: suffixText == null
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onEditingComplete: () => FocusManager.instance.primaryFocus?.unfocus(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _inputDecoration(hint, suffixText: suffixText).copyWith(errorText: errorText),
        ),
      ],
    );
  }
}

class _DialogBareInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffixText;
  final String? prefixText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _DialogBareInput({
    required this.controller,
    required this.hint,
    this.suffixText,
    this.prefixText,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.formValue,
      textInputAction: TextInputAction.done,
      keyboardType: suffixText == null && prefixText == null
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onEditingComplete: () => FocusManager.instance.primaryFocus?.unfocus(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: _inputDecoration(hint, suffixText: suffixText, prefixText: prefixText).copyWith(errorText: errorText),
    );
  }
}

void showAddSupplierDialog(
  BuildContext context, {
  required Future<void> Function(SupplierProfile supplier) onCreateSupplier,
}) {
  final text = AppTextScope.of(context);
  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final notesController = TextEditingController();

  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.9,
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stockBottomSheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    text.t('Add Supplier'),
                    style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DialogInput(label: text.t('Supplier Name'), controller: nameController, hint: text.t('Example: GTI Kampar')),
            const SizedBox(height: 14),
            _DialogInput(label: text.t('Contact'), controller: contactController, hint: text.t('Example: Mr Tan')),
            const SizedBox(height: 14),
            _DialogInput(label: text.t('Phone'), controller: phoneController, hint: text.t('Example: 0123456789')),
            const SizedBox(height: 14),
            _DialogInput(label: text.t('Address'), controller: addressController, hint: text.t('Address')),
            const SizedBox(height: 14),
            _DialogInput(label: text.t('Notes'), controller: notesController, hint: text.t('Notes')),
            const SizedBox(height: 18),
            PrimaryButton(
              text: text.t('Save Supplier'),
              icon: Icons.save_outlined,
              onPressed: () async {
                final supplier = SupplierProfile(
                  id: 'SUP${DateTime.now().millisecondsSinceEpoch}',
                  supplierName: nameController.text.trim().isEmpty
                      ? 'New Supplier'
                      : nameController.text.trim(),
                  supplierItem: 'General',
                  contactPerson: contactController.text.trim(),
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  notes: notesController.text.trim(),
                  unit: 'unit',
                  recommendedPurchaseAmount: 0,
                  recommendedPurchaseFrequency: '',
                  pricingPerUnit: 0,
                  minimumBalanceValue: 0,
                  maximumBalanceValue: 1,
                  currentBalanceValue: 0,
                  lastBalanceUpdatedAt: 'Not counted yet',
                  lastBalanceUpdatedBy: headId,
                );
                final confirmed = await confirmDataChange(
                  context,
                  action: 'Create Supplier?',
                  details: 'This will create a new supplier for the this business.',
                );
                if (!confirmed || !context.mounted) return;

                final saved = await runStockRequest(
                  context,
                  () => onCreateSupplier(supplier),
                );
                if (!saved || !context.mounted || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                showSuccessSnackBar(context, text.t('Supplier created'));
              },
            ),
          ],
        ),
      );
    },
  );
}

void showAddSkuDialog(
  BuildContext context, {
  required List<StockTag> tags,
  required List<SupplierProfile> suppliers,
  required Future<void> Function(StockSku sku) onCreateSku,
}) {
  final text = AppTextScope.of(context);
  final api = _StockMediaScope.of(context).api;
  final nameController = TextEditingController();
  final tagNames = tags
      .map((tag) => tag.tag.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  String? selectedTag1;
  String? selectedTag2;
  final receivingChecklistControllers = List<TextEditingController>.generate(5, (_) => TextEditingController());
  final minController = TextEditingController();
  final maxController = TextEditingController();
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();
  String unit = 'kg';
  String resetTime = '08:00';
  int recoveryPercent = 100;
  String? skuPhotoLocalPath;
  bool saving = false;
  bool showErrors = false;
  final selectedSupplierIds = <String>{};
  const units = ['kg', 'pcs', 'box', 'bottle', 'carton', 'ctn', 'pack', 'bag', 'btl', 'biji', 'unit'];

  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.94,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void refreshValidation() {
            if (showErrors) setSheetState(() {});
          }

          String? requiredTextError(String label, TextEditingController controller) {
            return showErrors && controller.text.trim().isEmpty ? text.t('$label required') : null;
          }

          String? requiredNumberError(String label, TextEditingController controller) {
            final raw = controller.text.trim();
            return showErrors && (raw.isEmpty || double.tryParse(raw) == null) ? text.t('$label required') : null;
          }

          final tag1Error = showErrors && selectedTag1 == null
              ? text.t('Tag 1 required')
              : null;
          final tag2Error = showErrors && selectedTag2 == null
              ? text.t('Tag 2 required')
              : null;
          final photoError = showErrors && skuPhotoLocalPath == null ? text.t('Stock Thumbnail required') : null;
          final resetTimeError = showErrors && !isValidStockResetTime(resetTime) ? text.t('Reset Time required') : null;
          final supplierError = showErrors && selectedSupplierIds.isEmpty ? text.t('Supplier required') : null;

          Future<void> takeSkuPhoto() async {
            FocusManager.instance.primaryFocus?.unfocus();
            final path = await Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                builder: (_) => const _StockCameraPage(
                  title: 'Stock Thumbnail',
                  subtitle: 'Take a clear photo of the SKU.',
                ),
                fullscreenDialog: true,
              ),
            );
            if (path == null || !sheetContext.mounted) return;
            setSheetState(() => skuPhotoLocalPath = path);
          }

          Future<void> pickResetTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: parseStockResetTime(resetTime),
            );
            if (picked == null) return;
            setSheetState(() => resetTime = formatStockResetTime(picked));
          }

          Future<void> pickSuppliers() async {
            final result = await showStockBottomSheet<List<String>>(
              context,
              maxHeightFactor: 0.72,
              builder: (supplierSheetContext) {
                final temp = selectedSupplierIds.toSet();
                return StatefulBuilder(
                  builder: (context, setSupplierState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                          child: Column(
                            children: [
                              stockBottomSheetHandle(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      text.t('Suppliers'),
                                      style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.of(supplierSheetContext).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: suppliers.map((supplier) {
                              final selected = temp.contains(supplier.id);
                              return CheckboxListTile(
                                value: selected,
                                title: Text(supplier.supplierName),
                                onChanged: (value) {
                                  setSupplierState(() {
                                    if (value == true) {
                                      temp.add(supplier.id);
                                    } else {
                                      temp.remove(supplier.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  text: text.t('Cancel'),
                                  outlined: true,
                                  onPressed: () => Navigator.of(supplierSheetContext).pop(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PrimaryButton(
                                  text: text.t('Save'),
                                  icon: Icons.save_outlined,
                                  onPressed: () => Navigator.of(supplierSheetContext).pop(temp.toList()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
            if (result == null) return;
            setSheetState(() {
              selectedSupplierIds
                ..clear()
                ..addAll(result);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stockBottomSheetHandle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.t('Add SKU'),
                        style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DialogInput(label: text.t('SKU Name'), controller: nameController, hint: text.t('Example: Chicken'), errorText: requiredTextError(text.t('SKU Name'), nameController), onChanged: (_) => refreshValidation()),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Tag 1')),
                DropdownButtonFormField<String>(
                  initialValue: selectedTag1,
                  isExpanded: true,
                  items: tagNames
                      .map((tag) => DropdownMenuItem<String>(
                            value: tag,
                            child: Text(tag, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(growable: false),
                  onChanged: tagNames.isEmpty
                      ? null
                      : (value) => setSheetState(() => selectedTag1 = value),
                  decoration: _inputDecoration(
                    tagNames.isEmpty
                        ? text.t('Create tag first')
                        : text.t('Select Tag'),
                  ).copyWith(errorText: tag1Error),
                ),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Tag 2')),
                DropdownButtonFormField<String>(
                  initialValue: selectedTag2,
                  isExpanded: true,
                  items: tagNames
                      .map((tag) => DropdownMenuItem<String>(
                            value: tag,
                            child: Text(tag, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(growable: false),
                  onChanged: tagNames.isEmpty
                      ? null
                      : (value) => setSheetState(() => selectedTag2 = value),
                  decoration: _inputDecoration(
                    tagNames.isEmpty
                        ? text.t('Create tag first')
                        : text.t('Select Tag'),
                  ).copyWith(errorText: tag2Error),
                ),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Receiving Checklist')),
                ...List.generate(5, (index) {
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                    child: _DialogBareInput(
                      controller: receivingChecklistControllers[index],
                      hint: text.t('Checklist ${index + 1}'),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Stock Thumbnail')),
                Pressable(
                  onTap: saving ? null : takeSkuPhoto,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 92),
                    decoration: BoxDecoration(
                      color: skuPhotoLocalPath == null
                          ? AppColours.blueSoft.withValues(alpha: 0.55)
                          : Colors.black,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: photoError == null
                            ? skuPhotoLocalPath == null
                                ? AppColours.blue.withValues(alpha: 0.18)
                                : AppColours.green
                            : AppColours.red,
                      ),
                    ),
                    child: skuPhotoLocalPath == null
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.photo_camera_outlined,
                                  color: photoError == null
                                      ? AppColours.blue
                                      : AppColours.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    text.t('Take Photo'),
                                    style: TextStyle(
                                      fontSize: AppTextSize.s16,
                                      fontWeight: FontWeight.w700,
                                      color: photoError == null
                                          ? AppColours.textMain
                                          : AppColours.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(
                                  File(skuPhotoLocalPath!),
                                  width: double.infinity,
                                  height: 190,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0x99000000),
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(13),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      text.t('Retake Photo'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (photoError != null) _InlineError(photoError),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Reset Time')),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: pickResetTime,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColours.blueSoft.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: resetTimeError == null ? AppColours.blue.withValues(alpha: 0.18) : AppColours.red),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            resetTime,
                            style: TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700, color: resetTimeError == null ? AppColours.textMain : AppColours.red),
                          ),
                        ),
                        const Icon(Icons.schedule_rounded, color: AppColours.textMuted),
                      ],
                    ),
                  ),
                ),
                if (resetTimeError != null) _InlineError(resetTimeError),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Unit')),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: _inputDecoration(''),
                  items: units.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => unit = value);
                  },
                ),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Balance')),
                Row(
                  children: [
                    Expanded(child: _DialogBareInput(controller: minController, hint: text.t('Min'), suffixText: unit, errorText: requiredNumberError(text.t('Min'), minController), onChanged: (_) => refreshValidation())),
                    const SizedBox(width: 12),
                    Expanded(child: _DialogBareInput(controller: maxController, hint: text.t('Max'), suffixText: unit, errorText: requiredNumberError(text.t('Max'), maxController), onChanged: (_) => refreshValidation())),
                  ],
                ),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Recovery')),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: recoveryPercent.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        label: '$recoveryPercent%',
                        onChanged: (value) => setSheetState(() => recoveryPercent = value.round()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('$recoveryPercent%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FieldLabel(text.t('Price')),
                Row(
                  children: [
                    Expanded(child: _DialogBareInput(controller: minPriceController, hint: text.t('Min'), prefixText: 'RM', errorText: requiredNumberError(text.t('Min Price'), minPriceController), onChanged: (_) => refreshValidation())),
                    const SizedBox(width: 12),
                    Expanded(child: _DialogBareInput(controller: maxPriceController, hint: text.t('Max'), prefixText: 'RM', errorText: requiredNumberError(text.t('Max Price'), maxPriceController), onChanged: (_) => refreshValidation())),
                  ],
                ),
                const SizedBox(height: 18),
                _FieldLabel(text.t('Suppliers')),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: suppliers.isEmpty
                      ? null
                      : () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          pickSuppliers();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColours.blueSoft.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: supplierError == null ? AppColours.blue.withValues(alpha: 0.18) : AppColours.red),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            suppliers.isEmpty
                                ? text.t('Create supplier first')
                                : selectedSupplierIds.isEmpty
                                    ? text.t('None')
                                    : suppliers.where((supplier) => selectedSupplierIds.contains(supplier.id)).map((supplier) => supplier.supplierName).join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: AppTextSize.s15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),
                  ),
                ),
                if (supplierError != null) _InlineError(supplierError),
                const SizedBox(height: 18),
                PrimaryButton(
                  text: saving ? text.t('Saving...') : text.t('Save SKU'),
                  icon: saving ? null : Icons.save_outlined,
                  onPressed: saving ? null : () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setSheetState(() => showErrors = true);
                    final name = nameController.text.trim();
                    final category = selectedTag1?.trim() ?? '';
                    final location = selectedTag2?.trim() ?? '';
                    final min = double.tryParse(minController.text.trim());
                    final max = double.tryParse(maxController.text.trim());
                    final minPrice = double.tryParse(minPriceController.text.trim());
                    final maxPrice = double.tryParse(maxPriceController.text.trim());

                    if (name.isEmpty ||
                        category.isEmpty ||
                        location.isEmpty ||
                        unit.trim().isEmpty ||
                        min == null ||
                        max == null ||
                        minPrice == null ||
                        maxPrice == null ||
                        !isValidStockResetTime(resetTime) ||
                        selectedSupplierIds.isEmpty ||
                        skuPhotoLocalPath == null) {
                      AppFeedback.warning();
                      return;
                    }

                    if (min < 0 || max <= 0 || max < min) {
                      showWarningSnackBar(context, text.t('Balance must be Min / Max.'));
                      return;
                    }

                    if (minPrice < 0 || maxPrice < minPrice) {
                      showWarningSnackBar(context, text.t('Price must be Min / Max.'));
                      return;
                    }

                    final tag1 = tags.firstWhere((tag) => tag.tag == category);
                    final tag2 = tags.firstWhere((tag) => tag.tag == location);
                    final confirmed = await confirmDataChange(
                      context,
                      action: 'Create SKU?',
                      details:
                          'This will upload the thumbnail and create a new SKU for the this business.',
                    );
                    if (!confirmed || !context.mounted || !sheetContext.mounted) return;

                    setSheetState(() => saving = true);
                    String photoStorageKey;
                    try {
                      photoStorageKey = await api.uploadStockSkuThumbnail(
                        skuPhotoLocalPath!,
                      );
                    } on EastAppApiException {
                      if (sheetContext.mounted) {
                        setSheetState(() => saving = false);
                      }
                      return;
                    }
                    if (!context.mounted || !sheetContext.mounted) return;

                    final sku = StockSku(
                      id: 'SKU${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      tag1Id: tag1.id,
                      category: tag1.tag,
                      tag2Id: tag2.id,
                      location: tag2.tag,
                      receivingChecklist: receivingChecklistControllers
                          .map((controller) => controller.text.trim())
                          .where((value) => value.isNotEmpty)
                          .take(5)
                          .toList(),
                      unit: unit,
                      minimumBalanceValue: min,
                      maximumBalanceValue: max,
                      currentBalanceValue: min,
                      recoveryPercent: recoveryPercent,
                      minimumPriceRm: minPrice,
                      maximumPriceRm: maxPrice,
                      supplierIds: selectedSupplierIds.toList(),
                      photoPath: photoStorageKey,
                      assignedStaffName: 'Unassigned',
                      resetTime: resetTime,
                      lastUpdatedAt: 'Not counted yet',
                      lastUpdatedBy: headId,
                      coolingPeriod: true,
                    );
                    final saved = await runStockRequest(
                      context,
                      () => onCreateSku(sku),
                    );
                    if (!saved || !context.mounted || !sheetContext.mounted) {
                      if (sheetContext.mounted) {
                        setSheetState(() => saving = false);
                      }
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    showSuccessSnackBar(context, text.t('SKU created'));
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String formatStockNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String formatStockResetTime(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay parseStockResetTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length == 2) {
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return TimeOfDay(hour: hour, minute: minute);
    }
  }
  return const TimeOfDay(hour: 8, minute: 0);
}

bool isValidStockResetTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return false;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

class _StockCameraPage extends StatefulWidget {
  final String title;
  final String subtitle;

  const _StockCameraPage({
    required this.title,
    required this.subtitle,
  });

  @override
  State<_StockCameraPage> createState() => _StockCameraPageState();
}

class _StockCameraPageState extends State<_StockCameraPage> {
  CameraController? controller;
  bool capturing = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    initialiseCamera();
  }

  Future<void> initialiseCamera() async {
    final oldController = controller;
    controller = null;
    await oldController?.dispose();
    if (mounted) {
      setState(() => errorMessage = null);
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final value = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await value.initialize();
      if (!mounted) {
        await value.dispose();
        return;
      }
      AppDiagnostics.instance.setCameraInfo(
        'Stock camera · title=${widget.title}, cameraCount=${cameras.length}, '
        'selected=${camera.name}, lens=${camera.lensDirection.name}, '
        'sensorOrientation=${camera.sensorOrientation}, preset=medium',
      );
      setState(() => controller = value);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> capturePhoto() async {
    final value = controller;
    if (value == null || !value.value.isInitialized || capturing) return;
    setState(() => capturing = true);
    try {
      final photo = await value.takePicture();
      AppDiagnostics.instance.log('Stock photo captured · title=${widget.title}, file=${photo.name}');
      if (!mounted) return;
      Navigator.of(context).pop(photo.path);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        capturing = false;
        errorMessage = error.toString();
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white70,
                              size: 54,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: initialiseCamera,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry Camera'),
                            ),
                          ],
                        ),
                      )
                    : value == null || !value.value.isInitialized
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final previewSize = value.value.previewSize;
                                  if (previewSize == null) {
                                    return CameraPreview(value);
                                  }
                                  return ClipRect(
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: SizedBox(
                                        width: previewSize.height,
                                        height: previewSize.width,
                                        child: CameraPreview(value),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                top: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    widget.subtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: AppTextSize.s14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SizedBox(
                width: 76,
                height: 76,
                child: FloatingActionButton(
                  heroTag: 'sku-thumbnail-capture',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  onPressed: value == null || !value.value.isInitialized || capturing
                      ? null
                      : capturePhoto,
                  child: capturing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
