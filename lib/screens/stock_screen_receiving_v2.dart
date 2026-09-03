part of 'stock_screen.dart';

class _ReceivingDraftV2 {
  final StockSku sku;
  final StockReceivingItem item;

  const _ReceivingDraftV2({required this.sku, required this.item});
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

class _StockReceivingPageState extends State<_StockReceivingPage> {
  final TextEditingController supplierSearchController = TextEditingController();
  final TextEditingController skuSearchController = TextEditingController();
  Map<String, StockPurchaseSupplierState> purchaseStates = const {};
  bool loadingStates = true;
  SupplierProfile? selectedSupplier;
  final Map<String, _ReceivingDraftV2> drafts = {};
  String invoicePhotoName = '';
  String goodsPhotoName = '';

  String get receivedBy {
    if (widget.role == UserRole.head) return headId;
    if (widget.role == UserRole.manager) return managerId;
    return staffId;
  }

  StockPurchaseGateway get gateway =>
      StockPurchaseGateway(_StockMediaScope.of(context).api);

  @override
  void initState() {
    super.initState();
    supplierSearchController.addListener(_refresh);
    skuSearchController.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(loadPurchaseStates()));
  }

  @override
  void dispose() {
    supplierSearchController.dispose();
    skuSearchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> loadPurchaseStates() async {
    if (!mounted) return;
    setState(() => loadingStates = true);
    try {
      final values = await gateway.suppliers();
      if (!mounted) return;
      setState(() {
        purchaseStates = {for (final value in values) value.supplierId: value};
        loadingStates = false;
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingStates = false);
    }
  }

  List<SupplierProfile> get filteredSuppliers {
    final query = supplierSearchController.text.trim().toLowerCase();
    final values = widget.suppliers.where((supplier) {
      if (query.isEmpty) return true;
      return supplier.supplierName.toLowerCase().contains(query) ||
          supplier.contactPerson.toLowerCase().contains(query) ||
          supplier.phone.toLowerCase().contains(query);
    }).toList(growable: false);
    values.sort((a, b) => a.supplierName
        .toLowerCase()
        .compareTo(b.supplierName.toLowerCase()));
    return values;
  }

  List<StockSku> skusForSupplier(SupplierProfile supplier) {
    final query = skuSearchController.text.trim().toLowerCase();
    final values = widget.skus.where((sku) {
      if (!sku.active || !sku.supplierIds.contains(supplier.id)) return false;
      if (query.isEmpty) return true;
      return sku.name.toLowerCase().contains(query) ||
          sku.unit.toLowerCase().contains(query);
    }).toList(growable: false);
    values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  String supplierStatus(StockPurchaseSupplierState? state) {
    if (state == null || state.orderState == 'NONE') return 'Order not marked done';
    if (state.orderState == 'ORDERED') return 'Ready to receive';
    if (state.orderState == 'SUBMITTED') return 'Awaiting review';
    if (state.orderState == 'CORRECTION_REQUIRED') return 'Needs correction';
    return state.orderState;
  }

  Color supplierStatusColour(StockPurchaseSupplierState? state) {
    if (state?.orderState == 'ORDERED') return AppColours.green;
    if (state?.orderState == 'SUBMITTED') return AppColours.blue;
    if (state?.orderState == 'CORRECTION_REQUIRED') return AppColours.orange;
    return AppColours.textMuted;
  }

  void selectSupplier(SupplierProfile supplier) {
    final state = purchaseStates[supplier.id];
    if (state?.receivingEnabled != true) {
      AppFeedback.warning();
      return;
    }
    AppFeedback.select();
    setState(() {
      selectedSupplier = supplier;
      drafts.clear();
      invoicePhotoName = '';
      goodsPhotoName = '';
      skuSearchController.clear();
    });
  }

  void backToSuppliers() {
    setState(() {
      selectedSupplier = null;
      drafts.clear();
      invoicePhotoName = '';
      goodsPhotoName = '';
      skuSearchController.clear();
    });
    unawaited(loadPurchaseStates());
  }

  Future<void> captureInvoicePhoto() async {
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
          setState(() => invoicePhotoName = storageKey);
          showSuccessSnackBar(context, text.t('Invoice photo captured'));
        },
      );
    } on EastAppApiException {
      // Global API error UI already handles this.
    }
  }

  Future<void> captureGoodsPhoto() async {
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
          setState(() => goodsPhotoName = storageKey);
          showSuccessSnackBar(context, text.t('Goods received photo captured'));
        },
      );
    } on EastAppApiException {
      // Global API error UI already handles this.
    }
  }

  Future<void> editSku(StockSku sku) async {
    final text = AppTextScope.of(context);
    final existing = drafts[sku.id];
    final invoiceController = TextEditingController(
      text: existing == null
          ? ''
          : formatStockNumber(existing.item.invoiceQuantity),
    );
    final receivedController = TextEditingController(
      text: existing == null
          ? ''
          : formatStockNumber(existing.item.receivedQuantity),
    );
    final noteController = TextEditingController(
      text: existing?.item.note == 'No remark provided.' ? '' : existing?.item.note ?? '',
    );
    final checklist = sku.receivingChecklist;
    final checked = List<bool>.filled(checklist.length, existing != null);

    try {
      await showStockBottomSheet<void>(
        context,
        maxHeightFactor: 0.9,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final complete = checked.every((value) => value);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    stockBottomSheetHandle(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text.content(sku.name),
                            style: const TextStyle(
                              fontSize: AppTextSize.s22,
                              fontWeight: FontWeight.w900,
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
                    TextField(
                      controller: invoiceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: text.t('Invoice Quantity'),
                        suffixText: sku.unit,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: receivedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: text.t('Received Quantity'),
                        suffixText: sku.unit,
                      ),
                    ),
                    if (checklist.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(text.t('Receiving Checklist'), style: AppTextStyles.formLabel),
                      const SizedBox(height: 4),
                      for (var i = 0; i < checklist.length; i++)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: checked[i],
                          title: Text(text.content(checklist[i])),
                          onChanged: (value) =>
                              setSheetState(() => checked[i] = value ?? false),
                        ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: text.t('Note (optional)')),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: text.t(existing == null ? 'Add SKU' : 'Update SKU'),
                      icon: Icons.check_rounded,
                      onPressed: complete
                          ? () {
                              final invoice = double.tryParse(invoiceController.text.trim());
                              final received = double.tryParse(receivedController.text.trim());
                              if (invoice == null || received == null || invoice < 0 || received < 0) {
                                AppFeedback.warning();
                                return;
                              }
                              setState(() {
                                drafts[sku.id] = _ReceivingDraftV2(
                                  sku: sku,
                                  item: StockReceivingItem(
                                    skuId: sku.id,
                                    skuName: sku.name,
                                    invoiceQuantity: invoice,
                                    receivedQuantity: received,
                                    unit: sku.unit,
                                    condition: checklist.isEmpty ? 'Checked' : 'Checked',
                                    note: noteController.text.trim().isEmpty
                                        ? 'No remark provided.'
                                        : noteController.text.trim(),
                                  ),
                                );
                              });
                              Navigator.of(sheetContext).pop();
                              AppFeedback.select();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      invoiceController.dispose();
      receivedController.dispose();
      noteController.dispose();
    }
  }

  Future<void> submitReceiving() async {
    final supplier = selectedSupplier;
    if (supplier == null) return;
    final text = AppTextScope.of(context);
    if (invoicePhotoName.isEmpty || goodsPhotoName.isEmpty || drafts.isEmpty) {
      AppFeedback.warning();
      showWarningSnackBar(
        context,
        text.t('Capture both photos and select at least one SKU.'),
      );
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: text.t('Submit Receiving?'),
      details: text.t(
        'The selected SKU list will be treated as the complete delivery and sent for review.',
      ),
    );
    if (!confirmed || !mounted) return;

    final now = DateTime.now();
    final record = StockReceivingRecord(
      id: 'REC${now.microsecondsSinceEpoch}',
      supplierId: supplier.id,
      supplierName: supplier.supplierName,
      receivedBy: receivedBy,
      receivedAt: 'Submitted just now',
      capturedAt: now,
      invoicePhotoName: invoicePhotoName,
      goodsPhotoName: goodsPhotoName,
      items: drafts.values.map((draft) => draft.item).toList(growable: false),
    );
    final ok = await runStockRequest(
      context,
      () => widget.onSubmitReceiving(record),
    );
    if (!ok || !mounted) return;
    showSuccessSnackBar(context, text.t('Receiving submitted for review'));
    backToSuppliers();
  }

  Widget buildSupplierList(AppText text) {
    final suppliers = filteredSuppliers;
    return _PageScaffold(
      title: text.t('Receiving'),
      subtitle: text.t('Choose the supplier delivering stock.'),
      onBack: widget.onBack,
      children: [
        WhiteCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.t('Orders awaiting delivery'),
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text.t('Suppliers become available after Purchase → Ordered Done.'),
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: supplierSearchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: text.t('Search supplier'),
                ),
              ),
            ],
          ),
        ),
        if (loadingStates)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (suppliers.isEmpty)
          WhiteCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text(text.t('No supplier found.'))),
            ),
          )
        else
          for (final supplier in suppliers) ...[
            _ReceivingSupplierCardV2(
              supplier: supplier,
              state: purchaseStates[supplier.id],
              statusLabel: supplierStatus(purchaseStates[supplier.id]),
              statusColour: supplierStatusColour(purchaseStates[supplier.id]),
              onTap: () => selectSupplier(supplier),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget buildSupplierReceiving(AppText text, SupplierProfile supplier) {
    final state = purchaseStates[supplier.id];
    final skus = skusForSupplier(supplier);
    return _PageScaffold(
      title: text.t('Receiving'),
      subtitle: text.content(supplier.supplierName),
      onBack: backToSuppliers,
      children: [
        WhiteCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.content(supplier.supplierName),
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supplierStatus(state),
                      style: TextStyle(
                        color: supplierStatusColour(state),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SmallStatusPill(
                text: '${drafts.length} selected',
                textColour: AppColours.blue,
                backgroundColour: AppColours.blueSoft,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ReceivingPhotoButtonV2(
                label: 'Goods Photo',
                done: goodsPhotoName.isNotEmpty,
                icon: Icons.inventory_2_outlined,
                onTap: captureGoodsPhoto,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReceivingPhotoButtonV2(
                label: 'Invoice Photo',
                done: invoicePhotoName.isNotEmpty,
                icon: Icons.receipt_long_outlined,
                onTap: captureInvoicePhoto,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: skuSearchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: text.t('Search SKU'),
          ),
        ),
        const SizedBox(height: 10),
        if (skus.isEmpty)
          WhiteCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(text.t('No SKU linked to this supplier.'))),
            ),
          )
        else
          for (final sku in skus) ...[
            _ReceivingSkuRowV2(
              sku: sku,
              selected: drafts.containsKey(sku.id),
              onTap: () => editSku(sku),
              onRemove: drafts.containsKey(sku.id)
                  ? () => setState(() => drafts.remove(sku.id))
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        PrimaryButton(
          text: '${text.t('Submit Receiving')} · ${drafts.length} ${text.t('SKU')}',
          icon: Icons.send_rounded,
          onPressed: drafts.isNotEmpty &&
                  invoicePhotoName.isNotEmpty &&
                  goodsPhotoName.isNotEmpty
              ? submitReceiving
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final supplier = selectedSupplier;
    return supplier == null
        ? buildSupplierList(text)
        : buildSupplierReceiving(text, supplier);
  }
}

class _ReceivingSupplierCardV2 extends StatelessWidget {
  final SupplierProfile supplier;
  final StockPurchaseSupplierState? state;
  final String statusLabel;
  final Color statusColour;
  final VoidCallback onTap;

  const _ReceivingSupplierCardV2({
    required this.supplier,
    required this.state,
    required this.statusLabel,
    required this.statusColour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final enabled = state?.receivingEnabled == true;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: WhiteCard(
        padding: EdgeInsets.zero,
        child: Pressable(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: enabled ? AppColours.blueSoft : AppColours.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: enabled ? AppColours.blue : AppColours.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.content(supplier.supplierName),
                        style: const TextStyle(
                          fontSize: AppTextSize.s16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (supplier.contactPerson.trim().isNotEmpty ||
                          supplier.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [supplier.contactPerson, supplier.phone]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColour,
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                  color: AppColours.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceivingPhotoButtonV2 extends StatelessWidget {
  final String label;
  final bool done;
  final IconData icon;
  final VoidCallback onTap;

  const _ReceivingPhotoButtonV2({
    required this.label,
    required this.done,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(done ? Icons.check_circle_rounded : icon,
                  color: done ? AppColours.green : AppColours.blue),
              const SizedBox(height: 6),
              Text(
                text.t(label),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                text.t(done ? 'Captured' : 'Tap to capture'),
                style: TextStyle(
                  color: done ? AppColours.green : AppColours.textMuted,
                  fontSize: AppTextSize.s11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceivingSkuRowV2 extends StatelessWidget {
  final StockSku sku;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _ReceivingSkuRowV2({
    required this.sku,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColours.blue : Colors.white,
                  border: Border.all(
                    color: selected ? AppColours.blue : AppColours.border,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.content(sku.name),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sku.unit,
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontSize: AppTextSize.s12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: text.t('Remove'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
