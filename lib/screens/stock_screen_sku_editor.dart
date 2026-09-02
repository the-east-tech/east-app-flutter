part of 'stock_screen.dart';

void showAddSkuDialog(
  BuildContext context, {
  required List<StockTag> tags,
  required List<SupplierProfile> suppliers,
  required Future<void> Function(StockSku sku) onCreateSku,
}) {
  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.94,
    builder: (sheetContext) => _SkuEditorForm(
      api: _StockMediaScope.of(context).api,
      tags: tags,
      suppliers: suppliers,
      onSave: onCreateSku,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class _SkuDetailContent extends StatelessWidget {
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
  Widget build(BuildContext context) => _SkuEditorForm(
    api: _StockMediaScope.of(context).api,
    tags: tags,
    suppliers: suppliers,
    initialSku: sku,
    onSave: onUpdateSku,
    onClose: onClose,
  );
}

class _SkuEditorForm extends StatefulWidget {
  final EastAppApi api;
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final StockSku? initialSku;
  final Future<void> Function(StockSku sku) onSave;
  final VoidCallback onClose;

  const _SkuEditorForm({
    required this.api,
    required this.tags,
    required this.suppliers,
    required this.onSave,
    required this.onClose,
    this.initialSku,
  });

  @override
  State<_SkuEditorForm> createState() => _SkuEditorFormState();
}

class _SkuEditorFormState extends State<_SkuEditorForm> {
  late final TextEditingController nameController;
  late final List<TextEditingController> checklistControllers;
  late final TextEditingController minBalanceController;
  late final TextEditingController currentBalanceController;
  late final TextEditingController maxBalanceController;
  late final TextEditingController minPriceController;
  late final TextEditingController maxPriceController;
  late String? tag1;
  late String? tag2;
  late String unit;
  late String resetTime;
  late int recoveryPercent;
  late Set<String> supplierIds;
  String? pendingPhotoPath;
  Uint8List? pendingPhotoBytes;
  bool saving = false;
  bool showErrors = false;

  bool get editing => widget.initialSku != null;

  List<String> get tagNames => widget.tags
      .map((tag) => tag.tag.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  @override
  void initState() {
    super.initState();
    final sku = widget.initialSku;
    nameController = TextEditingController(text: sku?.name ?? '');
    checklistControllers = List.generate(5, (index) => TextEditingController(text: sku != null && index < sku.receivingChecklist.length ? sku.receivingChecklist[index] : ''));
    minBalanceController = TextEditingController(text: sku == null ? '' : formatStockNumber(sku.minimumBalanceValue));
    currentBalanceController = TextEditingController(text: sku == null ? '' : formatStockNumber(sku.currentBalanceValue));
    maxBalanceController = TextEditingController(text: sku == null ? '' : formatStockNumber(sku.maximumBalanceValue));
    minPriceController = TextEditingController(text: sku == null ? '' : formatStockNumber(sku.minimumPriceRm));
    maxPriceController = TextEditingController(text: sku == null ? '' : formatStockNumber(sku.maximumPriceRm));
    tag1 = sku?.category;
    tag2 = sku?.location;
    unit = sku?.unit ?? 'kg';
    resetTime = sku?.resetTime ?? '08:00';
    recoveryPercent = sku?.recoveryPercent ?? 100;
    supplierIds = {...?sku?.supplierIds};
  }

  @override
  void dispose() {
    nameController.dispose();
    for (final controller in checklistControllers) controller.dispose();
    minBalanceController.dispose();
    currentBalanceController.dispose();
    maxBalanceController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  String? requiredText(TextEditingController controller, String message) => showErrors && controller.text.trim().isEmpty ? message : null;
  String? requiredNumber(TextEditingController controller, String message) => showErrors && double.tryParse(controller.text.trim()) == null ? message : null;

  Future<void> takePhoto() async {
    await showCameraOnlyCaptureDialog(
      context,
      title: AppTextScope.of(context).t('Stock Thumbnail'),
      subtitle: AppTextScope.of(context).t('Take a clear photo of the SKU.'),
      onCaptured: (path) async {
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        setState(() {
          pendingPhotoPath = path;
          pendingPhotoBytes = bytes;
        });
      },
    );
  }

  Future<void> pickResetTime() async {
    final picked = await showTimePicker(context: context, initialTime: parseStockResetTime(resetTime));
    if (picked != null && mounted) setState(() => resetTime = formatStockResetTime(picked));
  }

  Future<void> pickSuppliers() async {
    final result = await showStockBottomSheet<List<String>>(
      context,
      maxHeightFactor: 0.72,
      builder: (sheetContext) {
        final selected = supplierIds.toSet();
        return StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Column(children: [
                  stockBottomSheetHandle(),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text(AppTextScope.of(context).t('Suppliers'), style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
                  ]),
                ]),
              ),
              Flexible(child: ListView(shrinkWrap: true, children: widget.suppliers.map((supplier) => CheckboxListTile(
                value: selected.contains(supplier.id),
                title: Text(supplier.supplierName),
                onChanged: (value) => setSheetState(() => value == true ? selected.add(supplier.id) : selected.remove(supplier.id)),
              )).toList())),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Row(children: [
                  Expanded(child: PrimaryButton(text: AppTextScope.of(context).t('Cancel'), outlined: true, onPressed: () => Navigator.of(sheetContext).pop())),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton(text: AppTextScope.of(context).t('Save'), icon: Icons.save_outlined, onPressed: () => Navigator.of(sheetContext).pop(selected.toList()))),
                ]),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) setState(() => supplierIds = result.toSet());
  }

  Future<void> save() async {
    final text = AppTextScope.of(context);
    setState(() => showErrors = true);
    final name = nameController.text.trim();
    final minBalance = double.tryParse(minBalanceController.text.trim());
    final maxBalance = double.tryParse(maxBalanceController.text.trim());
    final currentBalance = editing
        ? double.tryParse(currentBalanceController.text.trim())
        : minBalance;
    final minPrice = double.tryParse(minPriceController.text.trim());
    final maxPrice = double.tryParse(maxPriceController.text.trim());
    final requiresPhoto = !editing && widget.initialSku?.photoPath.trim().isEmpty != false;

    if (name.isEmpty || tag1 == null || tag2 == null || unit.trim().isEmpty ||
        minBalance == null || maxBalance == null || currentBalance == null ||
        minPrice == null || maxPrice == null || !isValidStockResetTime(resetTime) ||
        supplierIds.isEmpty || (requiresPhoto && pendingPhotoPath == null)) {
      AppFeedback.warning();
      return;
    }
    if (minBalance < 0 || maxBalance <= 0 || maxBalance < minBalance || currentBalance < 0 || currentBalance > maxBalance) {
      showWarningSnackBar(context, text.t('Balance must be Min / Current / Max.'));
      return;
    }
    if (minPrice < 0 || maxPrice < minPrice) {
      showWarningSnackBar(context, text.t('Price must be Min / Max.'));
      return;
    }

    final selectedTag1 = widget.tags.firstWhere((item) => item.tag == tag1);
    final selectedTag2 = widget.tags.firstWhere((item) => item.tag == tag2);
    final confirmed = await confirmDataChange(
      context,
      action: editing ? 'Update SKU?' : 'Create SKU?',
      details: editing ? 'This will save the edited SKU details and stock settings.' : 'This will create a new SKU for this business.',
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      var photoPath = widget.initialSku?.photoPath ?? '';
      if (pendingPhotoPath != null) {
        photoPath = await widget.api.uploadStockSkuThumbnail(pendingPhotoPath!);
      }
      final checklist = checklistControllers.map((c) => c.text.trim()).where((value) => value.isNotEmpty).take(5).toList();
      final existing = widget.initialSku;
      final sku = existing == null
          ? StockSku(
              id: 'SKU${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              tag1Id: selectedTag1.id,
              category: selectedTag1.tag,
              tag2Id: selectedTag2.id,
              location: selectedTag2.tag,
              receivingChecklist: checklist,
              unit: unit,
              minimumBalanceValue: minBalance,
              maximumBalanceValue: maxBalance,
              currentBalanceValue: currentBalance,
              recoveryPercent: recoveryPercent,
              minimumPriceRm: minPrice,
              maximumPriceRm: maxPrice,
              supplierIds: supplierIds.toList(),
              photoPath: photoPath,
              assignedStaffName: 'Unassigned',
              resetTime: resetTime,
              lastUpdatedAt: 'Not counted yet',
              lastUpdatedBy: headId,
              coolingPeriod: true,
            )
          : existing.copyWith(
              name: name,
              tag1Id: selectedTag1.id,
              category: selectedTag1.tag,
              tag2Id: selectedTag2.id,
              location: selectedTag2.tag,
              receivingChecklist: checklist,
              unit: unit,
              minimumBalanceValue: minBalance,
              maximumBalanceValue: maxBalance,
              currentBalanceValue: currentBalance,
              recoveryPercent: recoveryPercent,
              minimumPriceRm: minPrice,
              maximumPriceRm: maxPrice,
              supplierIds: supplierIds.toList(),
              photoPath: photoPath,
            );
      final saved = await runStockRequest(context, () => widget.onSave(sku));
      if (!saved || !mounted) return;
      showSuccessSnackBar(context, text.t(editing ? 'Saved' : 'SKU created'));
      widget.onClose();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final tags = tagNames;
    final selectedSupplierNames = widget.suppliers.where((supplier) => supplierIds.contains(supplier.id)).map((supplier) => supplier.supplierName).join(', ');
    final photoRequiredError = showErrors && !editing && pendingPhotoPath == null;
    const units = ['kg', 'pcs', 'box', 'bottle', 'carton', 'ctn', 'pack', 'bag', 'btl', 'biji', 'unit'];

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
        child: Column(children: [
          stockBottomSheetHandle(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(text.t(editing ? 'Edit SKU' : 'Add SKU'), style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700))),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
          ]),
        ]),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        children: [
          _DialogInput(label: text.t('SKU Name'), controller: nameController, hint: text.t('Example: Chicken'), errorText: requiredText(nameController, text.t('SKU Name required'))),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Tag 1')),
          DropdownButtonFormField<String>(initialValue: tags.contains(tag1) ? tag1 : null, isExpanded: true, items: tags.map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(), onChanged: (value) => setState(() => tag1 = value), decoration: _inputDecoration(tags.isEmpty ? text.t('Create tag first') : text.t('Select Tag')).copyWith(errorText: showErrors && tag1 == null ? text.t('Tag 1 required') : null)),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Tag 2')),
          DropdownButtonFormField<String>(initialValue: tags.contains(tag2) ? tag2 : null, isExpanded: true, items: tags.map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(), onChanged: (value) => setState(() => tag2 = value), decoration: _inputDecoration(tags.isEmpty ? text.t('Create tag first') : text.t('Select Tag')).copyWith(errorText: showErrors && tag2 == null ? text.t('Tag 2 required') : null)),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Receiving Checklist')),
          ...List.generate(5, (index) => Padding(padding: EdgeInsets.only(top: index == 0 ? 0 : 8), child: _DialogBareInput(controller: checklistControllers[index], hint: text.t('Checklist ${index + 1}')))),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Stock Thumbnail')),
          Pressable(
            onTap: saving ? null : takePhoto,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColours.blueSoft.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: photoRequiredError ? AppColours.red : AppColours.border)),
              child: pendingPhotoBytes != null
                  ? Image.memory(pendingPhotoBytes!, height: 160, fit: BoxFit.cover)
                  : editing
                      ? Row(children: [_SkuPhotoThumb(sku: widget.initialSku!, size: 64), const SizedBox(width: 12), Expanded(child: Text(text.t('Tap to replace photo'), style: const TextStyle(fontWeight: FontWeight.w700)))])
                      : Row(children: [Icon(Icons.photo_camera_outlined, color: photoRequiredError ? AppColours.red : AppColours.blue), const SizedBox(width: 10), Text(text.t('Take Photo'), style: const TextStyle(fontWeight: FontWeight.w700))]),
            ),
          ),
          if (photoRequiredError) _InlineError(text.t('Stock Thumbnail required')),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Reset Time')),
          OutlinedButton.icon(onPressed: pickResetTime, icon: const Icon(Icons.schedule_rounded), label: Text(resetTime)),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Unit')),
          DropdownButtonFormField<String>(initialValue: units.contains(unit) ? unit : 'unit', decoration: _inputDecoration(''), items: units.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) setState(() => unit = value); }),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Balance')),
          Row(children: [
            Expanded(child: _DialogBareInput(controller: minBalanceController, hint: text.t('Min'), suffixText: unit, errorText: requiredNumber(minBalanceController, text.t('Min required')))),
            if (editing) ...[const SizedBox(width: 8), Expanded(child: _DialogBareInput(controller: currentBalanceController, hint: text.t('Current'), suffixText: unit, errorText: requiredNumber(currentBalanceController, text.t('Current required'))))],
            const SizedBox(width: 8),
            Expanded(child: _DialogBareInput(controller: maxBalanceController, hint: text.t('Max'), suffixText: unit, errorText: requiredNumber(maxBalanceController, text.t('Max required')))),
          ]),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Recovery')),
          Row(children: [Expanded(child: Slider(value: recoveryPercent.toDouble(), min: 1, max: 100, divisions: 99, label: '$recoveryPercent%', onChanged: (value) => setState(() => recoveryPercent = value.round()))), SizedBox(width: 48, child: Text('$recoveryPercent%', textAlign: TextAlign.right))]),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Price')),
          Row(children: [
            Expanded(child: _DialogBareInput(controller: minPriceController, hint: text.t('Min'), prefixText: 'RM', errorText: requiredNumber(minPriceController, text.t('Min Price required')))),
            const SizedBox(width: 12),
            Expanded(child: _DialogBareInput(controller: maxPriceController, hint: text.t('Max'), prefixText: 'RM', errorText: requiredNumber(maxPriceController, text.t('Max Price required')))),
          ]),
          const SizedBox(height: 14),
          _FieldLabel(text.t('Suppliers')),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.suppliers.isEmpty ? null : pickSuppliers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColours.blueSoft.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: showErrors && supplierIds.isEmpty ? AppColours.red : AppColours.border)),
              child: Row(children: [Expanded(child: Text(widget.suppliers.isEmpty ? text.t('Create supplier first') : supplierIds.isEmpty ? text.t('None') : selectedSupplierNames, maxLines: 2, overflow: TextOverflow.ellipsis)), const Icon(Icons.arrow_drop_down_rounded)]),
            ),
          ),
          if (showErrors && supplierIds.isEmpty) _InlineError(text.t('Supplier required')),
          const SizedBox(height: 20),
          PrimaryButton(text: text.t(saving ? 'Saving...' : editing ? 'Save' : 'Save SKU'), icon: saving ? null : Icons.save_outlined, onPressed: saving ? null : save),
        ],
      )),
    ]);
  }
}
