part of 'stock_screen.dart';

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
  bool loadingStates = true;
  Map<String, StockPurchaseSupplierState> purchaseStates = const {};

  StockPurchaseGateway get gateway =>
      StockPurchaseGateway(_StockMediaScope.of(context).api);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(loadPurchaseStates()),
    );
  }

  Future<void> loadPurchaseStates() async {
    if (!mounted) return;
    setState(() => loadingStates = true);
    try {
      final values = await gateway.suppliers();
      if (!mounted) return;
      setState(() {
        purchaseStates = {
          for (final value in values) value.supplierId: value,
        };
        loadingStates = false;
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingStates = false);
    }
  }

  List<StockSku> get visibleSkus => widget.skus.where((sku) {
        if (!sku.active) return false;
        return !lowStockOnly ||
            sku.currentBalanceValue <= sku.minimumBalanceValue;
      }).toList(growable: false);

  List<({SupplierProfile supplier, List<StockSku> skus})> get supplierGroups {
    final result = <({SupplierProfile supplier, List<StockSku> skus})>[];
    for (final supplier in widget.suppliers) {
      final skus = visibleSkus
          .where((sku) => sku.supplierIds.contains(supplier.id))
          .toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (skus.isNotEmpty) result.add((supplier: supplier, skus: skus));
    }
    result.sort(
      (a, b) => a.supplier.supplierName
          .toLowerCase()
          .compareTo(b.supplier.supplierName.toLowerCase()),
    );
    return result;
  }

  double suggestedAmount(StockSku sku) {
    final shortage = sku.maximumBalanceValue - sku.currentBalanceValue;
    return shortage <= 0 ? 0 : shortage;
  }

  String itemLines(List<StockSku> skus) {
    return List.generate(
      skus.length,
      (index) {
        final sku = skus[index];
        return '${index + 1}. ${sku.name} — '
            '${formatStockNumber(suggestedAmount(sku))} ${sku.unit}';
      },
    ).join('\n');
  }

  String generatedMessage(String template, List<StockSku> skus) {
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final items = itemLines(skus);
    var result = template.trim();
    result = result.contains('{items}')
        ? result.replaceAll('{items}', items)
        : '$result\n\n$items';
    return result.replaceAll('{date}', date).trim();
  }

  String stateLabel(StockPurchaseSupplierState? state) {
    if (state == null || state.orderState == 'NONE') return 'Not ordered';
    if (state.orderState == 'ORDERED') return 'Ordered · Ready to receive';
    if (state.orderState == 'SUBMITTED') return 'Receiving · Awaiting review';
    if (state.orderState == 'CORRECTION_REQUIRED') {
      return 'Receiving · Needs correction';
    }
    return state.orderState;
  }

  Color stateColour(StockPurchaseSupplierState? state) {
    if (state == null || state.orderState == 'NONE') {
      return AppColours.textMuted;
    }
    if (state.orderState == 'ORDERED') return AppColours.green;
    if (state.orderState == 'SUBMITTED') return AppColours.blue;
    return AppColours.orange;
  }

  void showCopiedFeedback() {
    AppFeedback.select();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(AppTextScope.of(context).t('Message copied')),
            ],
          ),
        ),
      );
  }

  Future<void> openSupplierOrder(
    SupplierProfile supplier,
    List<StockSku> skus,
  ) async {
    final text = AppTextScope.of(context);
    final currentState = purchaseStates[supplier.id];
    final initialTemplate = currentState?.messageTemplate.trim().isNotEmpty == true
        ? currentState!.messageTemplate
        : 'Hi, please prepare the following items:\n\n{items}\n\n{date}\n'
            'Please confirm availability and delivery time. Thank u.';
    final templateController = TextEditingController(text: initialTemplate);
    final messageController = TextEditingController(
      text: generatedMessage(initialTemplate, skus),
    );
    var state = currentState;
    var editingTemplate = false;
    var savingTemplate = false;
    var markingOrdered = false;

    try {
      await showStockBottomSheet<void>(
        context,
        maxHeightFactor: 0.94,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final activeOrder = state?.hasActiveOrder == true;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    stockBottomSheetHandle(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.content(supplier.supplierName),
                                style: const TextStyle(
                                  fontSize: AppTextSize.s24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${skus.length} ${text.t('SKU')} · '
                                '${stateLabel(state)}',
                                style: TextStyle(
                                  color: stateColour(state),
                                  fontWeight: FontWeight.w800,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                        ),
                        onPressed: () => setSheetState(
                          () => editingTemplate = !editingTemplate,
                        ),
                        icon: Icon(
                          editingTemplate
                              ? Icons.expand_less_rounded
                              : Icons.edit_outlined,
                          size: 15,
                        ),
                        label: Text(
                          text.t(editingTemplate
                              ? 'Hide template'
                              : 'Edit template'),
                          style: const TextStyle(
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (editingTemplate) ...[
                      const SizedBox(height: 5),
                      Text(
                        text.t('Message Template'),
                        style: AppTextStyles.formLabel,
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: templateController,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: 'Use {items} and {date} where needed.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: savingTemplate
                                  ? null
                                  : () async {
                                      final value =
                                          templateController.text.trim();
                                      if (value.isEmpty) {
                                        showWarningSnackBar(
                                          context,
                                          text.t(
                                            'Message template cannot be empty.',
                                          ),
                                        );
                                        return;
                                      }
                                      setSheetState(
                                        () => savingTemplate = true,
                                      );
                                      try {
                                        final saved = await gateway.saveTemplate(
                                          supplier.id,
                                          value,
                                        );
                                        if (!mounted) return;
                                        setState(() {
                                          purchaseStates = {
                                            ...purchaseStates,
                                            supplier.id: saved,
                                          };
                                        });
                                        setSheetState(() => state = saved);
                                        showSuccessSnackBar(
                                          context,
                                          text.t('Supplier template saved'),
                                        );
                                      } on EastAppApiException {
                                        // Global API error UI handles this.
                                      } finally {
                                        if (sheetContext.mounted) {
                                          setSheetState(
                                            () => savingTemplate = false,
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.save_outlined),
                              label: Text(text.t('Save Template')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                messageController.text = generatedMessage(
                                  templateController.text,
                                  skus,
                                );
                              },
                              icon: const Icon(Icons.auto_fix_high_rounded),
                              label: Text(text.t('Apply Template')),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      text.t('Order Message'),
                      style: AppTextStyles.formLabel,
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: messageController,
                      minLines: 8,
                      maxLines: 16,
                      decoration: InputDecoration(
                        helperText: text.t(
                          'This final message can still be edited before copying.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: activeOrder
                          ? text.t('Order Already Marked Done')
                          : text.t('Ordered Done'),
                      icon: activeOrder
                          ? Icons.check_circle_rounded
                          : Icons.task_alt_rounded,
                      onPressed: activeOrder || markingOrdered
                          ? null
                          : () async {
                              final message = messageController.text.trim();
                              if (message.isEmpty) {
                                showWarningSnackBar(
                                  context,
                                  text.t('Order message cannot be empty.'),
                                );
                                return;
                              }
                              final confirmed = await confirmDataChange(
                                context,
                                action: text.t('Confirm Ordered Done?'),
                                details: text.t(
                                  'This will enable this supplier in Receiving. '
                                  'Only confirm after the order has actually been placed.',
                                ),
                              );
                              if (!confirmed || !sheetContext.mounted) return;
                              setSheetState(() => markingOrdered = true);
                              try {
                                final saved = await gateway.markOrdered(
                                  supplier.id,
                                  message,
                                );
                                if (!mounted) return;
                                setState(() {
                                  purchaseStates = {
                                    ...purchaseStates,
                                    supplier.id: saved,
                                  };
                                });
                                setSheetState(() => state = saved);
                                showSuccessSnackBar(
                                  context,
                                  text.t(
                                    'Order marked done. Receiving is now enabled.',
                                  ),
                                );
                              } on EastAppApiException {
                                // Global API error UI handles this.
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => markingOrdered = false);
                                }
                              }
                            },
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: messageController.text),
                          );
                          if (!mounted) return;
                          showCopiedFeedback();
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(text.t('Copy Message')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text.t(
                        'Copy Message never changes the order status and can be used multiple times.',
                      ),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontSize: AppTextSize.s12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      templateController.dispose();
      messageController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final groups = supplierGroups;
    return _PageScaffold(
      title: text.t('Purchase'),
      subtitle: text.t(
        'Prepare supplier messages, then confirm only when the order is actually placed.',
      ),
      onBack: widget.onBack,
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
                      text.t('Supplier Orders'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text.t('Copying a message does not mark an order as done.'),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loadingStates ? null : loadPurchaseStates,
                icon: loadingStates
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        WhiteCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: lowStockOnly,
              title: Text(
                text.t('Low Stock Only'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle:
                  Text(text.t('Show only SKUs at or below minimum balance.')),
              onChanged: (value) =>
                  setState(() => lowStockOnly = value ?? true),
            ),
          ),
        ),
        if (groups.isEmpty)
          WhiteCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  text.t(
                    lowStockOnly
                        ? 'No low-stock supplier orders to prepare.'
                        : 'No supplier SKUs available.',
                  ),
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
        else
          for (final group in groups) ...[
            _PurchaseSupplierCard(
              supplier: group.supplier,
              skuCount: group.skus.length,
              stateLabel: stateLabel(purchaseStates[group.supplier.id]),
              stateColour: stateColour(purchaseStates[group.supplier.id]),
              onTap: () => openSupplierOrder(group.supplier, group.skus),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PurchaseSupplierCard extends StatelessWidget {
  final SupplierProfile supplier;
  final int skuCount;
  final String stateLabel;
  final Color stateColour;
  final VoidCallback onTap;

  const _PurchaseSupplierCard({
    required this.supplier,
    required this.skuCount,
    required this.stateLabel,
    required this.stateColour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColours.blue,
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
                    const SizedBox(height: 4),
                    Text(
                      '$skuCount ${text.t('SKU')} · $stateLabel',
                      style: TextStyle(
                        color: stateColour,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColours.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
