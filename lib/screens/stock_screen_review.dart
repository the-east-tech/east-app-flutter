part of 'stock_screen.dart';

enum _StockApprovalKind { count, receivable, sku }

class _StockApprovalScope extends InheritedWidget {
  final Widget section;

  const _StockApprovalScope({
    required this.section,
    required super.child,
  });

  static Widget? maybeSectionOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_StockApprovalScope>()
        ?.section;
  }

  @override
  bool updateShouldNotify(covariant _StockApprovalScope oldWidget) {
    return oldWidget.section != section;
  }
}

class _StockApprovalLauncher extends StatelessWidget {
  final _StockApprovalKind kind;
  final EastAppApi api;
  final Future<void> Function(StockReceivableRecord record) onReviewReceivable;
  final Future<void> Function(StockSubmission submission) onReviewStockCount;
  final Future<void> Function(List<StockSubmission> submissions)
      onBulkReviewStockCounts;
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final bool canReviewSkuChanges;
  final Future<void> Function() onSkuChangeReviewed;

  const _StockApprovalLauncher({
    required this.kind,
    required this.api,
    required this.onReviewReceivable,
    required this.onReviewStockCount,
    required this.onBulkReviewStockCounts,
    required this.tags,
    required this.suppliers,
    required this.canReviewSkuChanges,
    required this.onSkuChangeReviewed,
  });

  bool get isReceivable => kind == _StockApprovalKind.receivable;
  bool get isSku => kind == _StockApprovalKind.sku;

  Future<void> _open(BuildContext context) async {
    AppFeedback.select();
    await showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.94,
      builder: (sheetContext) => isSku
          ? _SkuChangeApprovalSheet(
              api: api,
              tags: tags,
              suppliers: suppliers,
              canReview: canReviewSkuChanges,
              onReviewed: onSkuChangeReviewed,
            )
          : _StockApprovalSheet(
              kind: kind,
              api: api,
              onReviewReceivable: onReviewReceivable,
              onReviewStockCount: onReviewStockCount,
              onBulkReviewStockCounts: onBulkReviewStockCounts,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: () => unawaited(_open(context)),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isSku
                      ? Icons.edit_note_rounded
                      : isReceivable
                          ? Icons.inventory_2_outlined
                          : Icons.fact_check_outlined,
                  color: AppColours.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t(
                        isSku
                            ? 'SKU Change Records'
                            : isReceivable
                                ? 'Receivable Records'
                                : 'Daily Count Records',
                      ),
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text.t(
                        isSku
                            ? 'Review submitted SKU changes'
                            : isReceivable
                                ? 'Review submitted receivable records'
                                : 'Review submitted daily stock counts',
                      ),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontSize: AppTextSize.s13,
                        fontWeight: FontWeight.w600,
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

class _StockApprovalSheet extends StatefulWidget {
  final _StockApprovalKind kind;
  final EastAppApi api;
  final Future<void> Function(StockReceivableRecord record) onReviewReceivable;
  final Future<void> Function(StockSubmission submission) onReviewStockCount;
  final Future<void> Function(List<StockSubmission> submissions)
      onBulkReviewStockCounts;

  const _StockApprovalSheet({
    required this.kind,
    required this.api,
    required this.onReviewReceivable,
    required this.onReviewStockCount,
    required this.onBulkReviewStockCounts,
  });

  @override
  State<_StockApprovalSheet> createState() => _StockApprovalSheetState();
}

class _StockApprovalSheetState extends State<_StockApprovalSheet> {
  static const int _pageSize = 50;
  static const List<StockWorkflowStatus> _statusOptions =
      StockWorkflowStatus.values;

  StockWorkflowStatus statusFilter = StockWorkflowStatus.submitted;
  late DateTime rangeStart;
  late DateTime rangeEnd;
  List<StockReceivableRecord> receivableRecords = const [];
  List<StockSubmission> countRecords = const [];
  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  int loadedPage = -1;
  int totalElements = 0;
  bool lastPage = true;
  bool selecting = false;
  final Set<String> selectedIds = <String>{};

  bool get isReceivable => widget.kind == _StockApprovalKind.receivable;
  bool get canReviewSelectedStatus =>
      statusFilter == StockWorkflowStatus.submitted;
  int get recordsCount =>
      isReceivable ? receivableRecords.length : countRecords.length;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    rangeEnd = today;
    rangeStart = today.subtract(const Duration(days: 29));
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String get rangeLabel =>
      '${_formatDate(rangeStart)} – ${_formatDate(rangeEnd)}';

  void _clearLoadedResults() {
    receivableRecords = const [];
    countRecords = const [];
    loaded = false;
    loadedPage = -1;
    totalElements = 0;
    lastPage = true;
    selecting = false;
    selectedIds.clear();
  }

  Future<void> selectDateRange() async {
    final text = AppTextScope.of(context);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: DateTimeRange(start: rangeStart, end: rangeEnd),
      helpText: text.t('Select Date Range'),
      saveText: text.t('Apply'),
      switchToInputEntryModeIcon: const Icon(Icons.edit_rounded),
    );
    if (selected == null || !mounted) return;

    final start = _dateOnly(selected.start);
    final end = _dateOnly(selected.end);
    if (end.difference(start).inDays + 1 > 30) {
      await AppFeedback.warning();
      if (!mounted) return;
      showWarningSnackBar(context, text.t('Maximum 30 days.'));
      return;
    }

    setState(() {
      rangeStart = start;
      rangeEnd = end;
      _clearLoadedResults();
    });
  }

  Future<void> loadRecords({bool reset = true}) async {
    if (loading || loadingMore || (!reset && lastPage)) return;
    setState(() {
      if (reset) {
        loading = true;
        selecting = false;
        selectedIds.clear();
      } else {
        loadingMore = true;
      }
    });

    try {
      final page = reset ? 0 : loadedPage + 1;
      if (isReceivable) {
        final result = await widget.api.stockReceivables(
          workflowStatus: statusFilter,
          from: rangeStart,
          to: rangeEnd,
          page: page,
          size: _pageSize,
        );
        if (!mounted) return;
        setState(() {
          receivableRecords = reset
              ? List<StockReceivableRecord>.from(result.content)
              : [...receivableRecords, ...result.content];
          loaded = true;
          loadedPage = result.page;
          totalElements = result.totalElements;
          lastPage = result.last;
        });
      } else {
        final result = await widget.api.stockCounts(
          mine: false,
          workflowStatus: statusFilter,
          from: rangeStart,
          to: rangeEnd,
          page: page,
          size: _pageSize,
        );
        if (!mounted) return;
        setState(() {
          countRecords = reset
              ? List<StockSubmission>.from(result.content)
              : [...countRecords, ...result.content];
          loaded = true;
          loadedPage = result.page;
          totalElements = result.totalElements;
          lastPage = result.last;
        });
      }
    } on EastAppApiException catch (_) {
      // Global API error UI already presents the failure.
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  StockSku skuForSubmission(StockSubmission submission) {
    return StockSku(
      id: submission.stockTaskId,
      name: submission.skuName.isEmpty
          ? submission.stockTaskId
          : submission.skuName,
      category: submission.skuCategory,
      unit: submission.skuUnit,
      minimumBalanceValue: submission.skuMinimumBalanceValue,
      maximumBalanceValue: submission.skuMaximumBalanceValue,
      currentBalanceValue: submission.currentBalanceValue,
      supplierIds: const [],
      photoPath: submission.skuPhotoPath,
      location: submission.skuLocation,
      lastUpdatedAt: submission.submittedAt,
      lastUpdatedBy: submission.submittedBy,
    );
  }

  Color workflowStatusColour(StockWorkflowStatus status) {
    return switch (status) {
      StockWorkflowStatus.pending => AppColours.red,
      StockWorkflowStatus.submitted => AppColours.blue,
      StockWorkflowStatus.done => AppColours.green,
    };
  }

  Color receivableConditionColour(StockReceivableRecord record) {
    final condition = record.items.isEmpty
        ? ''
        : record.items.first.condition.toLowerCase();
    if (condition.contains('good') ||
        condition.contains('pass') ||
        condition.contains('ok')) {
      return AppColours.green;
    }
    if (condition.contains('bad') ||
        condition.contains('reject') ||
        condition.contains('damag')) {
      return AppColours.red;
    }
    return AppColours.orange;
  }

  String recordDateLabel(DateTime value) => _formatDate(_dateOnly(value));

  void toggleSelection(String id) {
    if (!canReviewSelectedStatus) return;
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void startSelection() {
    if (!canReviewSelectedStatus) return;
    AppFeedback.select();
    setState(() {
      selecting = true;
      selectedIds.clear();
    });
  }

  void cancelSelection() {
    AppFeedback.select();
    setState(() {
      selecting = false;
      selectedIds.clear();
    });
  }

  Future<bool> reviewReceivable(
    StockReceivableRecord record,
    StockWorkflowStatus status,
  ) async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(
        status == StockWorkflowStatus.done
            ? 'Approve Receivable Record?'
            : 'Return Receivable Record?',
      ),
      details: text.t(
        'This will update the review status of this receivable record.',
      ),
    );
    if (!confirmed || !mounted) return false;
    final updated = record.copyWith(
      workflowStatus: status,
      reviewNote: status == StockWorkflowStatus.done ? 'Approved.' : 'Returned.',
    );
    final saved = await runStockRequest(
      context,
      () => widget.onReviewReceivable(updated),
    );
    if (!saved || !mounted) return false;
    setState(() {
      receivableRecords = receivableRecords
          .where((item) => item.id != record.id)
          .toList();
      totalElements = totalElements > 0 ? totalElements - 1 : 0;
      selectedIds.remove(record.id);
    });
    showSuccessSnackBar(
      context,
      text.t(
        status == StockWorkflowStatus.done
            ? 'Receivable record approved'
            : 'Receivable record returned',
      ),
    );
    return true;
  }

  Future<bool> reviewCount(
    StockSubmission submission,
    StockWorkflowStatus status,
  ) async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(
        status == StockWorkflowStatus.done
            ? 'Approve Daily Count?'
            : 'Return Daily Count?',
      ),
      details: text.t(
        'This will update the review status of this daily stock count.',
      ),
    );
    if (!confirmed || !mounted) return false;
    final updated = submission.copyWith(
      workflowStatus: status,
      reviewNote: status == StockWorkflowStatus.done ? 'Approved.' : 'Returned.',
    );
    final saved = await runStockRequest(
      context,
      () => widget.onReviewStockCount(updated),
    );
    if (!saved || !mounted) return false;
    setState(() {
      countRecords = countRecords
          .where((item) => item.id != submission.id)
          .toList();
      totalElements = totalElements > 0 ? totalElements - 1 : 0;
      selectedIds.remove(submission.id);
    });
    showSuccessSnackBar(
      context,
      text.t(
        status == StockWorkflowStatus.done
            ? 'Daily count approved'
            : 'Daily count returned',
      ),
    );
    return true;
  }

  Future<void> bulkReview(StockWorkflowStatus status) async {
    if (selectedIds.isEmpty || !canReviewSelectedStatus) return;
    final selectedCount = selectedIds.length;
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(
        status == StockWorkflowStatus.done
            ? 'Approve $selectedCount records?'
            : 'Return $selectedCount records?',
      ),
      details: text.t('This will update all selected records.'),
    );
    if (!confirmed || !mounted) return;

    final selected = countRecords
        .where((item) => selectedIds.contains(item.id))
        .toList();
    final updated = selected
        .map(
          (item) => item.copyWith(
            workflowStatus: status,
            reviewNote:
                status == StockWorkflowStatus.done ? 'Approved.' : 'Returned.',
          ),
        )
        .toList();
    final ok = await runStockRequest(
      context,
      () => widget.onBulkReviewStockCounts(updated),
    );
    if (!ok || !mounted) return;
    setState(() {
      countRecords = countRecords
          .where((item) => !selectedIds.contains(item.id))
          .toList();
      totalElements =
          (totalElements - selected.length).clamp(0, totalElements).toInt();
    });

    setState(() {
      selecting = false;
      selectedIds.clear();
    });
    showSuccessSnackBar(
      context,
      text.t(
        status == StockWorkflowStatus.done
            ? 'Selected records approved'
            : 'Selected records returned',
      ),
    );
  }

  void showReceivableDetails(StockReceivableRecord record) {
    final text = AppTextScope.of(context);
    final conditionColour = receivableConditionColour(record);
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.92,
      builder: (detailContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        text.t('Receivable Review'),
                        style: const TextStyle(
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(detailContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewInfoRows(
                        rows: [
                          _ReviewInfoRow(
                            label: 'Review Status',
                            value: record.workflowStatus.label,
                            valueColour:
                                workflowStatusColour(record.workflowStatus),
                          ),
                          _ReviewInfoRow(
                            label: 'Supplier',
                            value: record.supplierName,
                          ),
                          _ReviewInfoRow(
                            label: 'Captured',
                            value: recordDateLabel(record.capturedAt),
                          ),
                          _ReviewInfoRow(
                            label: 'Received By',
                            value: record.receivedBy,
                          ),
                          for (final item in record.items)
                            _ReviewInfoRow(
                              label: item.skuName,
                              value:
                                  '${formatStockNumber(item.receivedQuantity)} ${item.unit} · ${item.condition}',
                            ),
                          if (record.reviewedBy.isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Reviewed By',
                              value: record.reviewedBy,
                            ),
                          if (record.reviewedAt.isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Reviewed At',
                              value: record.reviewedAt,
                            ),
                          if (record.reviewNote.isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Review Note',
                              value: record.reviewNote,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ReviewPhotoGrid(
                        record: record,
                        conditionColour: conditionColour,
                      ),
                    ],
                  ),
                ),
                if (record.workflowStatus == StockWorkflowStatus.submitted) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Return'),
                          outlined: true,
                          icon: Icons.close_rounded,
                          onPressed: () async {
                            final ok = await reviewReceivable(
                              record,
                              StockWorkflowStatus.pending,
                            );
                            if (ok && detailContext.mounted) {
                              Navigator.of(detailContext).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Approve'),
                          icon: Icons.check_rounded,
                          onPressed: () async {
                            final ok = await reviewReceivable(
                              record,
                              StockWorkflowStatus.done,
                            );
                            if (ok && detailContext.mounted) {
                              Navigator.of(detailContext).pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void showCountDetails(StockSubmission submission) {
    final text = AppTextScope.of(context);
    final sku = skuForSubmission(submission);
    final increased = submission.increasedValue;
    final increasedText =
        '${increased >= 0 ? '+' : ''}${formatStockNumber(increased)} ${sku.unit}';
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.92,
      builder: (detailContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        text.t('Daily Count Review'),
                        style: const TextStyle(
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(detailContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewInfoRows(
                        rows: [
                          _ReviewInfoRow(
                            label: 'Review Status',
                            value: submission.workflowStatus.label,
                            valueColour: workflowStatusColour(
                              submission.workflowStatus,
                            ),
                          ),
                          _ReviewInfoRow(label: 'SKU', value: sku.name),
                          _ReviewInfoRow(
                            label: 'Current Balance',
                            value:
                                '${formatStockNumber(submission.currentBalanceValue)} ${sku.unit}',
                          ),
                          _ReviewInfoRow(
                            label: 'Min',
                            value:
                                '${formatStockNumber(sku.minimumBalanceValue)} ${sku.unit}',
                          ),
                          _ReviewInfoRow(
                            label: 'Max',
                            value:
                                '${formatStockNumber(sku.maximumBalanceValue)} ${sku.unit}',
                          ),
                          _ReviewInfoRow(
                            label: 'Changed Value',
                            value: increasedText,
                            valueColour: increased >= 0
                                ? AppColours.green
                                : AppColours.red,
                          ),
                          _ReviewInfoRow(
                            label: 'Previous Value',
                            value:
                                '${formatStockNumber(submission.previousBalanceValue)} ${sku.unit}',
                          ),
                          _ReviewInfoRow(
                            label: 'Captured',
                            value: recordDateLabel(submission.capturedAt),
                          ),
                          _ReviewInfoRow(
                            label: 'Counted By',
                            value: submission.submittedBy,
                          ),
                          if ((submission.remarks['note'] ?? '')
                              .trim()
                              .isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Remark',
                              value: submission.remarks['note']!,
                            ),
                          if (submission.reviewedBy.isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Reviewed By',
                              value: submission.reviewedBy,
                            ),
                          if (submission.reviewedAt.isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Reviewed At',
                              value: submission.reviewedAt,
                            ),
                          if (submission.reviewNote.isNotEmpty)
                            _ReviewInfoRow(
                              label: 'Review Note',
                              value: submission.reviewNote,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CountReviewPhotoPreview(sku: sku, onTap: () {}),
                    ],
                  ),
                ),
                if (submission.workflowStatus ==
                    StockWorkflowStatus.submitted) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Return'),
                          outlined: true,
                          icon: Icons.close_rounded,
                          onPressed: () async {
                            final ok = await reviewCount(
                              submission,
                              StockWorkflowStatus.pending,
                            );
                            if (ok && detailContext.mounted) {
                              Navigator.of(detailContext).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Approve'),
                          icon: Icons.check_rounded,
                          onPressed: () async {
                            final ok = await reviewCount(
                              submission,
                              StockWorkflowStatus.done,
                            );
                            if (ok && detailContext.mounted) {
                              Navigator.of(detailContext).pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget statusDropdown() {
    final text = AppTextScope.of(context);
    return DropdownButtonFormField<StockWorkflowStatus>(
      initialValue: statusFilter,
      isExpanded: true,
      decoration: _inputDecoration(text.t('Status')).copyWith(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: _statusOptions
          .map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(text.t(status.label)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value == statusFilter) return;
        setState(() {
          statusFilter = value;
          _clearLoadedResults();
        });
      },
    );
  }

  Widget selectionToolbar() {
    final text = AppTextScope.of(context);
    return WhiteCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.t('${selectedIds.length} selected'),
              style: const TextStyle(
                fontSize: AppTextSize.s14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: cancelSelection,
            child: Text(text.t('Cancel')),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: selectedIds.isEmpty
                ? null
                : () => bulkReview(StockWorkflowStatus.pending),
            child: Text(text.t('Return')),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: selectedIds.isEmpty
                ? null
                : () => bulkReview(StockWorkflowStatus.done),
            child: Text(text.t('Approve')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              children: [
                stockBottomSheetHandle(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.t(
                          isReceivable
                              ? 'Receivable Records'
                              : 'Daily Count Records',
                        ),
                        style: const TextStyle(
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!isReceivable &&
                        loaded &&
                        canReviewSelectedStatus &&
                        recordsCount > 0 &&
                        !selecting)
                      TextButton.icon(
                        onPressed: startSelection,
                        icon: const Icon(Icons.checklist_rounded),
                        label: Text(text.t('Select')),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                statusDropdown(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: selectDateRange,
                    icon: const Icon(Icons.date_range_rounded, size: 20),
                    label: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rangeLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTextSize.s13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: text.t(
                    loading
                        ? 'Searching...'
                        : loaded
                            ? 'Search Again'
                            : 'Search',
                  ),
                  icon: loading ? null : Icons.search_rounded,
                  onPressed: loading ? null : () => loadRecords(reset: true),
                ),
                const SizedBox(height: 14),
                if (!loaded)
                  WhiteCard(
                    child: Text(
                      text.t(
                        'Select Status and Date, then press Search.',
                      ),
                      style: const TextStyle(
                        fontSize: AppTextSize.s15,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else ...[
                  if (selecting) ...[
                    selectionToolbar(),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          label: 'Results',
                          value: '$totalElements',
                          icon: Icons.manage_search_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Loaded',
                          value: '$recordsCount',
                          icon: Icons.download_done_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (recordsCount == 0)
                    WhiteCard(
                      child: Text(
                        text.t(
                          isReceivable
                              ? 'No receivable records found.'
                              : 'No daily count records found.',
                        ),
                        style: const TextStyle(
                          fontSize: AppTextSize.s16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    WhiteCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: isReceivable
                            ? receivableRecords.map((record) {
                                final selected =
                                    selectedIds.contains(record.id);
                                return _ReceivableReviewRow(
                                  record: record,
                                  timerText:
                                      recordDateLabel(record.capturedAt),
                                  statusText: record.workflowStatus.label,
                                  statusColour:
                                      workflowStatusColour(record.workflowStatus),
                                  conditionColour:
                                      receivableConditionColour(record),
                                  selectMode: false,
                                  selectable: false,
                                  selected: selected,
                                  onTap: () => showReceivableDetails(record),
                                  onSelectToggle: () =>
                                      toggleSelection(record.id),
                                );
                              }).toList()
                            : countRecords.map((submission) {
                                final sku = skuForSubmission(submission);
                                final selected =
                                    selectedIds.contains(submission.id);
                                return _DailyCountReviewRow(
                                  submission: submission,
                                  sku: sku,
                                  timerText:
                                      recordDateLabel(submission.capturedAt),
                                  statusText: submission.workflowStatus.label,
                                  statusColour: workflowStatusColour(
                                    submission.workflowStatus,
                                  ),
                                  selectMode: selecting,
                                  selectable: canReviewSelectedStatus,
                                  selected: selected,
                                  onTap: () => showCountDetails(submission),
                                  onSelectToggle: () =>
                                      toggleSelection(submission.id),
                                );
                              }).toList(),
                      ),
                    ),
                  if (!lastPage) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      text: loadingMore ? 'Loading...' : 'Load More',
                      icon: loadingMore ? null : Icons.expand_more_rounded,
                      onPressed:
                          loadingMore ? null : () => loadRecords(reset: false),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkuChangeApprovalSheet extends StatefulWidget {
  final EastAppApi api;
  final List<StockTag> tags;
  final List<SupplierProfile> suppliers;
  final bool canReview;
  final Future<void> Function() onReviewed;

  const _SkuChangeApprovalSheet({
    required this.api,
    required this.tags,
    required this.suppliers,
    required this.canReview,
    required this.onReviewed,
  });

  @override
  State<_SkuChangeApprovalSheet> createState() =>
      _SkuChangeApprovalSheetState();
}

class _SkuChangeApprovalSheetState extends State<_SkuChangeApprovalSheet> {
  List<StockSkuChangeRequest> records = const [];
  StockWorkflowStatus statusFilter = StockWorkflowStatus.submitted;
  bool loading = true;
  String? reviewingId;

  List<StockSkuChangeRequest> get visibleRecords => records
      .where((record) => record.workflowStatus == statusFilter)
      .toList(growable: false);

  static const proposalKeys = [
    'name',
    'tag1Id',
    'tag2Id',
    'supplierIds',
    'unit',
    'minimumBalanceValue',
    'maximumBalanceValue',
    'currentBalanceValue',
    'recoveryPercent',
    'minimumPriceRm',
    'maximumPriceRm',
    'assignedStaffNames',
    'receivableChecklist',
    'stockCheckSchedule',
    'stockCheckDay',
    'stockCheckDate',
    'active',
    'coolingPeriod',
  ];

  String proposalLabel(String key) => switch (key) {
        'name' => 'SKU Name',
        'tag1Id' => 'Tag 1',
        'tag2Id' => 'Tag 2',
        'supplierIds' => 'Suppliers',
        'unit' => 'Unit',
        'minimumBalanceValue' => 'Minimum Balance',
        'maximumBalanceValue' => 'Maximum Balance',
        'currentBalanceValue' => 'Current Balance',
        'recoveryPercent' => 'Recovery',
        'minimumPriceRm' => 'Minimum Price',
        'maximumPriceRm' => 'Maximum Price',
        'assignedStaffNames' => 'Assigned Staff',
        'receivableChecklist' => 'Receivable Checklist',
        'stockCheckSchedule' => 'Stock Check Schedule',
        'stockCheckDay' => 'Stock Check Day',
        'stockCheckDate' => 'Stock Check Date',
        'active' => 'Active',
        'coolingPeriod' => 'Cooling Period',
        _ => key,
      };

  String tagName(Object? value) {
    if (value == null) return 'None';
    final id = value.toString();
    for (final tag in widget.tags) {
      if (tag.id == id) return tag.tag;
    }
    return 'Unavailable';
  }

  String supplierNames(Object? value) {
    if (value is! List || value.isEmpty) return 'None';
    final names = value.map((id) {
      for (final supplier in widget.suppliers) {
        if (supplier.id == id.toString()) return supplier.supplierName;
      }
      return 'Unavailable';
    });
    return names.join('\n');
  }

  String readableEnum(Object? value) {
    final words = value
        .toString()
        .toLowerCase()
        .split('_')
        .where((word) => word.isNotEmpty);
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String proposalValue(String key, Object? value) {
    if (key == 'tag1Id' || key == 'tag2Id') return tagName(value);
    if (key == 'supplierIds') return supplierNames(value);
    if (value == null) return '-';
    if (value is List) {
      if (value.isEmpty) return 'None';
      if (key == 'receivableChecklist') {
        return List.generate(
          value.length,
          (index) => '${index + 1}. ${value[index]}',
        ).join('\n');
      }
      return value.join('\n');
    }
    if (value is bool) return value ? 'Yes' : 'No';
    if (key == 'stockCheckSchedule') return readableEnum(value);
    if (key == 'recoveryPercent') return '$value%';
    if (key == 'minimumPriceRm' || key == 'maximumPriceRm') {
      return 'RM $value';
    }
    final result = value.toString().trim();
    return result.isEmpty ? '-' : result;
  }

  List<_ReviewInfoRow> proposalRows(StockSkuChangeRequest record) {
    final data = record.proposedData;
    if (data == null) return const [];
    return proposalKeys
        .where(
          (key) => data.containsKey(key) &&
              !(record.changeType == 'UPDATE' &&
                  key == 'currentBalanceValue'),
        )
        .map(
          (key) => _ReviewInfoRow(
            label: proposalLabel(key),
            value: proposalValue(key, data[key]),
          ),
        )
        .toList(growable: false);
  }

  String requestTime(DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  void initState() {
    super.initState();
    unawaited(loadRecords());
  }

  Future<void> loadRecords() async {
    if (mounted) setState(() => loading = true);
    try {
      final loaded = await widget.api.stockSkuChangeRequests();
      if (!mounted) return;
      setState(() => records = loaded);
    } on EastAppApiException {
      // Global API error handling already presents the failure.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> returnReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Return SKU Change?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain what must be corrected',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Return'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> review(
    StockSkuChangeRequest record,
    StockWorkflowStatus nextStatus,
  ) async {
    if (!widget.canReview || reviewingId != null) return;
    String note = '';
    if (nextStatus == StockWorkflowStatus.pending) {
      final reason = await returnReason();
      if (reason == null || !mounted) return;
      note = reason;
    } else {
      final confirmed = await confirmDataChange(
        context,
        action: 'Approve SKU Change?',
        details:
            'This will apply the ${record.changeType.toLowerCase()} change to ${record.skuName}.',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => reviewingId = record.id);
    try {
      final updated = await widget.api.reviewStockSkuChange(
        requestId: record.id,
        status: nextStatus,
        note: note,
      );
      await widget.onReviewed();
      if (!mounted) return;
      setState(() {
        records = records
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
      showSuccessSnackBar(
        context,
        nextStatus == StockWorkflowStatus.done
            ? 'SKU change approved'
            : 'SKU change returned',
      );
    } on EastAppApiException {
      // Global API error handling already presents the failure.
    } finally {
      if (mounted) setState(() => reviewingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final visible = visibleRecords;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              children: [
                stockBottomSheetHandle(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SKU Change Records',
                        style: TextStyle(
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: loadRecords,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                DropdownButtonFormField<StockWorkflowStatus>(
                  initialValue: statusFilter,
                  decoration: _inputDecoration(text.t('Status')),
                  items: StockWorkflowStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => statusFilter = value);
                  },
                ),
                const SizedBox(height: 12),
                if (!widget.canReview)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Only Owner can approve or return SKU changes.',
                      style: TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (visible.isEmpty)
                  const WhiteCard(
                    child: Text(
                      'No SKU change records found.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  ...visible.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: WhiteCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    record.skuName,
                                    style: const TextStyle(
                                      fontSize: AppTextSize.s17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                SmallStatusPill(
                                  text: record.changeType,
                                  textColour: AppColours.blue,
                                  backgroundColour: AppColours.blueSoft,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Requested by ${record.requestedByName.isEmpty ? 'Unknown' : record.requestedByName}',
                              style: const TextStyle(
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              requestTime(record.submittedAt),
                              style: const TextStyle(
                                color: AppColours.textMuted,
                                fontSize: AppTextSize.s12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (record.reviewNote.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Reason: ${record.reviewNote}'),
                            ],
                            if (record.proposedData != null) ...[
                              const SizedBox(height: 6),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Proposed Values',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                children: [
                                  _ReviewInfoRows(
                                    rows: proposalRows(record),
                                  ),
                                ],
                              ),
                            ],
                            if (record.workflowStatus ==
                                    StockWorkflowStatus.submitted &&
                                widget.canReview) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: PrimaryButton(
                                      text: 'Return',
                                      outlined: true,
                                      icon: Icons.undo_rounded,
                                      onPressed: reviewingId == null
                                          ? () => review(
                                                record,
                                                StockWorkflowStatus.pending,
                                              )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: PrimaryButton(
                                      text: reviewingId == record.id
                                          ? 'Applying...'
                                          : 'Approve',
                                      icon: Icons.check_rounded,
                                      onPressed: reviewingId == null
                                          ? () => review(
                                                record,
                                                StockWorkflowStatus.done,
                                              )
                                          : null,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
