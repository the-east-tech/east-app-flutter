part of 'stock_screen.dart';

class StockScreen extends StatefulWidget {
  final UserRole role;
  final EastAppApi api;
  final bool isOwner;
  final String currentTenantId;
  final StockReviewSummary? reviewSummary;
  final Future<void> Function() onReloadAfterSkuImport;
  final List<StockTask> stockTasks;
  final List<StockSubmission> submissions;
  final List<SupplierProfile> suppliers;
  final List<StockSku> stockSkus;
  final List<StockReceivableRecord> receivableRecords;
  final List<StockTag> tags;
  final DateTime? tagsLastUpdatedAt;
  final DateTime? suppliersLastUpdatedAt;
  final DateTime? skusLastUpdatedAt;
  final Future<String?> Function(StockPage page, bool forceRefresh) onLoadPageData;
  final Future<void> Function() onLoadMoreTags;
  final Future<void> Function() onLoadMoreSuppliers;
  final Future<void> Function() onLoadMoreSkus;
  final Future<void> Function() onLoadMoreCounts;
  final Future<void> Function() onLoadMoreReceivables;
  final bool canLoadMoreTags;
  final bool canLoadMoreSuppliers;
  final bool canLoadMoreSkus;
  final bool canLoadMoreCounts;
  final bool canLoadMoreReceivables;
  final Future<void> Function(StockSubmission submission) onSubmitStockCheck;
  final void Function(StockTask task) onCreateStockTask;
  final Future<void> Function(String supplierId, double balance, String updatedBy)
      onUpdateSupplierBalance;
  final Future<void> Function(SupplierProfile supplier) onCreateSupplier;
  final Future<void> Function(SupplierProfile supplier) onUpdateSupplier;
  final Future<bool> Function(Set<String> supplierIds) onDeleteSuppliers;
  final Future<void> Function(StockSku sku) onCreateSku;
  final Future<void> Function(StockSku sku) onUpdateSku;
  final Future<void> Function(String skuId) onDeleteSku;
  final Future<void> Function() onSkuChangeReviewed;
  final Future<void> Function(StockReceivableRecord record) onSubmitReceivable;
  final Future<void> Function(StockReceivableRecord record) onReviewReceivable;
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
    required this.reviewSummary,
    required this.onReloadAfterSkuImport,
    required this.stockTasks,
    required this.submissions,
    required this.suppliers,
    required this.stockSkus,
    required this.receivableRecords,
    required this.tags,
    required this.tagsLastUpdatedAt,
    required this.suppliersLastUpdatedAt,
    required this.skusLastUpdatedAt,
    required this.onLoadPageData,
    required this.onLoadMoreTags,
    required this.onLoadMoreSuppliers,
    required this.onLoadMoreSkus,
    required this.onLoadMoreCounts,
    required this.onLoadMoreReceivables,
    required this.canLoadMoreTags,
    required this.canLoadMoreSuppliers,
    required this.canLoadMoreSkus,
    required this.canLoadMoreCounts,
    required this.canLoadMoreReceivables,
    required this.onSubmitStockCheck,
    required this.onCreateStockTask,
    required this.onUpdateSupplierBalance,
    required this.onCreateSupplier,
    required this.onUpdateSupplier,
    required this.onDeleteSuppliers,
    required this.onCreateSku,
    required this.onUpdateSku,
    required this.onDeleteSku,
    required this.onSkuChangeReviewed,
    required this.onSubmitReceivable,
    required this.onReviewReceivable,
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
  receivable,
  restockMessage,
  review,
  skuSetup,
  supplierSetup,
  tagSetup,
  assigneeSetup,
}
