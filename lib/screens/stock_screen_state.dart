part of 'stock_screen.dart';

class _StockScreenState extends State<StockScreen> {
  static const _directLoadPages = <StockPage>{
    StockPage.dailyCount,
    StockPage.receiving,
    StockPage.restockMessage,
    StockPage.supplierSetup,
  };

  final Map<String, Future<Uint8List>> _thumbnailCache = {};
  final Map<String, Future<Uint8List>> _receivingPhotoCache = {};
  final Map<StockPage, DateTime> _loadedAt = <StockPage, DateTime>{};
  StockPage page = StockPage.home;
  StockPage? dataLoadingPage;
  bool pageLoading = false;
  bool loadingMore = false;
  int stockPageSlideDirection = 1;
  double stockSwipeStartX = 0;
  double stockSwipeDeltaX = 0;
  bool returnToMainHomeOnBack = false;

  void resetCountTimers(List<String> skuIds) {
    // SKU reset is based on each SKU's daily reset time, not a countdown timer.
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
    if (widget.currentTenantId != oldWidget.currentTenantId) {
      _loadedAt.clear();
      dataLoadingPage = null;
    }
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
  bool get canApproveStock => widget.isOwner || isHead;
  bool get canAccessAuditTrail => widget.isOwner || isHead;

  StockPurchaseGateway get purchaseGateway => StockPurchaseGateway(
        widget.api,
        tenantId: widget.currentTenantId,
      );

  Future<void> invalidatePurchaseStateCache() async {
    try {
      await purchaseGateway.invalidateCache();
    } on Object {
      // Cache maintenance must never turn a successful stock mutation into an error.
    }
  }

  Future<void> submitReceiving(StockReceivingRecord record) async {
    await widget.onSubmitReceiving(record);
    await invalidatePurchaseStateCache();
  }

  Future<void> reviewReceiving(StockReceivingRecord record) async {
    await widget.onReviewReceiving(record);
    await invalidatePurchaseStateCache();
  }

  StockPage _dataPageFor(StockPage value) {
    // Keep the former Review deep-link compatible while the visible Review page
    // is removed. Home review links now land in Count, where approval lives.
    return value == StockPage.review ? StockPage.dailyCount : value;
  }

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

    final dataPage = _dataPageFor(nextPage);
    if (_directLoadPages.contains(dataPage)) {
      setState(() {
        stockPageSlideDirection = 1;
        page = nextPage;
      });
      unawaited(_loadData(dataPage));
      return;
    }

    setState(() => pageLoading = true);
    final error = await widget.onLoadPageData(dataPage, false);
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
    switch (_dataPageFor(page)) {
      case StockPage.dailyCount:
        return widget.canLoadMoreSkus || widget.canLoadMoreCounts;
      case StockPage.receiving:
      case StockPage.restockMessage:
        return widget.canLoadMoreSuppliers || widget.canLoadMoreSkus;
      case StockPage.skuSetup:
        return widget.canLoadMoreTags ||
            widget.canLoadMoreSuppliers ||
            widget.canLoadMoreSkus;
      case StockPage.supplierSetup:
        return widget.canLoadMoreSuppliers;
      case StockPage.tagSetup:
        return widget.canLoadMoreTags;
      case StockPage.assigneeSetup:
      case StockPage.auditTrail:
      case StockPage.home:
      case StockPage.review:
        return false;
    }
  }

  Future<void> loadMoreCurrentPage() async {
    if (loadingMore || !canLoadMoreCurrentPage) return;
    setState(() => loadingMore = true);
    try {
      switch (_dataPageFor(page)) {
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
        case StockPage.supplierSetup:
          await widget.onLoadMoreSuppliers();
          break;
        case StockPage.tagSetup:
          await widget.onLoadMoreTags();
          break;
        case StockPage.assigneeSetup:
        case StockPage.auditTrail:
        case StockPage.home:
        case StockPage.review:
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
    if (page != StockPage.home) goHome();
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
    final isRightSwipe = stockSwipeDeltaX > 72 ||
        details.primaryVelocity != null && details.primaryVelocity! > 380;
    final isLeftEdgeSwipe = stockSwipeStartX <= 48 &&
        (stockSwipeDeltaX > 32 ||
            details.primaryVelocity != null && details.primaryVelocity! > 180);
    if (isRightSwipe || isLeftEdgeSwipe) goHome(fromSwipe: true);
  }

  Future<void> _loadData(
    StockPage target, {
    bool forceRefresh = false,
  }) async {
    if (dataLoadingPage != null) return;
    setState(() => dataLoadingPage = target);
    final error = await widget.onLoadPageData(target, forceRefresh);
    if (!mounted) return;
    setState(() {
      dataLoadingPage = null;
      if (error == null) _loadedAt[target] = DateTime.now();
    });
  }

  Widget _dataPage({
    required StockPage target,
    required Widget child,
  }) {
    return _DataRefreshShell(
      updatedAt: _loadedAt[target],
      onRefresh: () => _loadData(target, forceRefresh: true),
      child: child,
    );
  }

  Widget _withApproval({
    required _StockApprovalKind kind,
    required Widget child,
  }) {
    if (!canApproveStock) return child;
    return _StockApprovalScope(
      section: _StockApprovalLauncher(
        kind: kind,
        api: widget.api,
        onReviewReceiving: reviewReceiving,
        onReviewStockCount: widget.onReviewStockCount,
        onBulkReviewStockCounts: widget.onBulkReviewStockCounts,
      ),
      child: child,
    );
  }

  Widget _countPage() {
    return _dataPage(
      target: StockPage.dailyCount,
      child: _withApproval(
        kind: _StockApprovalKind.count,
        child: _DailyStockCountPage(
          role: widget.role,
          skus: widget.stockSkus,
          submissions: widget.submissions,
          onBack: goHome,
          onSubmitStockCheck: widget.onSubmitStockCheck,
          onUpdateSkuBalance: widget.onUpdateSkuBalance,
          onResetCountTimers: resetCountTimers,
        ),
      ),
    );
  }

  Widget buildCurrentPage() {
    switch (page) {
      case StockPage.dailyCount:
      case StockPage.review:
        return _countPage();
      case StockPage.receiving:
        return _dataPage(
          target: StockPage.receiving,
          child: _withApproval(
            kind: _StockApprovalKind.receiving,
            child: _StockReceivingPage(
              tenantId: widget.currentTenantId,
              role: widget.role,
              suppliers: widget.suppliers,
              skus: widget.stockSkus,
              onBack: goHome,
              onSubmitReceiving: submitReceiving,
              onUpdateSkuBalance: widget.onUpdateSkuBalance,
            ),
          ),
        );
      case StockPage.restockMessage:
        return _dataPage(
          target: StockPage.restockMessage,
          child: _RestockMessagePage(
            tenantId: widget.currentTenantId,
            suppliers: widget.suppliers,
            skus: widget.stockSkus,
            onBack: goHome,
          ),
        );
      case StockPage.skuSetup:
        return _DataRefreshShell(
          updatedAt: widget.skusLastUpdatedAt,
          onRefresh: () => _loadData(StockPage.skuSetup, forceRefresh: true),
          child: _SkuSetupPage(
            api: widget.api,
            isOwner: widget.isOwner,
            onReloadAfterSkuImport: widget.onReloadAfterSkuImport,
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
        return _dataPage(
          target: StockPage.supplierSetup,
          child: _SupplierSetupPage(
            suppliers: widget.suppliers,
            onBack: goHome,
            onCreateSupplier: widget.onCreateSupplier,
            onUpdateSupplier: widget.onUpdateSupplier,
            onDeleteSuppliers: widget.onDeleteSuppliers,
          ),
        );
      case StockPage.tagSetup:
        return _DataRefreshShell(
          updatedAt: widget.tagsLastUpdatedAt,
          onRefresh: () => _loadData(StockPage.tagSetup, forceRefresh: true),
          child: _TagSetupPage(
            api: widget.api,
            currentTenantId: widget.currentTenantId,
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
          currentTenantId: widget.currentTenantId,
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
    if (pageLoading) return const Center(child: CircularProgressIndicator());
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
