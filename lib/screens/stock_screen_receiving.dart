part of 'stock_screen.dart';

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColours.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text.t('Bulk submission is risky. Check every record. This action cannot be undone.'),
                        style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.orange, fontWeight: FontWeight.w800, height: 1.25),
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
                AppTextScope.of(context).content(sku.name),
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
            text.t('$selectedCount selected'),
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
    final textScope = context.getInheritedWidgetOfExactType<AppTextScope>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget sheet = _StockMediaScope(
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
                                            text.content(sku.name),
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
                                      Text(
                                        text.t('No checklist set.'),
                                        style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w700),
                                      )
                                    else
                                      ...sku.receivingChecklist.asMap().entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 5),
                                          child: Text(
                                            '${entry.key + 1}. ${text.content(entry.value)}',
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
        if (textScope != null) {
          sheet = AppTextScope(
            language: textScope.language,
            contentTranslations: textScope.contentTranslations,
            child: sheet,
          );
        }
        return sheet;
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
    final text = AppTextScope.of(context);
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
                            if (!submitted && savedSkuCount > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                text.t('$savedSkuCount SKU received'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s12,
                                  color: AppColours.green,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ] else if (submitted && savedSkuCount > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                text.t('$savedSkuCount SKU saved'),
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
                    AppTextScope.of(context).content(sku.name),
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
