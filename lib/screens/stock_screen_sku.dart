part of 'stock_screen.dart';

class _SkuSetupPage extends StatefulWidget {
  final EastAppApi api;
  final bool isOwner;
  final Future<void> Function() onReloadAfterSkuImport;
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
    required this.onReloadAfterSkuImport,
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
  bool exportingSkus = false;

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

  Widget compactFilter({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final active = value != 'All';
    return PopupMenuButton<String>(
      initialValue: value,
      position: PopupMenuPosition.under,
      tooltip: '$label: $value',
      onSelected: onChanged,
      itemBuilder: (_) => options.map((option) {
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              Expanded(
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
              if (option == value)
                const Icon(Icons.check_rounded, size: 18, color: AppColours.blue),
            ],
          ),
        );
      }).toList(growable: false),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColours.blue.withValues(alpha: 0.08)
              : AppColours.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColours.blue : AppColours.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                active ? value : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColours.blue : AppColours.textMain,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 17,
              color: active ? AppColours.blue : AppColours.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> exportSkus() async {
    if (exportingSkus) return;
    AppFeedback.tap();
    setState(() => exportingSkus = true);
    try {
      final csv = await widget.api.exportStockSkusCsv();
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null || !renderBox.hasSize ? null : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: AppTextScope.of(context).t('Share SKU Export'),
          files: [XFile.fromData(csv.bytes, mimeType: 'text/csv')],
          fileNameOverrides: [csv.fileName],
          sharePositionOrigin: shareOrigin,
          downloadFallbackEnabled: true,
        ),
      );
      if (!mounted || result.status != ShareResultStatus.success) return;
      showSuccessSnackBar(context, 'Exported');
    } on EastAppApiException {
      // Global API error handling already presents the failure.
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Unable to share the SKU CSV file.');
    } finally {
      if (mounted) setState(() => exportingSkus = false);
    }
  }

  Future<void> importSkus() async {
    AppFeedback.tap();
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv']);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) showErrorSnackBar(context, 'The SKU CSV must not exceed 2 MB.');
        return;
      }
      final preview = await widget.api.previewStockSkuCsv(fileName: file.name, bytes: bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final text = AppTextScope.of(dialogContext);
          return AlertDialog(
            title: Text(text.t(preview.invalidRows == 0 ? 'Import SKUs?' : 'CSV cannot be imported')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${text.t('Recognised format')}: ${preview.format} v${preview.formatVersion}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _SkuCsvPreviewRow(label: text.t('Total rows'), value: preview.totalRows),
                    _SkuCsvPreviewRow(label: text.t('Ready to import'), value: preview.readyRows, colour: AppColours.green),
                    _SkuCsvPreviewRow(label: text.t('Existing duplicates skipped'), value: preview.duplicateRows),
                    _SkuCsvPreviewRow(label: text.t('New tags'), value: preview.newTagCount),
                    _SkuCsvPreviewRow(label: text.t('Invalid rows'), value: preview.invalidRows, colour: preview.invalidRows == 0 ? null : AppColours.red),
                    if (preview.unmatchedSupplierCount > 0) ...[
                      const SizedBox(height: 10),
                      Text(text.t('Unmatched suppliers will remain unlinked:'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(preview.unmatchedSupplierNames.join(', ')),
                    ],
                    if (preview.errors.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...preview.errors.map((error) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(error, style: const TextStyle(color: AppColours.red)))),
                    ],
                    const SizedBox(height: 12),
                    Text(text.t('Images, current balances and assignees are not imported.'), style: const TextStyle(color: AppColours.textMuted, fontSize: AppTextSize.s12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(text.t(preview.canImport ? 'Cancel' : 'Close'))),
              if (preview.canImport) FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(text.t('Import'))),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      await widget.api.importStockSkuCsv(fileName: file.name, bytes: bytes);
      if (!mounted) return;
      await widget.onReloadAfterSkuImport();
      if (mounted) showSuccessSnackBar(context, 'Imported');
    } on EastAppApiException {
      // Global API error handling already presents the failure.
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Unable to read the selected SKU CSV file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final skus = filteredSkus;
    final lowCount = widget.skus.where((sku) => sku.isBelowMinimumBalance).length;
    return _PageScaffold(
      title: text.t('SKU'),
      subtitle: text.t('Search, filter & edit SKUs.'),
      onBack: widget.onBack,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: text.t('Add SKU'),
            child: SizedBox(
              width: 52,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => showAddSkuDialog(
                  context,
                  tags: widget.tags,
                  suppliers: widget.suppliers,
                  onCreateSku: widget.onCreateSku,
                ),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
          ),
          if (widget.isOwner) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              enabled: !exportingSkus,
              tooltip: text.t('More SKU actions'),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'import') unawaited(importSkus());
                if (value == 'export') unawaited(exportSkus());
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(value: 'import', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.file_upload_outlined), title: Text(text.t('Import SKUs')))),
                PopupMenuItem<String>(value: 'export', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.ios_share_rounded), title: Text(text.t('Export SKUs')))),
              ],
            ),
          ],
        ],
      ),
      children: [
        Row(children: [
          Expanded(child: _MiniMetric(label: text.t('Total SKU'), value: '${widget.skus.length}', icon: Icons.inventory_2_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _MiniMetric(label: text.t('Low'), value: '$lowCount', icon: Icons.warning_amber_rounded, danger: lowCount > 0)),
          const SizedBox(width: 10),
          Expanded(child: _MiniMetric(label: text.t('Showing'), value: '${skus.length}', icon: Icons.filter_alt_outlined)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: searchController, style: AppTextStyles.formValue, onChanged: (_) => setState(() {}), decoration: _inputDecoration(text.t('Search')).copyWith(prefixIcon: const Icon(Icons.search_rounded))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: compactFilter(label: text.t('Status'), value: warningFilter, options: const ['All', 'Low', 'Normal'], onChanged: (value) => setState(() => warningFilter = value))),
          const SizedBox(width: 6),
          Expanded(child: compactFilter(label: text.t('Tag 1'), value: tag1Options.contains(tag1Filter) ? tag1Filter : 'All', options: tag1Options, onChanged: (value) => setState(() => tag1Filter = value))),
          const SizedBox(width: 6),
          Expanded(child: compactFilter(label: text.t('Assigned'), value: assignedStaff.contains(assignedFilter) ? assignedFilter : 'All', options: assignedStaff, onChanged: (value) => setState(() => assignedFilter = value))),
          const SizedBox(width: 6),
          Expanded(child: compactFilter(label: text.t('Tag 2'), value: tag2Options.contains(tag2Filter) ? tag2Filter : 'All', options: tag2Options, onChanged: (value) => setState(() => tag2Filter = value))),
        ]),
        const SizedBox(height: 14),
        if (skus.isEmpty)
          WhiteCard(child: Text(text.t('No SKU matches the selected filters.'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)))
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ...skus.map((sku) => _SkuCompactRow(
                sku: sku,
                onTap: () => showSkuDetailDialog(context, sku: sku, tags: widget.tags, suppliers: widget.suppliers, onUpdateSku: widget.onUpdateSku, onUpdateSkuBalance: widget.onUpdateSkuBalance),
              )),
            ]),
          ),
      ],
    );
  }
}
