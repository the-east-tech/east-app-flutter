part of 'stock_screen.dart';

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
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final sku in widget.skus)
        sku.id: TextEditingController(
          text: formatStockNumber(sku.currentBalanceValue),
        ),
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
      final existingController = controllers[sku.id];
      final editable = canEditCountSku(sku);
      if (existingController == null) {
        final controller = TextEditingController(
          text: formatStockNumber(sku.currentBalanceValue),
        )..addListener(refreshProgressBars);
        controllers[sku.id] = controller;
        notes[sku.id] = TextEditingController();
        autoSavedBySku[sku.id] = !editable;
        completedBySku[sku.id] = !editable;
        continue;
      }

      final wasEditable = canEditCountSku(
        sku,
        submissions: oldWidget.submissions,
      );
      if (!wasEditable && editable) {
        existingController.text = formatStockNumber(sku.currentBalanceValue);
        notes[sku.id]?.clear();
        autoSavedBySku[sku.id] = false;
        completedBySku[sku.id] = false;
      } else if (wasEditable && !editable) {
        autoSavedBySku[sku.id] = true;
        completedBySku[sku.id] = true;
      }
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

  bool submissionBlocksCount(StockSubmission submission) {
    final status = submission.reviewStatus.trim().toUpperCase();
    return status != 'REJECTED' && status != 'PENDING';
  }

  StockSubmission? latestSubmissionFor(
    StockSku sku, {
    List<StockSubmission>? submissions,
  }) {
    final start = countCycleStart(sku, DateTime.now());
    final end = start.add(const Duration(days: 1));
    for (final submission in submissions ?? widget.submissions) {
      if (submission.stockTaskId == sku.id &&
          submissionBlocksCount(submission) &&
          !submission.capturedAt.isBefore(start) &&
          submission.capturedAt.isBefore(end)) {
        return submission;
      }
    }
    return null;
  }

  bool canEditCountSku(
    StockSku sku, {
    List<StockSubmission>? submissions,
  }) {
    final alreadySubmitted = latestSubmissionFor(
          sku,
          submissions: submissions,
        ) !=
        null;
    return sku.active && sku.coolingPeriod && !alreadySubmitted;
  }

  void openSkuPhotoPreview(StockSku sku) {
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.7,
      builder: (sheetContext) => Padding(
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
                      AppTextScope.of(context).content(sku.name),
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
              const SizedBox(height: 12),
              Center(child: _SkuPhotoThumb(sku: sku, size: 260)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openSkuBalanceKeypad(StockSku sku) async {
    final text = AppTextScope.of(context);
    if (!canEditCountSku(sku)) {
      showWarningSnackBar(context, text.t('Submitted counts cannot be edited.'));
      return;
    }
    final enteredText = await showAppNumberPad(
      context,
      title: text.content(sku.name),
      initialText: controllers[sku.id]!.text,
      suffixText: ' ${sku.unit}',
      minimum: 0,
      valueFormatter: formatStockNumber,
      previewBuilder: (_, value) =>
          _SkuBalanceSummary(sku: sku, currentBalance: value),
    );
    if (!mounted || enteredText == null) return;
    controllers[sku.id]!.text = enteredText;
    setState(() {
      completedBySku[sku.id] = true;
      showCountErrors = false;
    });
  }

  Future<void> submit() async {
    final text = AppTextScope.of(context);
    var hasInvalid = false;
    var incomplete = false;
    final skusToSubmit = widget.skus.where(canEditCountSku).toList();

    for (final sku in skusToSubmit) {
      if (double.tryParse(controllers[sku.id]!.text.trim()) == null) {
        hasInvalid = true;
        break;
      }
      if (completedBySku[sku.id] != true) incomplete = true;
    }

    if (hasInvalid || incomplete) {
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
            belowMinimumBalance: currentBalance < sku.minimumBalanceValue,
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
    final activeTagFilter =
        tagOptions.contains(countTagFilter) ? countTagFilter : 'All';
    final visibleSkus = filteredCountSkus(activeTagFilter);
    final completedCount = widget.skus.where((sku) {
      final hasNumber =
          double.tryParse(controllers[sku.id]!.text.trim()) != null;
      return hasNumber && completedBySku[sku.id] == true;
    }).length;
    final requiredSkus = widget.skus.where(canEditCountSku).toList();
    final requiredCompleted = requiredSkus.every((sku) {
      final hasNumber =
          double.tryParse(controllers[sku.id]!.text.trim()) != null;
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
                textColour: canSubmit ? AppColours.green : AppColours.red,
                backgroundColour:
                    canSubmit ? AppColours.greenSoft : AppColours.redSoft,
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
                final enteredBalance =
                    double.tryParse(controllers[sku.id]!.text.trim()) ??
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
                    onBalanceTap: () => unawaited(openSkuBalanceKeypad(sku)),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (showCountErrors && !canSubmit) ...[
          const SizedBox(height: 10),
          Text(
            text.t('Complete all pending items'),
            style: const TextStyle(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColours.blue : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? AppColours.blue : AppColours.border,
                  ),
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

  @override
  Widget build(BuildContext context) {
    final hasPhoto = sku.photoPath.trim().isNotEmpty;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasPhoto ? const Color(0xFFEAF3FF) : AppColours.background,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColours.border),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.56,
        color: hasPhoto ? AppColours.blue : AppColours.textMuted,
      ),
    );
    final storageKey = sku.photoPath.trim();
    final storedThumbnail =
        storageKey.endsWith('.jpg') || storageKey.endsWith('.png');
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
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: const BoxDecoration(
                color: AppColours.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: size * 0.24,
                color: Colors.white,
              ),
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
  final translatedSkuName = AppTextScope.of(context).content(sku.name);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) {
        Widget page = Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(translatedSkuName),
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
    final text = AppTextScope.of(context);
    final maximum =
        sku.maximumBalanceValue <= 0 ? 1.0 : sku.maximumBalanceValue;
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
                          color: countedNow
                              ? AppColours.greenSoft
                              : AppColours.background,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _SkuPhotoThumb(
                          sku: sku,
                          size: 48,
                          showCountTick: countedNow,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.content(sku.name),
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
                                    border:
                                        Border.all(color: AppColours.border),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 450),
                                        curve: Curves.easeOutCubic,
                                        width: constraints.maxWidth * ratio,
                                        decoration: BoxDecoration(
                                          color: statusColour,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
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
                        border: Border.all(
                          color: statusIconColour.withValues(
                            alpha: countedNow ? 0.50 : 0.35,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        statusIcon,
                        size: 17,
                        color: statusIconColour,
                      ),
                    ),
                  ],
                ),
                if (countedNow) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColours.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        text.t('Tap to edit'),
                        style: const TextStyle(
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
