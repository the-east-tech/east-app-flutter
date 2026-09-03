part of 'stock_screen.dart';

enum _StockApprovalKind { count, receiving }

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
  final Future<void> Function(StockReceivingRecord record) onReviewReceiving;
  final Future<void> Function(StockSubmission submission) onReviewStockCount;
  final Future<void> Function(List<StockSubmission> submissions)
      onBulkReviewStockCounts;

  const _StockApprovalLauncher({
    required this.kind,
    required this.api,
    required this.onReviewReceiving,
    required this.onReviewStockCount,
    required this.onBulkReviewStockCounts,
  });

  bool get isReceiving => kind == _StockApprovalKind.receiving;

  Future<void> _open(BuildContext context) async {
    AppFeedback.select();
    await showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.94,
      builder: (sheetContext) => _StockApprovalSheet(
        kind: kind,
        api: api,
        onReviewReceiving: onReviewReceiving,
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
                  isReceiving
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
                        isReceiving
                            ? 'Receiving Records'
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
                        isReceiving
                            ? 'Review submitted receiving records'
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
  final Future<void> Function(StockReceivingRecord record) onReviewReceiving;
  final Future<void> Function(StockSubmission submission) onReviewStockCount;
  final Future<void> Function(List<StockSubmission> submissions)
      onBulkReviewStockCounts;

  const _StockApprovalSheet({
    required this.kind,
    required this.api,
    required this.onReviewReceiving,
    required this.onReviewStockCount,
    required this.onBulkReviewStockCounts,
  });

  @override
  State<_StockApprovalSheet> createState() => _StockApprovalSheetState();
}

class _StockApprovalSheetState extends State<_StockApprovalSheet> {
  static const int _pageSize = 50;
  static const List<String> _statusOptions = [
    'Pending Review',
    'Approved',
    'Rejected',
  ];

  String statusFilter = 'Pending Review';
  late DateTime rangeStart;
  late DateTime rangeEnd;
  List<StockReceivingRecord> receivingRecords = const [];
  List<StockSubmission> countRecords = const [];
  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  int loadedPage = -1;
  int totalElements = 0;
  bool lastPage = true;
  bool selecting = false;
  final Set<String> selectedIds = <String>{};

  bool get isReceiving => widget.kind == _StockApprovalKind.receiving;
  bool get canReviewSelectedStatus => statusFilter == 'Pending Review';
  int get recordsCount =>
      isReceiving ? receivingRecords.length : countRecords.length;

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
    receivingRecords = const [];
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
      if (isReceiving) {
        final result = await widget.api.stockReceivings(
          reviewStatus: statusFilter,
          from: rangeStart,
          to: rangeEnd,
          page: page,
          size: _pageSize,
        );
        if (!mounted) return;
        setState(() {
          receivingRecords = reset
              ? List<StockReceivingRecord>.from(result.content)
              : [...receivingRecords, ...result.content];
          loaded = true;
          loadedPage = result.page;
          totalElements = result.totalElements;
          lastPage = result.last;
        });
      } else {
        final result = await widget.api.stockCounts(
          mine: false,
          reviewStatus: statusFilter,
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

  Color reviewStatusColour(String status) {
    if (status == 'Approved') return AppColours.green;
    if (status == 'Rejected') return AppColours.red;
    return AppColours.blue;
  }

  Color receivingConditionColour(StockReceivingRecord record) {
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

  Future<bool> reviewReceiving(
    StockReceivingRecord record,
    String status,
  ) async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(
        status == 'Approved'
            ? 'Approve Receiving Record?'
            : 'Reject Receiving Record?',
      ),
      details: text.t(
        'This will update the review status of this receiving record.',
      ),
    );
    if (!confirmed || !mounted) return false;
    final updated = record.copyWith(
      reviewStatus: status,
      reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
    );
    final saved = await runStockRequest(
      context,
      () => widget.onReviewReceiving(updated),
    );
    if (!saved || !mounted) return false;
    setState(() {
      receivingRecords = receivingRecords
          .where((item) => item.id != record.id)
          .toList();
      totalElements = totalElements > 0 ? totalElements - 1 : 0;
      selectedIds.remove(record.id);
    });
    showSuccessSnackBar(
      context,
      text.t(
        status == 'Approved'
            ? 'Receiving record approved'
            : 'Receiving record rejected',
      ),
    );
    return true;
  }

  Future<bool> reviewCount(
    StockSubmission submission,
    String status,
  ) async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(
        status == 'Approved' ? 'Approve Daily Count?' : 'Reject Daily Count?',
      ),
      details: text.t(
        'This will update the review status of this daily stock count.',
      ),
    );
    if (!confirmed || !mounted) return false;
    final updated = submission.copyWith(
      reviewStatus: status,
      reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
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
        status == 'Approved'
            ? 'Daily count approved'
            : 'Daily count rejected',
      ),
    );
    return true;
  }

  Future<void> bulkReview(String status) async {
    if (selectedIds.isEmpty || !canReviewSelectedStatus) return;
    final selectedCount = selectedIds.length;
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(
        status == 'Approved'
            ? 'Approve $selectedCount records?'
            : 'Reject $selectedCount records?',
      ),
      details: text.t('This will update all selected records.'),
    );
    if (!confirmed || !mounted) return;

    if (isReceiving) {
      final selected = receivingRecords
          .where((item) => selectedIds.contains(item.id))
          .toList();
      final ok = await runStockRequest(context, () async {
        for (final record in selected) {
          await widget.onReviewReceiving(
            record.copyWith(
              reviewStatus: status,
              reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
            ),
          );
        }
      });
      if (!ok || !mounted) return;
      setState(() {
        receivingRecords = receivingRecords
            .where((item) => !selectedIds.contains(item.id))
            .toList();
        totalElements =
            (totalElements - selected.length).clamp(0, totalElements).toInt();
      });
    } else {
      final selected = countRecords
          .where((item) => selectedIds.contains(item.id))
          .toList();
      final updated = selected
          .map(
            (item) => item.copyWith(
              reviewStatus: status,
              reviewNote: status == 'Approved' ? 'Approved.' : 'Rejected.',
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
    }

    setState(() {
      selecting = false;
      selectedIds.clear();
    });
    showSuccessSnackBar(
      context,
      text.t(
        status == 'Approved'
            ? 'Selected records approved'
            : 'Selected records rejected',
      ),
    );
  }

  void showReceivingDetails(StockReceivingRecord record) {
    final text = AppTextScope.of(context);
    final conditionColour = receivingConditionColour(record);
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
                        text.t('Receiving Review'),
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
                            value: record.reviewStatus,
                            valueColour:
                                reviewStatusColour(record.reviewStatus),
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
                if (record.reviewStatus == 'Pending Review') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Reject'),
                          outlined: true,
                          icon: Icons.close_rounded,
                          onPressed: () async {
                            final ok = await reviewReceiving(record, 'Rejected');
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
                            final ok = await reviewReceiving(record, 'Approved');
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
                            value: submission.reviewStatus,
                            valueColour:
                                reviewStatusColour(submission.reviewStatus),
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
                if (submission.reviewStatus == 'Pending Review') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: text.t('Reject'),
                          outlined: true,
                          icon: Icons.close_rounded,
                          onPressed: () async {
                            final ok = await reviewCount(submission, 'Rejected');
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
                            final ok = await reviewCount(submission, 'Approved');
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
    return DropdownButtonFormField<String>(
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
              child: Text(text.t(status)),
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
            onPressed:
                selectedIds.isEmpty ? null : () => bulkReview('Rejected'),
            child: Text(text.t('Reject')),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed:
                selectedIds.isEmpty ? null : () => bulkReview('Approved'),
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
                          isReceiving
                              ? 'Receiving Records'
                              : 'Daily Count Records',
                        ),
                        style: const TextStyle(
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (loaded &&
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
                          isReceiving
                              ? 'No receiving records found.'
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
                        children: isReceiving
                            ? receivingRecords.map((record) {
                                final selected =
                                    selectedIds.contains(record.id);
                                return _ReceivingReviewRow(
                                  record: record,
                                  timerText:
                                      recordDateLabel(record.capturedAt),
                                  statusText: record.reviewStatus,
                                  statusColour:
                                      reviewStatusColour(record.reviewStatus),
                                  conditionColour:
                                      receivingConditionColour(record),
                                  selectMode: selecting,
                                  selectable: canReviewSelectedStatus,
                                  selected: selected,
                                  onTap: () => showReceivingDetails(record),
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
                                  statusText: submission.reviewStatus,
                                  statusColour: reviewStatusColour(
                                    submission.reviewStatus,
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
