part of 'stock_screen.dart';

class _SupplierSetupPage extends StatefulWidget {
  final EastAppApi api;
  final bool isOwner;
  final Future<void> Function() onReloadAfterImport;
  final List<SupplierProfile> suppliers;
  final VoidCallback onBack;
  final Future<void> Function(SupplierProfile supplier) onCreateSupplier;
  final Future<void> Function(SupplierProfile supplier) onUpdateSupplier;
  final Future<bool> Function(Set<String> supplierIds) onDeleteSuppliers;

  const _SupplierSetupPage({
    required this.api,
    required this.isOwner,
    required this.onReloadAfterImport,
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
  final searchController = TextEditingController();
  final Set<String> selectedIds = <String>{};
  bool exportingSuppliers = false;

  Future<void> exportSuppliers() async {
    if (exportingSuppliers) return;
    setState(() => exportingSuppliers = true);
    try {
      final csv = await widget.api.exportStockSuppliersCsv();
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          title: AppTextScope.of(context).t('Share Supplier Export'),
          files: [XFile.fromData(csv.bytes, mimeType: 'text/csv')],
          fileNameOverrides: [csv.fileName],
          sharePositionOrigin: renderBox == null || !renderBox.hasSize
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
          downloadFallbackEnabled: true,
        ),
      );
    } on EastAppApiException {
      // Global API error handling already presents the failure.
    } finally {
      if (mounted) setState(() => exportingSuppliers = false);
    }
  }

  Future<void> importSuppliers() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) showErrorSnackBar(context, 'The Supplier CSV must not exceed 2 MB.');
        return;
      }
      final preview = await widget.api.previewStockSupplierCsv(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final text = AppTextScope.of(dialogContext);
          return AlertDialog(
            title: Text(text.t(preview.invalidRows == 0
                ? 'Import Suppliers?'
                : 'CSV cannot be submitted')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkuCsvPreviewRow(label: text.t('Total rows'), value: preview.totalRows),
                _SkuCsvPreviewRow(label: text.t('Ready to submit'), value: preview.readyRows, colour: AppColours.green),
                _SkuCsvPreviewRow(label: text.t('Existing duplicates skipped'), value: preview.duplicateRows),
                _SkuCsvPreviewRow(label: text.t('Invalid rows'), value: preview.invalidRows, colour: preview.invalidRows == 0 ? null : AppColours.red),
                if (preview.errors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...preview.errors.map((error) => Text(error, style: const TextStyle(color: AppColours.red))),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(text.t('Cancel'))),
              if (preview.canImport)
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(text.t('Import'))),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      await widget.api.importStockSupplierCsv(fileName: file.name, bytes: bytes);
      await widget.onReloadAfterImport();
      if (mounted) showSuccessSnackBar(context, 'Suppliers imported');
    } on EastAppApiException {
      // Global API error handling already presents the failure.
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
        ? widget.suppliers
        : widget.suppliers.where((supplier) => [
              supplier.supplierName,
              supplier.contactPerson,
              supplier.phone,
              supplier.address,
              supplier.address2,
              supplier.websiteOrGoogleLink,
              supplier.notes,
            ].join(' ').toLowerCase().contains(query));
    return _sortSuppliersAlphabetically(source);
  }

  void toggleSelected(String id) {
    setState(() => selectedIds.contains(id) ? selectedIds.remove(id) : selectedIds.add(id));
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
      // Global API error handling already presents the failure.
    }
  }

  void showSupplierDetail(SupplierProfile supplier) {
    final text = AppTextScope.of(context);
    final name = TextEditingController(text: supplier.supplierName);
    final contact = TextEditingController(text: supplier.contactPerson);
    final phone = TextEditingController(text: supplier.phone);
    final address = TextEditingController(text: supplier.address);
    final address2 = TextEditingController(text: supplier.address2);
    final websiteOrGoogleLink = TextEditingController(text: supplier.websiteOrGoogleLink);
    final notes = TextEditingController(text: supplier.notes);
    var editing = false;

    SupplierProfile updatedSupplier() => SupplierProfile(
      id: supplier.id,
      supplierName: name.text.trim().isEmpty ? supplier.supplierName : name.text.trim(),
      supplierItem: supplier.supplierItem,
      contactPerson: contact.text.trim(),
      phone: phone.text.trim(),
      address: address.text.trim(),
      address2: address2.text.trim(),
      websiteOrGoogleLink: websiteOrGoogleLink.text.trim(),
      notes: notes.text.trim(),
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

    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.86,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final title = name.text.trim().isEmpty ? supplier.supplierName : name.text.trim();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              stockBottomSheetHandle(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 8),
              _SetupDetailRow(label: text.t('Supplier Name'), value: supplier.supplierName, controller: name, isEditing: editing),
              _SetupDetailRow(label: text.t('Contact Person'), value: supplier.contactPerson, controller: contact, isEditing: editing),
              _SetupDetailRow(label: text.t('Phone'), value: supplier.phone, controller: phone, isEditing: editing, keyboardType: TextInputType.phone),
              _SetupDetailRow(label: text.t('Address 1'), value: supplier.address, controller: address, isEditing: editing),
              _SetupDetailRow(label: text.t('Address 2'), value: supplier.address2, controller: address2, isEditing: editing),
              _SetupDetailRow(label: text.t('Website or Google link'), value: supplier.websiteOrGoogleLink, controller: websiteOrGoogleLink, isEditing: editing, keyboardType: TextInputType.url),
              _SetupDetailRow(label: text.t('Notes'), value: supplier.notes, controller: notes, isEditing: editing),
              _SetupDetailRow(label: text.t('Created By'), value: supplier.lastBalanceUpdatedBy),
              _SetupDetailRow(label: text.t('Created Date'), value: '12 Mar 2024'),
              _SetupDetailRow(label: text.t('Last Updated'), value: supplier.lastBalanceUpdatedAt),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!editing) {
                      setSheetState(() => editing = true);
                      return;
                    }
                    final confirmed = await confirmDataChange(context, action: 'Update Supplier?', details: 'This will save the edited supplier information.');
                    if (!confirmed || !context.mounted) return;
                    final saved = await runStockRequest(context, () => widget.onUpdateSupplier(updatedSupplier()));
                    if (!saved || !context.mounted || !sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    showSuccessSnackBar(context, text.t('Saved'));
                  },
                  icon: Icon(editing ? Icons.save_outlined : Icons.edit_outlined),
                  label: Text(text.t(editing ? 'Save' : 'Edit')),
                )),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: editing ? AppColours.textMuted : AppColours.red),
                  onPressed: () async {
                    if (editing) {
                      setSheetState(() => editing = false);
                      return;
                    }
                    final confirmed = await confirmDataChange(context, action: 'Delete Supplier?', details: 'This will permanently delete this unassigned supplier.');
                    if (!confirmed || !context.mounted) return;
                    final deleted = await widget.onDeleteSuppliers({supplier.id});
                    if (!context.mounted || !sheetContext.mounted) return;
                    if (!deleted) {
                      showErrorSnackBar(context, 'Assigned suppliers cannot be deleted');
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    showSuccessSnackBar(context, text.t('Deleted'));
                  },
                  icon: Icon(editing ? Icons.close_rounded : Icons.delete_outline),
                  label: Text(text.t(editing ? 'Cancel' : 'Delete')),
                )),
              ]),
            ]),
          );
        },
      ),
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
      trailing: selecting
            ? ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColours.red, foregroundColor: Colors.white), onPressed: deleteSelected, icon: const Icon(Icons.delete_outline), label: Text(text.t('Delete')))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(text: text.t('Add Supplier'), icon: Icons.add_business_outlined, onPressed: () => showAddSupplierDialog(context, onCreateSupplier: widget.onCreateSupplier)),
                  if (widget.isOwner)
                    PopupMenuButton<String>(
                      enabled: !exportingSuppliers,
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) {
                        if (value == 'import') unawaited(importSuppliers());
                        if (value == 'export') unawaited(exportSuppliers());
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'import', child: Text(text.t('Import Suppliers'))),
                        PopupMenuItem(value: 'export', child: Text(text.t('Export Suppliers'))),
                      ],
                    ),
                ],
              ),
      children: [
        TextField(controller: searchController, style: AppTextStyles.formValue, onChanged: (_) => setState(() {}), decoration: _inputDecoration(text.t('Search')).copyWith(prefixIcon: const Icon(Icons.search_rounded))),
        const SizedBox(height: 12),
        if (items.isEmpty)
          WhiteCard(child: Text(text.t('No supplier found'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)))
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
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
            ]),
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

  const _CompactSupplierRow({required this.supplier, required this.selected, required this.selecting, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final meta = [if (supplier.contactPerson.isNotEmpty) supplier.contactPerson, if (supplier.phone.isNotEmpty) supplier.phone, if (supplier.address.isNotEmpty) supplier.address].join(' · ');
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 180), width: 38, height: 38, decoration: BoxDecoration(color: selected ? AppColours.blue : const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(12)), child: Icon(selected ? Icons.check_rounded : Icons.local_shipping_outlined, color: selected ? Colors.white : AppColours.blue, size: 21)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(supplier.supplierName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w700)),
              if (meta.isNotEmpty) ...[const SizedBox(height: 2), Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w700))],
            ])),
            if (selecting) Checkbox(value: selected, onChanged: (_) => onTap()) else const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
          ]),
        ),
      ),
    );
  }
}
