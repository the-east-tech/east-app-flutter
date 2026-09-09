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
  final Future<void> Function(String skuId) onDeleteSku;
  final VoidCallback onClose;

  const _SkuDetailContent({
    required this.sku,
    required this.tags,
    required this.suppliers,
    required this.onUpdateSku,
    required this.onDeleteSku,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => _SkuEditorForm(
        api: _StockMediaScope.of(context).api,
        tags: tags,
        suppliers: suppliers,
        initialSku: sku,
        onSave: onUpdateSku,
        onDelete: () => onDeleteSku(sku.id),
        onClose: onClose,
      );
}

class _SkuEditorForm extends StatefulWidget {
  final EastAppApi api;
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final StockSku? initialSku;
  final Future<void> Function(StockSku sku) onSave;
  final Future<void> Function()? onDelete;
  final VoidCallback onClose;

  const _SkuEditorForm({
    required this.api,
    required this.tags,
    required this.suppliers,
    required this.onSave,
    required this.onClose,
    this.initialSku,
    this.onDelete,
  });

  @override
  State<_SkuEditorForm> createState() => _SkuEditorFormState();
}

class _SkuEditorFormState extends State<_SkuEditorForm> {
  late final TextEditingController nameController;
  late final List<TextEditingController> checklistControllers;
  late final TextEditingController minBalanceController;
  late final TextEditingController maxBalanceController;
  late final TextEditingController minPriceController;
  late final TextEditingController maxPriceController;
  late String? tag1;
  late String? tag2;
  late String unit;
  late StockCheckSchedule stockCheckSchedule;
  late int stockCheckDay;
  DateTime? stockCheckDate;
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
    final checklist = sku?.receivingChecklist.take(5).toList() ?? const <String>[];
    checklistControllers = checklist.isEmpty
        ? [TextEditingController()]
        : checklist.map((value) => TextEditingController(text: value)).toList();
    minBalanceController = TextEditingController(
      text: sku == null ? '' : formatStockNumber(sku.minimumBalanceValue),
    );
    maxBalanceController = TextEditingController(
      text: sku == null ? '' : formatStockNumber(sku.maximumBalanceValue),
    );
    minPriceController = TextEditingController(
      text: sku == null ? '' : formatStockNumber(sku.minimumPriceRm),
    );
    maxPriceController = TextEditingController(
      text: sku == null ? '' : formatStockNumber(sku.maximumPriceRm),
    );
    tag1 = sku?.category.trim().isEmpty == false ? sku!.category : null;
    tag2 = sku?.location.trim().isEmpty == false ? sku!.location : null;
    unit = sku?.unit ?? 'kg';
    stockCheckSchedule = sku?.stockCheckSchedule ?? StockCheckSchedule.daily;
    final configuredStockCheckDay = sku?.stockCheckDay;
    stockCheckDay = stockCheckSchedule == StockCheckSchedule.monthly &&
            (configuredStockCheckDay == null || configuredStockCheckDay > 28)
        ? 0
        : configuredStockCheckDay ?? 1;
    stockCheckDate = sku?.stockCheckDate;
    final recovery = sku?.recoveryPercent ?? 100;
    recoveryPercent = ((recovery / 5).round() * 5).clamp(5, 100).toInt();
    supplierIds = {...?sku?.supplierIds};
  }

  @override
  void dispose() {
    nameController.dispose();
    for (final controller in checklistControllers) {
      controller.dispose();
    }
    minBalanceController.dispose();
    maxBalanceController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  String? requiredText(TextEditingController controller, String message) =>
      showErrors && controller.text.trim().isEmpty ? message : null;

  String? requiredNumber(TextEditingController controller, String message) =>
      showErrors && double.tryParse(controller.text.trim()) == null
          ? message
          : null;

  void addChecklistItem() {
    if (checklistControllers.length >= 5) return;
    setState(() => checklistControllers.add(TextEditingController()));
  }

  Future<void> takePhoto() async {
    await showCameraOnlyCaptureDialog(
      context,
      title: AppTextScope.of(context).t('Stock Thumbnail'),
      subtitle: AppTextScope.of(context).t('Take a clear photo of the SKU.'),
      onCaptured: (path) async => setPendingPhoto(path),
    );
  }

  Future<void> pickPhotoFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    await setPendingPhoto(picked.path);
  }

  Future<void> setPendingPhoto(String path) async {
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    setState(() {
      pendingPhotoPath = path;
      pendingPhotoBytes = bytes;
    });
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
                child: Column(
                  children: [
                    stockBottomSheetHandle(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppTextScope.of(context).t('Suppliers'),
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
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.suppliers
                      .map(
                        (supplier) => CheckboxListTile(
                          value: selected.contains(supplier.id),
                          title: Text(supplier.supplierName),
                          onChanged: (value) => setSheetState(() {
                            if (value == true) {
                              selected.add(supplier.id);
                            } else {
                              selected.remove(supplier.id);
                            }
                          }),
                        ),
                      )
                      .toList(),
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
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selected.toList()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() => supplierIds = result.toSet());
    }
  }

  Future<void> save() async {
    final text = AppTextScope.of(context);
    setState(() => showErrors = true);
    final name = nameController.text.trim();
    final minBalance = double.tryParse(minBalanceController.text.trim());
    final maxBalance = double.tryParse(maxBalanceController.text.trim());
    final currentBalance = widget.initialSku?.currentBalanceValue ?? minBalance;
    final minPrice = double.tryParse(minPriceController.text.trim());
    final maxPrice = double.tryParse(maxPriceController.text.trim());
    final requiresPhoto = !editing;

    if (name.isEmpty ||
        unit.trim().isEmpty ||
        minBalance == null ||
        maxBalance == null ||
        currentBalance == null ||
        minPrice == null ||
        maxPrice == null ||
        supplierIds.isEmpty ||
        (requiresPhoto && pendingPhotoPath == null)) {
      AppFeedback.warning();
      return;
    }
    if (stockCheckSchedule == StockCheckSchedule.adHoc &&
        stockCheckDate == null) {
      AppFeedback.warning();
      showWarningSnackBar(context, text.t('Select one date.'));
      return;
    }
    if (minBalance < 0 || maxBalance <= 0 || maxBalance < minBalance) {
      showWarningSnackBar(context, text.t('Balance must be Min / Max.'));
      return;
    }
    if (minPrice < 0 || maxPrice < minPrice) {
      showWarningSnackBar(context, text.t('Price must be Min / Max.'));
      return;
    }

    final selectedTag1 = tag1 == null
        ? null
        : widget.tags.firstWhere((item) => item.tag == tag1);
    final selectedTag2 = tag2 == null
        ? null
        : widget.tags.firstWhere((item) => item.tag == tag2);
    final confirmed = await confirmDataChange(
      context,
      action: editing ? 'Update SKU?' : 'Create SKU?',
      details: editing
          ? 'This will save the edited SKU details and stock settings.'
          : 'This will create a new SKU for this business.',
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      var photoPath = widget.initialSku?.photoPath ?? '';
      if (pendingPhotoPath != null) {
        photoPath = await widget.api.uploadStockSkuThumbnail(pendingPhotoPath!);
      }
      final checklist = checklistControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .take(5)
          .toList();
      final effectiveStockCheckDay =
          stockCheckSchedule == StockCheckSchedule.daily ||
                  stockCheckSchedule == StockCheckSchedule.adHoc ||
                  (stockCheckSchedule == StockCheckSchedule.monthly &&
                      stockCheckDay == 0)
              ? null
              : stockCheckDay;
      final existing = widget.initialSku;
      final sku = existing == null
          ? StockSku(
              id: 'SKU${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              tag1Id: selectedTag1?.id ?? '',
              category: selectedTag1?.tag ?? '',
              tag2Id: selectedTag2?.id ?? '',
              location: selectedTag2?.tag ?? '',
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
              stockCheckSchedule: stockCheckSchedule,
              stockCheckDay: effectiveStockCheckDay,
              stockCheckDate: stockCheckDate,
              lastUpdatedAt: 'Not counted yet',
              lastUpdatedBy: headId,
              coolingPeriod: true,
            )
          : existing.copyWith(
                name: name,
                tag1Id: selectedTag1?.id ?? '',
                category: selectedTag1?.tag ?? '',
                tag2Id: selectedTag2?.id ?? '',
                location: selectedTag2?.tag ?? '',
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
                stockCheckSchedule: stockCheckSchedule,
                stockCheckDay: effectiveStockCheckDay,
                clearStockCheckDay: effectiveStockCheckDay == null,
                stockCheckDate: stockCheckDate,
              );
      final saved = await runStockRequest(context, () => widget.onSave(sku));
      if (!saved || !mounted) return;
      showSuccessSnackBar(context, text.t('Submitted for Owner approval'));
      widget.onClose();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteSku() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || saving) return;
    final confirmed = await confirmDataChange(
      context,
      action: 'Delete SKU?',
      details: 'This will submit the SKU deletion for Owner approval.',
    );
    if (!confirmed || !mounted) return;
    setState(() => saving = true);
    try {
      final deleted = await runStockRequest(context, onDelete);
      if (!deleted || !mounted) return;
      showSuccessSnackBar(context, 'Submitted for Owner approval');
      widget.onClose();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final tags = tagNames;
    final selectedSupplierNames = widget.suppliers
        .where((supplier) => supplierIds.contains(supplier.id))
        .map((supplier) => supplier.supplierName)
        .join(', ');
    final photoRequiredError = showErrors && !editing && pendingPhotoPath == null;
    const units = [
      'kg', 'pcs', 'box', 'bottle', 'carton', 'ctn', 'pack', 'bag', 'btl',
      'biji', 'unit',
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
          child: Column(
            children: [
              stockBottomSheetHandle(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.t(editing ? 'Edit SKU' : 'Add SKU'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            children: [
              _DialogInput(
                label: text.t('SKU Name'),
                controller: nameController,
                hint: text.t('Example: Chicken'),
                errorText: requiredText(
                  nameController,
                  text.t('SKU Name required'),
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Tag 1 (optional)')),
              DropdownButtonFormField<String>(
                initialValue: tag1 ?? '',
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: '', child: Text(text.t('None'))),
                  ...tags.map(
                    (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                  ),
                ],
                onChanged: (value) => setState(
                  () => tag1 = value == null || value.isEmpty ? null : value,
                ),
                decoration: _inputDecoration(text.t('None')),
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Tag 2 (optional)')),
              DropdownButtonFormField<String>(
                initialValue: tag2 ?? '',
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: '', child: Text(text.t('None'))),
                  ...tags.map(
                    (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                  ),
                ],
                onChanged: (value) => setState(
                  () => tag2 = value == null || value.isEmpty ? null : value,
                ),
                decoration: _inputDecoration(text.t('None')),
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Receiving Checklist')),
              ...List.generate(
                checklistControllers.length,
                (index) => Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: _DialogBareInput(
                    controller: checklistControllers[index],
                    hint: text.t('Checklist ${index + 1}'),
                  ),
                ),
              ),
              if (checklistControllers.length < 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: addChecklistItem,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: Text(text.t('Add checklist item')),
                  ),
                ),
              const SizedBox(height: 10),
              _FieldLabel(text.t('Stock Thumbnail')),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 92),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColours.blueSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: photoRequiredError ? AppColours.red : AppColours.border,
                  ),
                ),
                child: pendingPhotoBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          pendingPhotoBytes!,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      )
                    : editing
                        ? Row(
                            children: [
                              _SkuPhotoThumb(sku: widget.initialSku!, size: 64),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  text.t('Choose Camera or Gallery to replace photo'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: photoRequiredError
                                    ? AppColours.red
                                    : AppColours.blue,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                text.t('Choose a thumbnail photo'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(text.t('Camera')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : pickPhotoFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(text.t('Gallery')),
                    ),
                  ),
                ],
              ),
              if (photoRequiredError)
                _InlineError(text.t('Stock Thumbnail required')),
              const SizedBox(height: 14),
              ScheduleSelector(
                title: 'Stock Check',
                compact: true,
                value: _stockAppScheduleType(stockCheckSchedule),
                day: stockCheckSchedule == StockCheckSchedule.monthly
                    ? (stockCheckDay == 0 ? null : stockCheckDay)
                    : stockCheckDay,
                date: stockCheckDate,
                onTypeChanged: (value) => setState(() {
                  stockCheckSchedule = _stockCheckSchedule(value);
                  if (stockCheckSchedule == StockCheckSchedule.weekly &&
                      stockCheckDay == 0) {
                    stockCheckDay = 1;
                  }
                }),
                onDayChanged: (day) =>
                    setState(() => stockCheckDay = day ?? 0),
                onDateChanged: (date) => setState(() => stockCheckDate = date),
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Unit')),
              DropdownButtonFormField<String>(
                initialValue: units.contains(unit) ? unit : 'unit',
                decoration: _inputDecoration(''),
                items: units
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => unit = value);
                },
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Balance')),
              Row(
                children: [
                  Expanded(
                    child: _DialogBareInput(
                      controller: minBalanceController,
                      hint: text.t('Min'),
                      suffixText: unit,
                      errorText: requiredNumber(
                        minBalanceController,
                        text.t('Min required'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DialogBareInput(
                      controller: maxBalanceController,
                      hint: text.t('Max'),
                      suffixText: unit,
                      errorText: requiredNumber(
                        maxBalanceController,
                        text.t('Max required'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Recovery')),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: recoveryPercent.toDouble(),
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: '$recoveryPercent%',
                      onChanged: (value) =>
                          setState(() => recoveryPercent = value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$recoveryPercent%',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Price')),
              Row(
                children: [
                  Expanded(
                    child: _DialogBareInput(
                      controller: minPriceController,
                      hint: text.t('Min'),
                      prefixText: 'RM',
                      errorText: requiredNumber(
                        minPriceController,
                        text.t('Min Price required'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogBareInput(
                      controller: maxPriceController,
                      hint: text.t('Max'),
                      prefixText: 'RM',
                      errorText: requiredNumber(
                        maxPriceController,
                        text.t('Max Price required'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel(text.t('Suppliers')),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.suppliers.isEmpty ? null : pickSuppliers,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColours.blueSoft.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: showErrors && supplierIds.isEmpty
                          ? AppColours.red
                          : AppColours.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.suppliers.isEmpty
                              ? text.t('Create supplier first')
                              : supplierIds.isEmpty
                                  ? text.t('None')
                                  : selectedSupplierNames,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),
              if (showErrors && supplierIds.isEmpty)
                _InlineError(text.t('Supplier required')),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (editing) ...[
                    Expanded(
                      child: PrimaryButton(
                        text: text.t('Delete'),
                        icon: Icons.delete_outline_rounded,
                        outlined: true,
                        onPressed: saving ? null : deleteSku,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      text: text.t(saving ? 'Saving...' : editing ? 'Save' : 'Save SKU'),
                      icon: saving ? null : Icons.save_outlined,
                      onPressed: saving ? null : save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

AppScheduleType _stockAppScheduleType(StockCheckSchedule type) {
  return switch (type) {
    StockCheckSchedule.adHoc => AppScheduleType.adHoc,
    StockCheckSchedule.daily => AppScheduleType.daily,
    StockCheckSchedule.weekly => AppScheduleType.weekly,
    StockCheckSchedule.monthly => AppScheduleType.monthly,
  };
}

StockCheckSchedule _stockCheckSchedule(AppScheduleType type) {
  return switch (type) {
    AppScheduleType.adHoc => StockCheckSchedule.adHoc,
    AppScheduleType.daily => StockCheckSchedule.daily,
    AppScheduleType.weekly => StockCheckSchedule.weekly,
    AppScheduleType.monthly => StockCheckSchedule.monthly,
  };
}
