import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/people_models.dart';
import '../models/report_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../utils/app_diagnostics.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';

class ReportScreen extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final EastAppUser currentUser;
  final UserRole role;
  final List<StockSku> stockSkus;
  final VoidCallback? onReportChanged;

  const ReportScreen({
    super.key,
    required this.api,
    required this.tenantId,
    required this.currentUser,
    required this.role,
    required this.stockSkus,
    this.onReportChanged,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController heroController;
  ReportDashboard? dashboard;
  bool loading = true;
  int periodDays = 7;
  DateTime? lastUpdatedAt;

  bool get isManagement {
    final role = widget.currentUser.role.systemKey;
    return role == 'OWNER' ||
        role == 'HEAD' ||
        role == 'MANAGER' ||
        role == 'SUPERVISOR';
  }

  bool get canReview {
    final role = widget.currentUser.role.systemKey;
    return role == 'OWNER' || role == 'HEAD' || role == 'MANAGER';
  }

  DateTime get earliestEditableDate {
    final now = DateTime.now();
    final role = widget.currentUser.role.systemKey;
    if (role == 'OWNER' || role == 'HEAD') {
      return DateTime(2020, 1, 1);
    }
    if (role == 'MANAGER' || role == 'SUPERVISOR') {
      return DateTime(now.year, now.month, now.day).subtract(
        const Duration(days: 7),
      );
    }
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    unawaited(loadDashboard());
  }

  @override
  void dispose() {
    heroController.dispose();
    super.dispose();
  }

  Future<void> loadDashboard({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    if (showLoading && mounted) setState(() => loading = true);
    final cacheKey = EastAppApi.reportDashboardCacheKey(
      widget.tenantId,
      periodDays,
    );
    try {
      final value = await widget.api.reportDashboard(
        days: periodDays,
        tenantId: widget.tenantId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        dashboard = value;
        lastUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
        loading = false;
      });
    } on EastAppApiException {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> handleChanged() async {
    widget.onReportChanged?.call();
    await widget.api.invalidateFeatureCache(
      'tenant:${widget.tenantId}:report:',
    );
    await loadDashboard(showLoading: false, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final data = dashboard;
    return RefreshIndicator(
      onRefresh: () => loadDashboard(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          _ReportHero(
            controller: heroController,
            dashboard: data,
            loading: loading,
            periodDays: periodDays,
            isManagement: isManagement,
            onPeriodChanged: (value) {
              if (value == periodDays) return;
              setState(() {
                periodDays = value;
                dashboard = null;
                lastUpdatedAt = null;
                loading = true;
              });
              unawaited(loadDashboard());
            },
            onRefresh: loading ? null : () => loadDashboard(forceRefresh: true),
            lastUpdatedAt: lastUpdatedAt,
            onApprovals: canReview ? showApprovals : null,
          ),
          const SizedBox(height: 12),
          if (loading && data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (isManagement && data?.trend.isNotEmpty == true) ...[
              _AnimatedSection(
                delay: 0,
                child: _TrendPanel(points: data!.trend),
              ),
              const SizedBox(height: 12),
            ],
            _AnimatedSection(
              delay: 60,
              child: _ReportCard(
                title: 'Sales',
                subtitle: isManagement
                    ? 'Daily revenue, productivity and void-control intelligence'
                    : 'Record every void bill with compulsory photo evidence',
                icon: Icons.point_of_sale_rounded,
                accent: AppColours.blue,
                metric: isManagement
                    ? 'RM ${_money(data?.sales?.netSalesRm ?? 0)}'
                    : 'Evidence',
                metricLabel: isManagement ? '$periodDays-day total sales' : 'Void-control reporting',
                badges: isManagement
                    ? [
                        _CardBadge(
                          '${(data?.workforce?.averageStaffPerDay ?? 0).toStringAsFixed(1)} avg staff/day',
                          Icons.groups_2_outlined,
                        ),
                        _CardBadge(
                          '${(data?.sales?.voidRatePercent ?? 0).toStringAsFixed(1)}% void exposure',
                          Icons.receipt_long_outlined,
                        ),
                      ]
                    : const [
                        _CardBadge('Photo required', Icons.camera_alt_outlined),
                      ],
                onTap: isManagement
                    ? showSalesHistory
                    : () => showVoidBill(),
                onAction: isManagement ? () => showSales() : null,
                actionTooltip: 'Create today’s Sales Report',
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedSection(
              delay: 120,
              child: _ReportCard(
                title: 'Inventory Intelligence',
                subtitle: isManagement
                    ? 'Calculated stock health, capital exposure and reorder priorities'
                    : 'Management-only calculated business intelligence',
                icon: Icons.hub_rounded,
                accent: AppColours.purple,
                metric: isManagement
                    ? '${(data?.inventory?.healthScorePercent ?? 0).toStringAsFixed(0)}%'
                    : 'Restricted',
                metricLabel: isManagement ? 'Inventory health score' : 'Management view',
                badges: isManagement
                    ? [
                        _CardBadge(
                          '${data?.inventory?.outOfStockCount ?? 0} out',
                          Icons.error_outline_rounded,
                        ),
                        _CardBadge(
                          '${data?.inventory?.lowStockCount ?? 0} low',
                          Icons.trending_down_rounded,
                        ),
                      ]
                    : const [],
                onTap: isManagement
                    ? showInventory
                    : () => showTemporaryDisabledMessage(context),
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedSection(
              delay: 180,
              child: _ReportCard(
                title: 'Waste',
                subtitle: 'Capture evidence and calculate the real cost of wastage',
                icon: Icons.delete_sweep_rounded,
                accent: AppColours.orange,
                metric: isManagement
                    ? 'RM ${_money(data?.waste?.periodLossRm ?? 0)}'
                    : 'Submit',
                metricLabel: isManagement
                    ? '$periodDays-day estimated loss'
                    : 'Waste evidence',
                badges: isManagement && data?.waste != null
                    ? [
                        _CardBadge(
                          '${data!.waste!.wasteToNetSalesPercent.toStringAsFixed(1)}% of sales',
                          Icons.percent_rounded,
                        ),
                        _CardBadge(
                          data.waste!.topWasteItem,
                          Icons.warning_amber_rounded,
                        ),
                      ]
                    : const [
                        _CardBadge('Photo required', Icons.camera_alt_outlined),
                      ],
                onTap: showWaste,
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedSection(
              delay: 240,
              child: _ReportCard(
                title: 'Daily Photos',
                subtitle: 'Every staff submits at least 5 photos; manager approves the batch',
                icon: Icons.photo_library_rounded,
                accent: AppColours.green,
                metric: isManagement
                    ? '${data?.dailyPhotos.completedStaffCount ?? 0}/${data?.dailyPhotos.requiredStaffCount ?? 0}'
                    : '${data?.dailyPhotos.currentUserPhotoCount ?? 0}/${data?.dailyPhotos.minimumRequired ?? 5}',
                metricLabel: isManagement ? 'Staff completed today' : 'Your photos today',
                badges: [
                  _CardBadge(
                    '${(data?.dailyPhotos.completionRatePercent ?? 0).toStringAsFixed(0)}% complete',
                    Icons.task_alt_rounded,
                  ),
                ],
                onTap: showDailyPhotos,
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedSection(
              delay: 300,
              child: _ReportCard(
                title: 'Complaints',
                subtitle: 'Track customer profile, action, compensation and resolution',
                icon: Icons.support_agent_rounded,
                accent: AppColours.red,
                metric: isManagement
                    ? '${data?.complaints?.openCount ?? 0}'
                    : 'Report',
                metricLabel: isManagement ? 'Open complaints' : 'Customer complaint',
                badges: isManagement && data?.complaints != null
                    ? [
                        _CardBadge(
                          '${data!.complaints!.resolutionRatePercent.toStringAsFixed(0)}% resolved',
                          Icons.done_all_rounded,
                        ),
                        _CardBadge(
                          'RM ${_money(data.complaints!.compensationInPeriodRm)} comp.',
                          Icons.payments_outlined,
                        ),
                      ]
                    : const [
                        _CardBadge('Photo required', Icons.camera_alt_outlined),
                      ],
                onTap: showComplaints,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> showSalesHistory() async {
    if (!mounted) return;
    await _showReportSheet<void>(
      context,
      title: 'Sales Reports',
      icon: Icons.receipt_long_rounded,
      builder: (_) => _SalesHistorySheet(
        api: widget.api,
        tenantId: widget.tenantId,
      ),
    );
  }

  Future<void> showSales({DateTime? date}) async {
    final reportDate = date ?? DateTime.now();
    SalesReport? report;
    try {
      report = await _runReportAction<SalesReport>(
        context,
        () => widget.api.salesReport(reportDate),
      );
    } on EastAppApiException {
      return;
    }
    if (!mounted || report == null) return;
    await _showReportSheet<void>(
      context,
      title: 'Sales Report',
      icon: Icons.point_of_sale_rounded,
      builder: (_) => _SalesSheet(
        api: widget.api,
        initialReport: report!,
        earliestDate: earliestEditableDate,
        onChanged: handleChanged,
      ),
    );
  }

  Future<void> showVoidBill({DateTime? reportDate}) async {
    await _showReportSheet<void>(
      context,
      title: 'Void Bill Evidence',
      icon: Icons.receipt_long_rounded,
      builder: (_) => _VoidBillForm(
        api: widget.api,
        reportDate: reportDate ?? DateTime.now(),
        onSaved: handleChanged,
      ),
    );
  }

  Future<void> showInventory() async {
    final value = dashboard?.inventory;
    if (value == null) return;
    await _showReportSheet<void>(
      context,
      title: 'Inventory Intelligence',
      icon: Icons.hub_rounded,
      builder: (_) => _InventorySheet(data: value),
    );
  }

  Future<void> showWaste() async {
    List<WasteReport> records;
    try {
      final loaded = await _runReportAction<List<WasteReport>>(
        context,
        () => widget.api.wasteReports(
          from: DateTime.now().subtract(const Duration(days: 29)),
          to: DateTime.now(),
        ),
      );
      if (loaded == null) return;
      records = loaded;
    } on EastAppApiException {
      return;
    }
    if (!mounted) return;
    await _showReportSheet<void>(
      context,
      title: 'Waste Intelligence',
      icon: Icons.delete_sweep_rounded,
      builder: (sheetContext) => _WasteSheet(
        api: widget.api,
        records: records,
        stockSkus: widget.stockSkus.where((sku) => sku.active).toList(),
        isManagement: isManagement,
        onChanged: handleChanged,
        onCreate: () async {
          Navigator.of(sheetContext).pop();
          await _showReportSheet<void>(
            context,
            title: 'New Waste Record',
            icon: Icons.add_a_photo_outlined,
            builder: (_) => _WasteForm(
              api: widget.api,
              stockSkus: widget.stockSkus.where((sku) => sku.active).toList(),
              earliestDate: earliestEditableDate,
              onSaved: handleChanged,
            ),
          );
        },
      ),
    );
  }

  Future<void> showDailyPhotos() async {
    DailyPhotoReport report;
    try {
      final loaded = await _runReportAction<DailyPhotoReport>(
        context,
        () => widget.api.dailyPhotoReport(date: DateTime.now()),
      );
      if (loaded == null) return;
      report = loaded;
    } on EastAppApiException {
      return;
    }
    if (!mounted) return;
    await _showReportSheet<void>(
      context,
      title: 'Daily Photos',
      icon: Icons.photo_library_rounded,
      builder: (_) => _DailyPhotosSheet(
        api: widget.api,
        initialReport: report,
        earliestDate: earliestEditableDate,
        onChanged: handleChanged,
      ),
    );
  }

  Future<void> showComplaints() async {
    List<ComplaintReport> records;
    try {
      final loaded = await _runReportAction<List<ComplaintReport>>(
        context,
        () => widget.api.complaintReports(
          from: DateTime.now().subtract(const Duration(days: 89)),
          to: DateTime.now(),
        ),
      );
      if (loaded == null) return;
      records = loaded;
    } on EastAppApiException {
      return;
    }
    if (!mounted) return;
    await _showReportSheet<void>(
      context,
      title: 'Complaints',
      icon: Icons.support_agent_rounded,
      builder: (sheetContext) => _ComplaintSheet(
        api: widget.api,
        records: records,
        isManagement: isManagement,
        onChanged: handleChanged,
        onCreate: () async {
          Navigator.of(sheetContext).pop();
          await _showReportSheet<void>(
            context,
            title: 'New Complaint',
            icon: Icons.add_comment_rounded,
            builder: (_) => _ComplaintForm(
              api: widget.api,
              earliestDate: earliestEditableDate,
              onSaved: handleChanged,
            ),
          );
        },
      ),
    );
  }

  Future<void> showApprovals() async {
    List<ReportApproval> approvals;
    try {
      final loaded = await _runReportAction<List<ReportApproval>>(
        context,
        widget.api.reportApprovals,
      );
      if (loaded == null) return;
      approvals = loaded;
    } on EastAppApiException {
      return;
    }
    if (!mounted) return;
    await _showReportSheet<void>(
      context,
      title: 'Report Approvals',
      icon: Icons.fact_check_rounded,
      builder: (_) => _ApprovalsSheet(
        api: widget.api,
        initialApprovals: approvals,
        onChanged: handleChanged,
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  final AnimationController controller;
  final ReportDashboard? dashboard;
  final bool loading;
  final int periodDays;
  final bool isManagement;
  final ValueChanged<int> onPeriodChanged;
  final VoidCallback? onRefresh;
  final DateTime? lastUpdatedAt;
  final VoidCallback? onApprovals;

  const _ReportHero({
    required this.controller,
    required this.dashboard,
    required this.loading,
    required this.periodDays,
    required this.isManagement,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.lastUpdatedAt,
    required this.onApprovals,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final shift = controller.value;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(-1 + shift * .35, -1),
              end: Alignment(1, 1 - shift * .25),
              colors: const [
                Color(0xFF07011D),
                Color(0xFF1237B8),
                Color(0xFF7B2CFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColours.blue.withOpacity(.22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -38 + shift * 22,
                top: -42,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.08),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Intelligence',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTextSize.s24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Operational evidence transformed into business decisions',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: AppTextSize.s13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isManagement) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Refresh report data',
                              onPressed: onRefresh,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(.16),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white.withOpacity(.10),
                                disabledForegroundColor: Colors.white70,
                              ),
                              icon: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                            Text(
                              _lastUpdatedText(lastUpdatedAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: AppTextSize.s10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isManagement)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 10) / 2;
                        final sales = dashboard?.sales;
                        final countCoverage = dashboard?.countCoverage;
                        final workforce = dashboard?.workforce;
                        final metrics = <Widget>[
                          _HeroMetric(
                            label: '$periodDays-Day Sales',
                            value: loading && dashboard == null
                                ? '—'
                                : 'RM ${_money(sales?.netSalesRm ?? 0)}',
                          ),
                          _HeroMetric(
                            label: 'Avg Sales / Reporting Day',
                            value: loading && dashboard == null
                                ? '—'
                                : 'RM ${_money(sales?.averageSalesPerReportingDayRm ?? 0)}',
                          ),
                          _HeroMetric(
                            label: 'Count Coverage',
                            value: loading && dashboard == null
                                ? '—'
                                : '${(countCoverage?.countCoveragePercent ?? 0).toStringAsFixed(0)}%',
                          ),
                          _HeroMetric(
                            label: 'Total Labour Hours',
                            value: loading && dashboard == null
                                ? '—'
                                : '${(workforce?.totalLabourHours ?? 0).toStringAsFixed(2)} h',
                          ),
                          _HeroMetric(
                            label: 'Sales / Labour Hour',
                            value: loading && dashboard == null ||
                                    (workforce?.totalLabourHours ?? 0) <= 0
                                ? '—'
                                : 'RM ${_money(workforce?.salesPerLabourHourRm ?? 0)}',
                          ),
                          _HeroMetric(
                            label: 'Avg Staff / Day',
                            value: loading && dashboard == null
                                ? '—'
                                : (workforce?.averageStaffPerDay ?? 0).toStringAsFixed(1),
                          ),
                        ];
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: metrics
                              .map((item) => SizedBox(width: width, child: item))
                              .toList(growable: false),
                        );
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMetric(
                            label: 'Daily Photos',
                            value:
                                '${dashboard?.dailyPhotos.currentUserPhotoCount ?? 0}/${dashboard?.dailyPhotos.minimumRequired ?? 5}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Status',
                            value: dashboard?.dailyPhotos.currentUserComplete == true
                                ? 'Complete'
                                : 'Pending',
                          ),
                        ),
                      ],
                    ),
                  if (isManagement &&
                      ((dashboard?.workforce?.openShiftCount ?? 0) > 0 ||
                          (dashboard?.countCoverage?.missingCountSkuDays ?? 0) > 0 ||
                          (dashboard?.workforce?.staffCountMismatchDays ?? 0) > 0)) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        [
                          if ((dashboard?.workforce?.openShiftCount ?? 0) > 0)
                            '${dashboard!.workforce!.openShiftCount} open shift(s)',
                          if ((dashboard?.countCoverage?.missingCountSkuDays ?? 0) > 0)
                            '${dashboard!.countCoverage!.missingCountSkuDays} missing SKU-day count(s)',
                          if ((dashboard?.workforce?.staffCountMismatchDays ?? 0) > 0)
                            'Attendance mismatch: ${dashboard!.workforce!.staffCountMismatchDays} day(s)',
                        ].join(' · '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  if (isManagement) ...[
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final periodSelector = SegmentedButton<int>(
                          showSelectedIcon: false,
                          expandedInsets: EdgeInsets.zero,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : Colors.white.withOpacity(.10),
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? AppColours.blueDark
                                  : Colors.white,
                            ),
                            side: WidgetStateProperty.all(
                              BorderSide(color: Colors.white.withOpacity(.18)),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(value: 7, label: Text('7D')),
                            ButtonSegment(value: 14, label: Text('14D')),
                            ButtonSegment(value: 30, label: Text('30D')),
                          ],
                          selected: {periodDays},
                          onSelectionChanged: (values) =>
                              onPeriodChanged(values.first),
                        );
                        final approvalButton = onApprovals == null
                            ? null
                            : _ApprovalActionButton(
                                count: dashboard?.pendingApprovals ?? 0,
                                onPressed: onApprovals!,
                              );
                        if (approvalButton == null) return periodSelector;
                        if (constraints.maxWidth < 390) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              periodSelector,
                              const SizedBox(height: 10),
                              approvalButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: periodSelector),
                            const SizedBox(width: 12),
                            Expanded(child: approvalButton),
                          ],
                        );
                      },
                    ),
                  ],

                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalActionButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _ApprovalActionButton({
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Approvals'),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColours.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTextSize.s10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 620),
            builder: (_, animation, child) => Opacity(
              opacity: animation,
              child: Transform.translate(
                offset: Offset(0, 5 * (1 - animation)),
                child: child,
              ),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTextSize.s20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final int delay;
  final Widget child;

  const _AnimatedSection({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 480 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String metric;
  final String metricLabel;
  final List<_CardBadge> badges;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String? actionTooltip;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.metric,
    required this.metricLabel,
    required this.badges,
    required this.onTap,
    this.onAction,
    this.actionTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          AppFeedback.tap();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColours.border),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withOpacity(.65)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: AppTextSize.s19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTextSize.s12,
                            height: 1.25,
                            color: AppColours.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onAction != null)
                    IconButton.filledTonal(
                      tooltip: actionTooltip,
                      onPressed: () {
                        AppFeedback.tap();
                        onAction!();
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTextSize.s26,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                        Text(
                          metricLabel,
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badges.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: badges,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _CardBadge(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColours.mutedBox,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColours.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSize.s10,
                fontWeight: FontWeight.w800,
                color: AppColours.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  final List<ReportTrendPoint> points;

  const _TrendPanel({required this.points});

  @override
  Widget build(BuildContext context) {
    final totalSales = points.fold<double>(0, (sum, item) => sum + item.netSalesRm);
    final totalLeakage = points.fold<double>(
      0,
      (sum, item) => sum + item.voidAmountRm + item.wasteLossRm,
    );
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales vs Operational Leakage',
                  style: TextStyle(
                    fontSize: AppTextSize.s17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${points.length} days',
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'RM ${_money(totalSales)} sales · RM ${_money(totalLeakage)} void + waste',
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (_, progress, __) => CustomPaint(
                painter: _TrendChartPainter(points, progress),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(colour: AppColours.blue, label: 'Total Sales'),
              SizedBox(width: 14),
              _LegendDot(colour: AppColours.red, label: 'Void'),
              SizedBox(width: 14),
              _LegendDot(colour: AppColours.orange, label: 'Waste'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color colour;
  final String label;

  const _LegendDot({required this.colour, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTextSize.s10,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<ReportTrendPoint> points;
  final double progress;

  _TrendChartPainter(this.points, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = points
        .map((item) => math.max(
              item.netSalesRm,
              math.max(item.voidAmountRm, item.wasteLossRm),
            ))
        .fold<double>(1, math.max);
    final chart = Rect.fromLTWH(6, 6, size.width - 12, size.height - 18);
    final gridPaint = Paint()
      ..color = AppColours.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final step = points.length == 1 ? chart.width : chart.width / (points.length - 1);
    final salesPath = Path();
    final voidPath = Path();
    final wastePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = chart.left + step * i;
      final salesY = chart.bottom -
          chart.height * (points[i].netSalesRm / maxValue) * progress;
      final voidY = chart.bottom -
          chart.height * (points[i].voidAmountRm / maxValue) * progress;
      final wasteY = chart.bottom -
          chart.height * (points[i].wasteLossRm / maxValue) * progress;
      if (i == 0) {
        salesPath.moveTo(x, salesY);
        voidPath.moveTo(x, voidY);
        wastePath.moveTo(x, wasteY);
      } else {
        salesPath.lineTo(x, salesY);
        voidPath.lineTo(x, voidY);
        wastePath.lineTo(x, wasteY);
      }
    }
    canvas.drawPath(
      salesPath,
      Paint()
        ..color = AppColours.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      voidPath,
      Paint()
        ..color = AppColours.red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      wastePath,
      Paint()
        ..color = AppColours.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.points != points;
  }
}

final Set<NavigatorState> _activeReportActions = <NavigatorState>{};

Future<T?> _runReportAction<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (!_activeReportActions.add(navigator)) return null;
  try {
    return await action();
  } finally {
    _activeReportActions.remove(navigator);
  }
}

Future<T?> _showReportSheet<T>(
  BuildContext context, {
  required String title,
  required IconData icon,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final keyboardHeight = media.viewInsets.bottom;
      final availableHeight = media.size.height - keyboardHeight;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(sheetContext).unfocus(),
          child: SizedBox(
            height: math.max(320.0, availableHeight * .92),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColours.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: AppColours.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColours.blue.withOpacity(.10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(icon, color: AppColours.blue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s20,
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
                      ),
                      const Divider(height: 1),
                      Expanded(child: builder(sheetContext)),
                    ],
                  ),
                ),
                if (keyboardHeight > 0)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: () => FocusScope.of(sheetContext).unfocus(),
                      icon: const Icon(Icons.keyboard_hide_rounded),
                      label: const Text('Done'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SalesHistorySheet extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;

  const _SalesHistorySheet({
    required this.api,
    required this.tenantId,
  });

  @override
  State<_SalesHistorySheet> createState() => _SalesHistorySheetState();
}

class _SalesHistorySheetState extends State<_SalesHistorySheet> {
  late DateTimeRange selectedRange;
  List<SalesReport> records = const [];
  bool loading = false;
  bool hasLoaded = false;
  DateTime? updatedAt;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    selectedRange = DateTimeRange(
      start: date.subtract(const Duration(days: 6)),
      end: date,
    );
  }

  String get rangeLabel =>
      '${_formatDate(selectedRange.start)} — ${_formatDate(selectedRange.end)}';

  String get cacheKey => EastAppApi.salesHistoryCacheKey(
        widget.tenantId,
        selectedRange.start,
        selectedRange.end,
      );

  Future<void> selectDateRange() async {
    if (loading) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2, 1, 1),
      lastDate: today,
      initialDateRange: selectedRange,
      helpText: 'Select Sales report dates',
      saveText: 'Use Range',
    );
    if (selected == null || !mounted) return;
    final inclusiveDays = selected.end.difference(selected.start).inDays + 1;
    if (inclusiveDays > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a maximum of 30 days.')),
      );
      return;
    }
    setState(() {
      selectedRange = selected;
      records = const [];
      hasLoaded = false;
      updatedAt = widget.api.featureCacheUpdatedAt(cacheKey);
    });
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final value = await widget.api.salesHistory(
        from: selectedRange.start,
        to: selectedRange.end,
        tenantId: widget.tenantId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        records = value;
        hasLoaded = true;
        updatedAt = widget.api.featureCacheUpdatedAt(cacheKey);
      });
    } on EastAppApiException {
      // Keep the previously loaded range visible after a handled API failure.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openRecord(SalesReport report) async {
    await _showReportSheet<void>(
      context,
      title: 'Sales · ${_formatDate(report.reportDate)}',
      icon: Icons.receipt_long_rounded,
      builder: (_) => _SalesSubmittedDetail(api: widget.api, report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: hasLoaded ? () => load(forceRefresh: true) : () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF071A3B), Color(0xFF244DFF), Color(0xFF6A35D8)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales Report Loader',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTextSize.s20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Select up to 30 days, then load submitted reports.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: AppTextSize.s12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasLoaded)
                      IconButton.filledTonal(
                        tooltip: 'Refresh loaded range',
                        onPressed: loading ? null : () => load(forceRefresh: true),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(.16),
                          foregroundColor: Colors.white,
                        ),
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : selectDateRange,
                    icon: const Icon(Icons.date_range_rounded),
                    label: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rangeLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(.35)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : () => load(),
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      loading
                          ? 'Loading...'
                          : hasLoaded
                              ? 'Reload Report'
                              : 'Load Report',
                    ),
                  ),
                ),
                if (hasLoaded) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lastUpdatedText(updatedAt),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: AppTextSize.s10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!hasLoaded)
            WhiteCard(
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.manage_search_rounded,
                      size: 48,
                      color: AppColours.textMuted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Select a date range, then tap Load Report.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColours.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (records.isEmpty)
            WhiteCard(
              child: const Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppColours.textMuted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No submitted Sales reports in this date range',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            )
          else
            ...records.map(
              (report) => WhiteCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openRecord(report),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _workflowColour(report.workflowStatus)
                                  .withOpacity(.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _workflowIcon(report.workflowStatus),
                              color: _workflowColour(report.workflowStatus),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(report.reportDate),
                                  style: const TextStyle(
                                    fontSize: AppTextSize.s16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'RM ${_money(report.totalSalesRm)} · ${report.submittedByName ?? 'Unknown'}',
                                  style: const TextStyle(
                                    color: AppColours.textMuted,
                                    fontSize: AppTextSize.s12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _WorkflowPill(status: report.workflowStatus),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SalesSubmittedDetail extends StatelessWidget {
  final EastAppApi api;
  final SalesReport report;

  const _SalesSubmittedDetail({required this.api, required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        _StatusBanner(status: report.workflowStatus, note: report.reviewNote),
        const SizedBox(height: 12),
        _MetricGrid(
          items: [
            _MetricData('Cash Total', 'RM ${_money(report.cashTotalRm)}', AppColours.green),
            _MetricData('eWallet Total', 'RM ${_money(report.ewalletTotalRm)}', AppColours.purple),
            _MetricData('Gross Delivery', 'RM ${_money(report.foodDeliverySalesRm)}', AppColours.orange),
            _MetricData('Net Delivery (60%)', 'RM ${_money(report.netFoodDeliverySalesRm)}', AppColours.blue),
            _MetricData('Platform Commission', 'RM ${_money(report.estimatedPlatformCommissionRm)}', AppColours.red),
            _MetricData('Total Sales', 'RM ${_money(report.totalSalesRm)}', AppColours.blue),
            _MetricData('Staff on Duty', '${report.staffOnDuty}', AppColours.purple),
            _MetricData('Sales / Staff-Day', 'RM ${_money(report.salesPerStaffRm)}', AppColours.blue),
            _MetricData('Void Total', 'RM ${_money(report.voidTotalRm)}', AppColours.red),
            _MetricData('Void Exposure', '${report.voidExposurePercent.toStringAsFixed(1)}%', AppColours.orange),
          ],
        ),
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submission Details',
                style: TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _approvalDetailRow('Report Date', _formatDate(report.reportDate)),
              _approvalDetailRow('Submitted By', report.submittedByName ?? '-'),
              _approvalDetailRow(
                'Submitted At',
                report.submittedAt == null ? '-' : _formatDateTime(report.submittedAt!),
              ),
              _approvalDetailRow('Cash Received By', report.cashReceivedBy),
              _approvalDetailRow('Status', _titleCase(report.workflowStatus)),
              if (report.reviewedByName != null)
                _approvalDetailRow('Reviewed By', report.reviewedByName!),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Void Bills',
                style: TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (report.voidBills.isEmpty)
                const Text('No void bills recorded.', style: TextStyle(color: AppColours.textMuted))
              else
                ...report.voidBills.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _RemoteReportImage(
                            api: api,
                            storageKey: item.photoStorageKey,
                            width: double.infinity,
                            height: 190,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.billNumber} · RM ${_money(item.amountRm)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(item.reason, style: const TextStyle(color: AppColours.textMuted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkflowPill extends StatelessWidget {
  final String status;
  const _WorkflowPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colour = _workflowColour(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status == 'SUBMITTED' ? 'Pending' : _titleCase(status),
        style: TextStyle(
          color: colour,
          fontSize: AppTextSize.s10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _workflowColour(String status) => switch (status.toUpperCase()) {
      'APPROVED' => AppColours.green,
      'REJECTED' => AppColours.red,
      'SUBMITTED' => AppColours.orange,
      _ => AppColours.blue,
    };

IconData _workflowIcon(String status) => switch (status.toUpperCase()) {
      'APPROVED' => Icons.verified_rounded,
      'REJECTED' => Icons.cancel_rounded,
      'SUBMITTED' => Icons.hourglass_top_rounded,
      _ => Icons.edit_note_rounded,
    };

class _SalesSheet extends StatefulWidget {
  final EastAppApi api;
  final SalesReport initialReport;
  final DateTime earliestDate;
  final Future<void> Function() onChanged;

  const _SalesSheet({
    required this.api,
    required this.initialReport,
    required this.earliestDate,
    required this.onChanged,
  });

  @override
  State<_SalesSheet> createState() => _SalesSheetState();
}

class _SalesSheetState extends State<_SalesSheet> {
  late SalesReport report;
  late final TextEditingController cashTotalController;
  late final TextEditingController cashReceivedByController;
  late final TextEditingController foodDeliveryController;
  late final TextEditingController ewalletController;
  late final TextEditingController staffOnDutyController;
  late final TextEditingController voidBillNumberController;
  late final TextEditingController voidAmountController;
  late final TextEditingController voidReasonController;
  String? validation;
  String? voidValidation;
  String? voidPhotoPath;
  bool voidExpanded = false;

  @override
  void initState() {
    super.initState();
    report = widget.initialReport;
    cashTotalController = TextEditingController(text: _editableNumber(report.cashTotalRm));
    cashReceivedByController = TextEditingController(text: report.cashReceivedBy);
    foodDeliveryController = TextEditingController(text: _editableNumber(report.foodDeliverySalesRm));
    ewalletController = TextEditingController(text: _editableNumber(report.ewalletTotalRm));
    staffOnDutyController = TextEditingController(
      text: report.staffOnDuty == 0 ? '' : '${report.staffOnDuty}',
    );
    voidBillNumberController = TextEditingController();
    voidAmountController = TextEditingController();
    voidReasonController = TextEditingController();
  }

  @override
  void dispose() {
    cashTotalController.dispose();
    cashReceivedByController.dispose();
    foodDeliveryController.dispose();
    ewalletController.dispose();
    staffOnDutyController.dispose();
    voidBillNumberController.dispose();
    voidAmountController.dispose();
    voidReasonController.dispose();
    super.dispose();
  }

  void applyReport(SalesReport value) {
    report = value;
    cashTotalController.text = _editableNumber(value.cashTotalRm);
    cashReceivedByController.text = value.cashReceivedBy;
    foodDeliveryController.text = _editableNumber(value.foodDeliverySalesRm);
    ewalletController.text = _editableNumber(value.ewalletTotalRm);
    staffOnDutyController.text = value.staffOnDuty == 0 ? '' : '${value.staffOnDuty}';
    validation = null;
    clearVoidDraft(collapse: true);
  }

  bool get hasVoidDraft =>
      voidPhotoPath != null ||
      voidBillNumberController.text.trim().isNotEmpty ||
      voidAmountController.text.trim().isNotEmpty ||
      voidReasonController.text.trim().isNotEmpty;

  void clearVoidDraft({bool collapse = false}) {
    voidBillNumberController.clear();
    voidAmountController.clear();
    voidReasonController.clear();
    voidPhotoPath = null;
    voidValidation = null;
    if (collapse) voidExpanded = false;
  }

  Future<void> captureVoidPhoto() async {
    FocusScope.of(context).unfocus();
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReportCameraPage(title: 'Void Bill Photo'),
      ),
    );
    if (!mounted || path == null) return;
    setState(() {
      voidPhotoPath = path;
      voidValidation = null;
      voidExpanded = true;
    });
  }

  Future<void> recordVoidBill() async {
    final billNumber = voidBillNumberController.text.trim();
    final reason = voidReasonController.text.trim();
    final amount = double.tryParse(voidAmountController.text.trim());
    if (voidPhotoPath == null) {
      setState(() {
        voidExpanded = true;
        voidValidation = 'Take a clear photo of the void bill.';
      });
      return;
    }
    if (billNumber.isEmpty) {
      setState(() {
        voidExpanded = true;
        voidValidation = 'Bill number is compulsory.';
      });
      return;
    }
    if (report.voidBills.any(
      (item) => item.billNumber.trim().toLowerCase() == billNumber.toLowerCase(),
    )) {
      setState(() {
        voidExpanded = true;
        voidValidation = 'This bill number is already recorded.';
      });
      return;
    }
    if (reason.isEmpty) {
      setState(() {
        voidExpanded = true;
        voidValidation = 'Void reason is compulsory.';
      });
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() {
        voidExpanded = true;
        voidValidation = 'Enter a valid void amount.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final confirmed = await confirmDataChange(
      context,
      action: 'Record this void bill?',
      details:
          'Bill $billNumber · RM ${_money(amount)}. The current Sales form values will stay on this page.',
    );
    if (!confirmed || !mounted) return;
    try {
      final refreshed = await _runReportAction<SalesReport>(context, () async {
        final storageKey = await widget.api.uploadReportImage(voidPhotoPath!);
        await widget.api.addSalesVoidBill(
          reportDate: report.reportDate,
          billNumber: billNumber,
          reason: reason,
          amountRm: amount,
          photoStorageKey: storageKey,
        );
        final value = await widget.api.salesReport(report.reportDate);
        await widget.onChanged();
        return value;
      });
      if (!mounted || refreshed == null) return;
      setState(() {
        report = refreshed;
        clearVoidDraft(collapse: true);
      });
      showSuccessSnackBar(context, 'Void bill recorded');
    } on EastAppApiException {
      return;
    }
  }

  Widget buildVoidBillsSection(bool editable) {
    final count = report.voidBills.length;
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => voidExpanded = !voidExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColours.red.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColours.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Void Bills (Optional)',
                          style: TextStyle(
                            fontSize: AppTextSize.s17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          count == 0
                              ? 'Expand only when a bill was voided.'
                              : '$count void bill${count == 1 ? '' : 's'} recorded',
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColours.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: voidExpanded ? .5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: voidExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      if (report.voidBills.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'No void bills recorded.',
                            style: TextStyle(
                              color: AppColours.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else ...[
                        ...report.voidBills.map(
                          (item) => _VoidBillRow(api: widget.api, item: item),
                        ),
                        if (editable) const SizedBox(height: 8),
                      ],
                      if (editable) ...[
                        _EvidenceCapture(
                          photoPath: voidPhotoPath,
                          title: 'Void Bill Photo',
                          subtitle:
                              'Capture the full bill including number and amount.',
                          onCapture: captureVoidPhoto,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: voidBillNumberController,
                          textInputAction: TextInputAction.next,
                          decoration:
                              AppInputStyle.decoration('e.g. V-001283').copyWith(
                            labelText: 'Bill Number',
                            prefixIcon: const Icon(
                              Icons.confirmation_number_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _AmountField(
                          controller: voidAmountController,
                          label: 'Void Amount',
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: voidReasonController,
                          minLines: 3,
                          maxLines: 5,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: AppInputStyle.decoration(
                            'Explain why the bill was voided',
                          ).copyWith(
                            labelText: 'Reason',
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (voidValidation != null) ...[
                          const SizedBox(height: 10),
                          _ValidationText(voidValidation!),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(clearVoidDraft),
                                icon: const Icon(Icons.clear_rounded),
                                label: const Text('Clear'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: recordVoidBill,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text('Record'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> selectDate() async {
    final selected = await _pickReportDate(
      context,
      initialDate: report.reportDate,
      earliestDate: widget.earliestDate,
    );
    if (selected == null || _sameDate(selected, report.reportDate) || !mounted) return;
    final confirmed = await confirmDataChange(
      context,
      action: 'Switch sales report date?',
      details: 'Any unsaved values on this screen will be replaced.',
    );
    if (!confirmed || !mounted) return;
    try {
      final loaded = await _runReportAction<SalesReport>(
        context,
        () => widget.api.salesReport(selected),
      );
      if (!mounted || loaded == null) return;
      setState(() => applyReport(loaded));
    } on EastAppApiException {
      return;
    }
  }

  ({double cashTotal, double foodDelivery, double ewallet, int staffOnDuty, String cashReceivedBy})? validateInput() {
    final cashText = cashTotalController.text.trim();
    final deliveryText = foodDeliveryController.text.trim();
    final ewalletText = ewalletController.text.trim();
    final staffText = staffOnDutyController.text.trim();
    final cashReceivedBy = cashReceivedByController.text.trim();
    if (cashText.isEmpty || deliveryText.isEmpty || ewalletText.isEmpty) {
      setState(() => validation = 'Cash Total, Gross Food Delivery Sales and eWallet Total are required. Enter 0 when a payment channel has no sales.');
      return null;
    }
    final cashTotal = double.tryParse(cashText);
    final foodDelivery = double.tryParse(deliveryText);
    final ewallet = double.tryParse(ewalletText);
    if (cashTotal == null || cashTotal < 0 ||
        foodDelivery == null || foodDelivery < 0 ||
        ewallet == null || ewallet < 0) {
      setState(() => validation = 'Payment totals must be valid non-negative amounts.');
      return null;
    }
    if (cashReceivedBy.isEmpty) {
      setState(() => validation = 'Cash Received By is required.');
      return null;
    }
    final staffOnDuty = int.tryParse(staffText);
    if (staffText.isEmpty || staffOnDuty == null || staffOnDuty < 1) {
      setState(() => validation = 'Staff on Duty is required and must be at least 1.');
      return null;
    }
    return (
      cashTotal: cashTotal,
      foodDelivery: foodDelivery,
      ewallet: ewallet,
      staffOnDuty: staffOnDuty,
      cashReceivedBy: cashReceivedBy,
    );
  }

  Future<void> submit() async {
    if (hasVoidDraft) {
      setState(() {
        voidExpanded = true;
        voidValidation =
            'Finish recording this void bill, or clear the optional fields before submitting Sales.';
      });
      return;
    }
    final input = validateInput();
    if (input == null) return;
    FocusScope.of(context).unfocus();
    final total = input.cashTotal + (input.foodDelivery * .60) + input.ewallet;
    final confirmed = await confirmDataChange(
      context,
      action: 'Submit sales report for approval?',
      details: 'Estimated Total Sales RM ${_money(total)}. Only 60% of Gross Food Delivery Sales is recognised after estimated platform commission. Sales fields and void bills will be locked unless Head or Owner rejects the report.',
    );
    if (!confirmed || !mounted) return;
    try {
      final saved = await _runReportAction<SalesReport>(context, () async {
        final value = await widget.api.submitSalesReportDirect(
          reportDate: report.reportDate,
          cashTotalRm: input.cashTotal,
          cashReceivedBy: input.cashReceivedBy,
          foodDeliverySalesRm: input.foodDelivery,
          ewalletTotalRm: input.ewallet,
          staffOnDuty: input.staffOnDuty,
        );
        await widget.onChanged();
        return value;
      });
      if (!mounted || saved == null) return;
      setState(() => applyReport(saved));
      showSuccessSnackBar(context, 'Sales report submitted');
    } on EastAppApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = report.isEditable;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        _StatusBanner(status: report.workflowStatus, note: report.reviewNote),
        const SizedBox(height: 10),
        _ReportDateSelector(date: report.reportDate, onTap: selectDate),
        const SizedBox(height: 12),
        _MetricGrid(
          items: [
            _MetricData('Total Sales', 'RM ${_money(report.totalSalesRm)}', AppColours.blue),
            _MetricData('Net Delivery', 'RM ${_money(report.netFoodDeliverySalesRm)}', AppColours.green),
            _MetricData('Platform Commission', 'RM ${_money(report.estimatedPlatformCommissionRm)}', AppColours.red),
            _MetricData('Void Total', 'RM ${_money(report.voidTotalRm)}', AppColours.red),
            _MetricData('Void Exposure', '${report.voidExposurePercent.toStringAsFixed(1)}%', AppColours.orange),
            _MetricData('Sales / Staff-Day', 'RM ${_money(report.salesPerStaffRm)}', AppColours.purple),
          ],
        ),
        const SizedBox(height: 14),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily Sales Input', style: TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'Total Sales is calculated by the server: Cash Total + eWallet Total + 60% of Gross Food Delivery Sales.',
                style: TextStyle(color: AppColours.textMuted, fontSize: AppTextSize.s12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              _AmountField(controller: cashTotalController, label: 'Cash Total', enabled: editable),
              const SizedBox(height: 10),
              _AmountField(controller: foodDeliveryController, label: 'Gross Food Delivery Sales', enabled: editable),
              const SizedBox(height: 5),
              const Text(
                'Enter the full platform amount. EastApp includes 60% in Total Sales and estimates 40% as platform commission.',
                style: TextStyle(
                  color: AppColours.textMuted,
                  fontSize: AppTextSize.s10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _AmountField(controller: ewalletController, label: 'eWallet Total', enabled: editable),
              const SizedBox(height: 10),
              TextField(
                controller: cashReceivedByController,
                enabled: editable,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: AppInputStyle.decoration('Cash Received By').copyWith(
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: staffOnDutyController,
                enabled: editable,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: AppInputStyle.decoration('Staff on Duty').copyWith(
                  prefixIcon: const Icon(Icons.groups_2_outlined),
                ),
              ),
              if (validation != null) ...[
                const SizedBox(height: 10),
                _ValidationText(validation!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        buildVoidBillsSection(editable),
        if (editable) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit for Approval'),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoidBillForm extends StatefulWidget {
  final EastAppApi api;
  final DateTime reportDate;
  final Future<void> Function() onSaved;

  const _VoidBillForm({
    required this.api,
    required this.reportDate,
    required this.onSaved,
  });

  @override
  State<_VoidBillForm> createState() => _VoidBillFormState();
}

class _VoidBillFormState extends State<_VoidBillForm> {
  final billController = TextEditingController();
  final reasonController = TextEditingController();
  final amountController = TextEditingController();
  String? photoPath;
  String? validation;

  @override
  void dispose() {
    billController.dispose();
    reasonController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> capture() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReportCameraPage(title: 'Void Bill Photo'),
      ),
    );
    if (!mounted || path == null) return;
    setState(() {
      photoPath = path;
      validation = null;
    });
  }

  Future<void> submit() async {
    final amount = double.tryParse(amountController.text.trim());
    if (photoPath == null) {
      setState(() => validation = 'Take a clear photo of the void bill.');
      return;
    }
    if (billController.text.trim().isEmpty) {
      setState(() => validation = 'Bill number is compulsory.');
      return;
    }
    if (reasonController.text.trim().isEmpty) {
      setState(() => validation = 'Void reason is compulsory.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => validation = 'Enter a valid void amount.');
      return;
    }
    final confirmed = await confirmDataChange(
      context,
      action: 'Record this void bill?',
      details: 'Bill ${billController.text.trim()} · RM ${_money(amount)}. Photo evidence will be permanently linked.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _runReportAction<void>(context, () async {
        final storageKey = await widget.api.uploadReportImage(photoPath!);
        await widget.api.addSalesVoidBill(
          reportDate: widget.reportDate,
          billNumber: billController.text,
          reason: reasonController.text,
          amountRm: amount,
          photoStorageKey: storageKey,
        );
        await widget.onSaved();
      });
      if (!mounted) return;
      showSuccessSnackBar(context, 'Void bill created');
      Navigator.of(context).pop();
    } on EastAppApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _ReportDateSelector(date: widget.reportDate),
        const SizedBox(height: 10),
        _EvidenceCapture(
          photoPath: photoPath,
          title: 'Void Bill Photo',
          subtitle: 'Capture the full bill including number and amount.',
          onCapture: capture,
        ),
        const SizedBox(height: 14),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: billController,
                decoration: AppInputStyle.decoration('e.g. V-001283').copyWith(
                  labelText: 'Bill Number',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: 10),
              _AmountField(
                controller: amountController,
                label: 'Void Amount',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: AppInputStyle.decoration('Explain why the bill was voided').copyWith(
                  labelText: 'Reason',
                  alignLabelWithHint: true,
                ),
              ),
              if (validation != null) ...[
                const SizedBox(height: 10),
                _ValidationText(validation!),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Record Void Bill'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventorySheet extends StatelessWidget {
  final InventoryIntelligence data;

  const _InventorySheet({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        WhiteCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data.healthScorePercent / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => CustomPaint(
                    painter: _DonutPainter(
                      value: value,
                      colour: _healthColour(data.healthScorePercent),
                    ),
                    child: Center(
                      child: Text(
                        '${data.healthScorePercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: AppTextSize.s25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Health',
                      style: TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${data.healthySkuCount} of ${data.activeSkuCount} SKUs are operating inside their configured range.',
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MetricGrid(
          items: [
            _MetricData('Stock Value', 'RM ${_money(data.estimatedStockValueRm)}', AppColours.blue),
            _MetricData('Reorder Need', 'RM ${_money(data.estimatedReorderInvestmentRm)}', AppColours.orange),
            _MetricData('Overstock Capital', 'RM ${_money(data.estimatedOverstockCapitalRm)}', AppColours.purple),
            _MetricData('Out / Low', '${data.outOfStockCount} / ${data.lowStockCount}', AppColours.red),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Priority Risks',
          style: TextStyle(
            fontSize: AppTextSize.s18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (data.topRisks.isEmpty)
          WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: Center(child: Text('No inventory risks detected')),
            ),
          )
        else
          ...data.topRisks.map(
            (risk) => WhiteCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SeverityPill(risk.severity),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          risk.skuName,
                          style: const TextStyle(
                            fontSize: AppTextSize.s16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        'RM ${_money(risk.estimatedValueAtRiskRm)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Balance ${_compact(risk.currentBalance)} · Range ${_compact(risk.minimumBalance)}–${_compact(risk.maximumBalance)}',
                    style: const TextStyle(
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    risk.insight,
                    style: const TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WasteSheet extends StatelessWidget {
  final EastAppApi api;
  final List<WasteReport> records;
  final List<StockSku> stockSkus;
  final bool isManagement;
  final Future<void> Function() onChanged;
  final VoidCallback onCreate;

  const _WasteSheet({
    required this.api,
    required this.records,
    required this.stockSkus,
    required this.isManagement,
    required this.onChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final total = records.fold<double>(0, (sum, item) => sum + item.estimatedLossRm);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniInsight(
                title: '30-day Loss',
                value: 'RM ${_money(total)}',
                icon: Icons.payments_outlined,
                colour: AppColours.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniInsight(
                title: 'Records',
                value: '${records.length}',
                icon: Icons.receipt_long_outlined,
                colour: AppColours.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add Waste Record'),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Recent Waste Evidence',
          style: TextStyle(
            fontSize: AppTextSize.s17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No waste records yet',
                  style: TextStyle(color: AppColours.textMuted),
                ),
              ),
            ),
          )
        else
          ...records.map(
            (item) => WhiteCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RemoteReportImage(
                    api: api,
                    storageKey: item.photoStorageKey,
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'RM ${_money(item.estimatedLossRm)}',
                              style: const TextStyle(
                                color: AppColours.orange,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_compact(item.quantity)} ${item.unit} · ${item.submittedByName}',
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 7),
                        _StatusChip(item.workflowStatus),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WasteForm extends StatefulWidget {
  final EastAppApi api;
  final List<StockSku> stockSkus;
  final DateTime earliestDate;
  final Future<void> Function() onSaved;

  const _WasteForm({
    required this.api,
    required this.stockSkus,
    required this.earliestDate,
    required this.onSaved,
  });

  @override
  State<_WasteForm> createState() => _WasteFormState();
}

class _WasteFormState extends State<_WasteForm> {
  final itemController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final costController = TextEditingController();
  final reasonController = TextEditingController();
  StockSku? selectedSku;
  String? photoPath;
  String? validation;
  DateTime reportDate = DateTime.now();

  @override
  void dispose() {
    itemController.dispose();
    quantityController.dispose();
    unitController.dispose();
    costController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  void selectSku(StockSku? sku) {
    setState(() {
      selectedSku = sku;
      if (sku != null) {
        itemController.text = sku.name;
        unitController.text = sku.unit;
        final average = (sku.minimumPriceRm + sku.maximumPriceRm) / 2;
        costController.text = average.toStringAsFixed(2);
      }
    });
  }

  Future<void> selectDate() async {
    final selected = await _pickReportDate(
      context,
      initialDate: reportDate,
      earliestDate: widget.earliestDate,
    );
    if (selected == null || !mounted) return;
    setState(() => reportDate = selected);
  }

  Future<void> capture() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReportCameraPage(title: 'Waste Evidence'),
      ),
    );
    if (!mounted || path == null) return;
    setState(() {
      photoPath = path;
      validation = null;
    });
  }

  Future<void> submit() async {
    final quantity = double.tryParse(quantityController.text.trim());
    final unitCost = double.tryParse(costController.text.trim());
    if (photoPath == null) {
      setState(() => validation = 'Take a clear waste photo.');
      return;
    }
    if (itemController.text.trim().isEmpty) {
      setState(() => validation = 'Select a SKU or enter the item name.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => validation = 'Enter a valid waste quantity.');
      return;
    }
    if (unitController.text.trim().isEmpty) {
      setState(() => validation = 'Unit is compulsory.');
      return;
    }
    if (unitCost == null || unitCost < 0) {
      setState(() => validation = 'Enter a valid estimated unit cost.');
      return;
    }
    if (reasonController.text.trim().isEmpty) {
      setState(() => validation = 'Waste reason is compulsory.');
      return;
    }
    final estimatedLoss = quantity * unitCost;
    final confirmed = await confirmDataChange(
      context,
      action: 'Submit waste report?',
      details:
          '${itemController.text.trim()} · ${_compact(quantity)} ${unitController.text.trim()} · Estimated loss RM ${_money(estimatedLoss)}.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _runReportAction<void>(context, () async {
        final storageKey = await widget.api.uploadReportImage(photoPath!);
        await widget.api.createWasteReport(
          reportDate: reportDate,
          skuId: selectedSku?.id,
          itemName: itemController.text,
          quantity: quantity,
          unit: unitController.text,
          estimatedUnitCostRm: unitCost,
          reason: reasonController.text,
          photoStorageKey: storageKey,
        );
        await widget.onSaved();
      });
      if (!mounted) return;
      showSuccessSnackBar(context, 'Waste report submitted');
      Navigator.of(context).pop();
    } on EastAppApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _EvidenceCapture(
          photoPath: photoPath,
          title: 'Waste Photo',
          subtitle: 'Photo evidence is compulsory for every waste record.',
          onCapture: capture,
        ),
        const SizedBox(height: 10),
        _ReportDateSelector(date: reportDate, onTap: selectDate),
        const SizedBox(height: 14),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<StockSku?>(
                value: selectedSku,
                isExpanded: true,
                decoration: AppInputStyle.decoration('Optional stock item').copyWith(
                  labelText: 'SKU',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<StockSku?>(
                    value: null,
                    child: Text('Non-SKU item'),
                  ),
                  ...widget.stockSkus.map(
                    (sku) => DropdownMenuItem<StockSku?>(
                      value: sku,
                      child: Text(sku.name),
                    ),
                  ),
                ],
                onChanged: selectSku,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: itemController,
                decoration: AppInputStyle.decoration('Item name').copyWith(
                  labelText: 'Item',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: AppInputStyle.decoration('0').copyWith(
                        labelText: 'Quantity',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: AppInputStyle.decoration('kg / pcs').copyWith(
                        labelText: 'Unit',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _AmountField(
                controller: costController,
                label: 'Estimated Unit Cost',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: AppInputStyle.decoration('Why was this item wasted?').copyWith(
                  labelText: 'Reason',
                  alignLabelWithHint: true,
                ),
              ),
              if (validation != null) ...[
                const SizedBox(height: 10),
                _ValidationText(validation!),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit Waste Report'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyPhotosSheet extends StatefulWidget {
  final EastAppApi api;
  final DailyPhotoReport initialReport;
  final DateTime earliestDate;
  final Future<void> Function() onChanged;

  const _DailyPhotosSheet({
    required this.api,
    required this.initialReport,
    required this.earliestDate,
    required this.onChanged,
  });

  @override
  State<_DailyPhotosSheet> createState() => _DailyPhotosSheetState();
}

class _DailyPhotosSheetState extends State<_DailyPhotosSheet> {
  late DailyPhotoReport report;

  @override
  void initState() {
    super.initState();
    report = widget.initialReport;
  }

  Future<void> selectDate() async {
    final selected = await _pickReportDate(
      context,
      initialDate: report.reportDate,
      earliestDate: widget.earliestDate,
    );
    if (selected == null || _sameDate(selected, report.reportDate) || !mounted) {
      return;
    }
    try {
      final loaded = await _runReportAction<DailyPhotoReport>(
        context,
        () => widget.api.dailyPhotoReport(date: selected),
      );
      if (!mounted || loaded == null) return;
      setState(() => report = loaded);
    } on EastAppApiException {
      return;
    }
  }

  Future<void> capture() async {
    if (!report.isEditable) return;
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReportCameraPage(title: 'Daily Photo'),
      ),
    );
    if (!mounted || path == null) return;
    try {
      final saved = await _runReportAction<DailyPhotoReport>(context, () async {
        final storageKey = await widget.api.uploadReportImage(path);
        final value = await widget.api.addDailyPhoto(
          reportDate: report.reportDate,
          photoStorageKey: storageKey,
        );
        await widget.onChanged();
        return value;
      });
      if (!mounted || saved == null) return;
      setState(() => report = saved);
    } on EastAppApiException {
      return;
    }
  }

  Future<void> submit() async {
    if (report.id == null || !report.requirementMet) return;
    final confirmed = await confirmDataChange(
      context,
      action: 'Submit daily photo batch?',
      details:
          '${report.photoCount} photos will be locked and sent for manager approval.',
    );
    if (!confirmed || !mounted) return;
    try {
      final saved = await _runReportAction<DailyPhotoReport>(context, () async {
        final value = await widget.api.submitDailyPhotoReport(report.id!);
        await widget.onChanged();
        return value;
      });
      if (!mounted || saved == null) return;
      setState(() => report = saved);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Daily photos submitted');
    } on EastAppApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = report.minimumRequired == 0
        ? 0.0
        : (report.photoCount / report.minimumRequired).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _StatusBanner(status: report.workflowStatus, note: report.reviewNote),
        const SizedBox(height: 10),
        _ReportDateSelector(date: report.reportDate, onTap: selectDate),
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 86,
                    height: 86,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      builder: (_, value, __) => CustomPaint(
                        painter: _DonutPainter(
                          value: value,
                          colour: report.requirementMet
                              ? AppColours.green
                              : AppColours.blue,
                        ),
                        child: Center(
                          child: Text(
                            '${report.photoCount}/${report.minimumRequired}',
                            style: const TextStyle(
                              fontSize: AppTextSize.s18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.requirementMet
                              ? 'Minimum achieved'
                              : '${report.minimumRequired - report.photoCount} more needed',
                          style: const TextStyle(
                            fontSize: AppTextSize.s18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'No caption needed. Take at least five operational photos each day.',
                          style: TextStyle(
                            color: AppColours.textMuted,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (report.isEditable) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: capture,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Take Photo'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (report.photos.isEmpty)
          WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No photos taken today',
                  style: TextStyle(color: AppColours.textMuted),
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, index) {
              final item = report.photos[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RemoteReportImage(
                      api: widget.api,
                      storageKey: item.photoStorageKey,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (report.isEditable && report.requirementMet) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit for Approval'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ComplaintSheet extends StatelessWidget {
  final EastAppApi api;
  final List<ComplaintReport> records;
  final bool isManagement;
  final Future<void> Function() onChanged;
  final VoidCallback onCreate;

  const _ComplaintSheet({
    required this.api,
    required this.records,
    required this.isManagement,
    required this.onChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final open = records.where((item) => item.status == 'OPEN').length;
    final resolved = records.length - open;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniInsight(
                title: 'Open',
                value: '$open',
                icon: Icons.pending_actions_rounded,
                colour: AppColours.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniInsight(
                title: 'Resolved',
                value: '$resolved',
                icon: Icons.done_all_rounded,
                colour: AppColours.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('Add Complaint'),
          ),
        ),
        const SizedBox(height: 14),
        if (records.isEmpty)
          WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No complaints recorded',
                  style: TextStyle(color: AppColours.textMuted),
                ),
              ),
            ),
          )
        else
          ...records.map(
            (item) => WhiteCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RemoteReportImage(
                    api: api,
                    storageKey: item.photoStorageKey,
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_titleCase(item.customerGender)} · approx. ${item.estimatedAge}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _StatusChip(item.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.complaintInfo,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Action: ${item.actionTaken}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isManagement) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _showComplaintUpdateDialog(
                              context,
                              api: api,
                              report: item,
                              onChanged: onChanged,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(
                              item.status == 'OPEN'
                                  ? 'Resolve Complaint'
                                  : 'Update Resolution',
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
      ],
    );
  }
}

class _ComplaintForm extends StatefulWidget {
  final EastAppApi api;
  final DateTime earliestDate;
  final Future<void> Function() onSaved;

  const _ComplaintForm({
    required this.api,
    required this.earliestDate,
    required this.onSaved,
  });

  @override
  State<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<_ComplaintForm> {
  final ageController = TextEditingController();
  final infoController = TextEditingController();
  final phoneController = TextEditingController();
  final actionController = TextEditingController();
  final compensationController = TextEditingController();
  String gender = 'UNKNOWN';
  String status = 'OPEN';
  String? photoPath;
  String? validation;
  DateTime reportDate = DateTime.now();

  @override
  void dispose() {
    ageController.dispose();
    infoController.dispose();
    phoneController.dispose();
    actionController.dispose();
    compensationController.dispose();
    super.dispose();
  }

  Future<void> selectDate() async {
    final selected = await _pickReportDate(
      context,
      initialDate: reportDate,
      earliestDate: widget.earliestDate,
    );
    if (selected == null || !mounted) return;
    setState(() => reportDate = selected);
  }

  Future<void> capture() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReportCameraPage(title: 'Complaint Photo'),
      ),
    );
    if (!mounted || path == null) return;
    setState(() {
      photoPath = path;
      validation = null;
    });
  }

  Future<void> submit() async {
    final age = int.tryParse(ageController.text.trim());
    final compensation = compensationController.text.trim().isEmpty
        ? null
        : double.tryParse(compensationController.text.trim());
    if (photoPath == null) {
      setState(() => validation = 'Take a complaint photo.');
      return;
    }
    if (age == null || age < 1 || age > 120) {
      setState(() => validation = 'Enter an estimated age from 1 to 120.');
      return;
    }
    if (infoController.text.trim().isEmpty) {
      setState(() => validation = 'Complaint information is compulsory.');
      return;
    }
    if (actionController.text.trim().isEmpty) {
      setState(() => validation = 'Action taken is compulsory.');
      return;
    }
    if (compensation != null && compensation < 0) {
      setState(() => validation = 'Compensation cannot be negative.');
      return;
    }
    final confirmed = await confirmDataChange(
      context,
      action: 'Submit customer complaint?',
      details: 'The photo, customer estimate, complaint and action will be stored for business review.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _runReportAction<void>(context, () async {
        final storageKey = await widget.api.uploadReportImage(photoPath!);
        await widget.api.createComplaintReport(
          reportDate: reportDate,
          photoStorageKey: storageKey,
          customerGender: gender,
          estimatedAge: age,
          complaintInfo: infoController.text,
          phoneE164: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text,
          actionTaken: actionController.text,
          compensationAmountRm: compensation,
          status: status,
        );
        await widget.onSaved();
      });
      if (!mounted) return;
      showSuccessSnackBar(context, 'Complaint report created');
      Navigator.of(context).pop();
    } on EastAppApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _EvidenceCapture(
          photoPath: photoPath,
          title: 'Complaint Photo',
          subtitle: 'Capture relevant evidence while respecting customer privacy.',
          onCapture: capture,
        ),
        const SizedBox(height: 10),
        _ReportDateSelector(date: reportDate, onTap: selectDate),
        const SizedBox(height: 14),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: gender,
                      decoration: AppInputStyle.decoration('Gender').copyWith(
                        labelText: 'Customer Gender',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                      ],
                      onChanged: (value) => setState(() => gender = value ?? 'UNKNOWN'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: AppInputStyle.decoration('Age').copyWith(
                        labelText: 'Estimated Age',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: infoController,
                minLines: 3,
                maxLines: 6,
                decoration: AppInputStyle.decoration('What did the customer complain about?').copyWith(
                  labelText: 'Complaint Information',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: AppInputStyle.decoration('Optional').copyWith(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: actionController,
                minLines: 3,
                maxLines: 6,
                decoration: AppInputStyle.decoration('What action was taken?').copyWith(
                  labelText: 'Action',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              _AmountField(
                controller: compensationController,
                label: 'Compensation Amount (Optional)',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: status,
                decoration: AppInputStyle.decoration('Status').copyWith(
                  labelText: 'Status',
                ),
                items: const [
                  DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                ],
                onChanged: (value) => setState(() => status = value ?? 'OPEN'),
              ),
              if (validation != null) ...[
                const SizedBox(height: 10),
                _ValidationText(validation!),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit Complaint'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showComplaintUpdateDialog(
  BuildContext context, {
  required EastAppApi api,
  required ComplaintReport report,
  required Future<void> Function() onChanged,
}) async {
  final actionController = TextEditingController(text: report.actionTaken);
  final compensationController = TextEditingController(
    text: report.compensationAmountRm == null
        ? ''
        : report.compensationAmountRm!.toStringAsFixed(2),
  );
  var status = report.status;
  String? validation;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Update Complaint'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: AppInputStyle.decoration('Status').copyWith(
                  labelText: 'Status',
                ),
                items: const [
                  DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                ],
                onChanged: (value) => setDialogState(() => status = value ?? 'OPEN'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: actionController,
                minLines: 3,
                maxLines: 6,
                decoration: AppInputStyle.decoration('Action taken').copyWith(
                  labelText: 'Action',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              _AmountField(
                controller: compensationController,
                label: 'Compensation Amount',
              ),
              if (validation != null) ...[
                const SizedBox(height: 10),
                _ValidationText(validation!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final compensation = compensationController.text.trim().isEmpty
                  ? null
                  : double.tryParse(compensationController.text.trim());
              if (actionController.text.trim().isEmpty ||
                  (compensation != null && compensation < 0)) {
                setDialogState(() {
                  validation = 'Enter an action and valid compensation amount.';
                });
                return;
              }
              final confirmed = await confirmDataChange(
                dialogContext,
                action: 'Update complaint status?',
              );
              if (!confirmed || !dialogContext.mounted) return;
              try {
                await _runReportAction<void>(dialogContext, () async {
                  await api.updateComplaintReport(
                    reportId: report.id,
                    status: status,
                    actionTaken: actionController.text,
                    compensationAmountRm: compensation,
                  );
                  await onChanged();
                });
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  showSuccessSnackBar(context, 'Complaint updated');
                }
              } on EastAppApiException {
                return;
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
  actionController.dispose();
  compensationController.dispose();
}

class _ApprovalsSheet extends StatefulWidget {
  final EastAppApi api;
  final List<ReportApproval> initialApprovals;
  final Future<void> Function() onChanged;

  const _ApprovalsSheet({
    required this.api,
    required this.initialApprovals,
    required this.onChanged,
  });

  @override
  State<_ApprovalsSheet> createState() => _ApprovalsSheetState();
}

class _ApprovalsSheetState extends State<_ApprovalsSheet> {
  late List<ReportApproval> approvals;
  final Set<String> reviewingIds = <String>{};
  final Set<String> openingEvidenceIds = <String>{};

  @override
  void initState() {
    super.initState();
    approvals = List.of(widget.initialApprovals);
  }

  Future<void> viewEvidence(ReportApproval item) async {
    if (!openingEvidenceIds.add(item.id)) return;
    if (mounted) setState(() {});
    try {
      SalesReport? sales;
      WasteReport? waste;
      DailyPhotoReport? dailyPhotos;
      try {
        final loaded = await _runReportAction<bool>(context, () async {
          if (item.reportType == 'SALES') {
            sales = await widget.api.salesReport(item.reportDate);
          } else if (item.reportType == 'WASTE') {
            final records = await widget.api.wasteReports(
              from: item.reportDate,
              to: item.reportDate,
            );
            for (final record in records) {
              if (record.id == item.id) {
                waste = record;
                break;
              }
            }
          } else if (item.reportType == 'DAILY_PHOTO') {
            dailyPhotos = await widget.api.dailyPhotoReport(
              date: item.reportDate,
              userId: item.submittedByUserId,
            );
          }
          return true;
        });
        if (loaded != true) return;
      } on EastAppApiException {
        return;
      }
      if (!mounted) return;
      if (sales == null && waste == null && dailyPhotos == null) {
        showWarningSnackBar(context, 'Report evidence could not be loaded.');
        return;
      }
      await _showReportSheet<void>(
        context,
        title: 'Review & Decide',
        icon: _reportTypeIcon(item.reportType),
        builder: (evidenceContext) => _ApprovalEvidenceView(
          api: widget.api,
          approval: item,
          sales: sales,
          waste: waste,
          dailyPhotos: dailyPhotos,
          onReject: () {
            Navigator.of(evidenceContext).pop();
            Future<void>.delayed(
              Duration.zero,
              () => review(item, false),
            );
          },
          onApprove: () {
            Navigator.of(evidenceContext).pop();
            Future<void>.delayed(
              Duration.zero,
              () => review(item, true),
            );
          },
        ),
      );
    } finally {
      openingEvidenceIds.remove(item.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> review(ReportApproval item, bool approve) async {
    if (!reviewingIds.add(item.id)) return;
    if (mounted) setState(() {});
    try {
      final noteController = TextEditingController();
      final note = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(approve ? 'Approve Report' : 'Reject Report'),
          content: TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 5,
            decoration: AppInputStyle.decoration(
              approve ? 'Optional approval note' : 'Rejection reason is compulsory',
            ).copyWith(labelText: 'Review Note', alignLabelWithHint: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = noteController.text.trim();
                if (!approve && value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(approve ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      );
      noteController.dispose();
      if (!mounted || note == null) return;
      final confirmed = await confirmDataChange(
        context,
        action: approve ? 'Approve this report?' : 'Reject this report?',
        details: item.summary,
      );
      if (!confirmed || !mounted) return;
      try {
        final completed = await _runReportAction<bool>(context, () async {
          await widget.api.reviewReport(
            reportId: item.id,
            status: approve ? 'APPROVED' : 'REJECTED',
            note: note,
          );
          await widget.onChanged();
          return true;
        });
        if (!mounted || completed != true) return;
        setState(() => approvals.removeWhere((entry) => entry.id == item.id));
        showSuccessSnackBar(context, approve ? 'Report approved' : 'Report rejected');
      } on EastAppApiException {
        return;
      }
    } finally {
      reviewingIds.remove(item.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        if (approvals.isEmpty)
          WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.verified_rounded, color: AppColours.green, size: 48),
                  SizedBox(height: 10),
                  Text(
                    'All reports reviewed',
                    style: TextStyle(
                      fontSize: AppTextSize.s18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...approvals.map(
            (item) => WhiteCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _reportTypeColour(item.reportType).withOpacity(.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _reportTypeIcon(item.reportType),
                          color: _reportTypeColour(item.reportType),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleCase(item.reportType.replaceAll('_', ' ')),
                              style: const TextStyle(
                                fontSize: AppTextSize.s16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${item.submittedByName} · ${_formatDate(item.reportDate)}',
                              style: const TextStyle(
                                color: AppColours.textMuted,
                                fontSize: AppTextSize.s12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(item.summary),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: reviewingIds.contains(item.id) ||
                              openingEvidenceIds.contains(item.id)
                          ? null
                          : () => viewEvidence(item),
                      icon: openingEvidenceIds.contains(item.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.visibility_outlined),
                      label: const Text('Review & Decide'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ApprovalEvidenceView extends StatelessWidget {
  final EastAppApi api;
  final ReportApproval approval;
  final SalesReport? sales;
  final WasteReport? waste;
  final DailyPhotoReport? dailyPhotos;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const _ApprovalEvidenceView({
    required this.api,
    required this.approval,
    this.sales,
    this.waste,
    this.dailyPhotos,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final salesReport = sales;
    final wasteReport = waste;
    final photoReport = dailyPhotos;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _reportTypeColour(approval.reportType).withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _reportTypeIcon(approval.reportType),
                  color: _reportTypeColour(approval.reportType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleCase(approval.reportType.replaceAll('_', ' ')),
                      style: const TextStyle(
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${approval.submittedByName} · ${_formatDate(approval.reportDate)}',
                      style: const TextStyle(
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
        const SizedBox(height: 12),
        if (salesReport != null) ...[
          _MetricGrid(
            items: [
              _MetricData('Cash Total', 'RM ${_money(salesReport.cashTotalRm)}', AppColours.green),
              _MetricData('Gross Delivery', 'RM ${_money(salesReport.foodDeliverySalesRm)}', AppColours.orange),
              _MetricData('Net Delivery (60%)', 'RM ${_money(salesReport.netFoodDeliverySalesRm)}', AppColours.green),
              _MetricData('Platform Commission', 'RM ${_money(salesReport.estimatedPlatformCommissionRm)}', AppColours.red),
              _MetricData('eWallet Total', 'RM ${_money(salesReport.ewalletTotalRm)}', AppColours.purple),
              _MetricData('Total Sales', 'RM ${_money(salesReport.totalSalesRm)}', AppColours.blue),
              _MetricData('Staff on Duty', '${salesReport.staffOnDuty}', AppColours.purple),
              _MetricData('Sales / Staff-Day', 'RM ${_money(salesReport.salesPerStaffRm)}', AppColours.blue),
              _MetricData('Void Total', 'RM ${_money(salesReport.voidTotalRm)}', AppColours.red),
              _MetricData('Void Exposure', '${salesReport.voidExposurePercent.toStringAsFixed(1)}%', AppColours.orange),
            ],
          ),
          const SizedBox(height: 12),
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sales Submission Details',
                  style: TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                _approvalDetailRow('Report Date', _formatDate(salesReport.reportDate)),
                _approvalDetailRow('Submitted By', salesReport.submittedByName ?? approval.submittedByName),
                _approvalDetailRow('Submitted At', _formatDateTime(salesReport.submittedAt ?? approval.submittedAt)),
                _approvalDetailRow('Cash Received By', salesReport.cashReceivedBy),
                _approvalDetailRow('Status', _titleCase(salesReport.workflowStatus)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Void Bill Evidence',
                  style: TextStyle(
                    fontSize: AppTextSize.s17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (salesReport.voidBills.isEmpty)
                  const Text(
                    'No void bills recorded.',
                    style: TextStyle(color: AppColours.textMuted),
                  )
                else
                  ...salesReport.voidBills.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _RemoteReportImage(
                              api: api,
                              storageKey: item.photoStorageKey,
                              width: double.infinity,
                              height: 190,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item.billNumber} · RM ${_money(item.amountRm)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            item.reason,
                            style: const TextStyle(color: AppColours.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (wasteReport != null) ...[
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _RemoteReportImage(
                    api: api,
                    storageKey: wasteReport.photoStorageKey,
                    width: double.infinity,
                    height: 220,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  wasteReport.itemName,
                  style: const TextStyle(
                    fontSize: AppTextSize.s18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${_editableNumber(wasteReport.quantity)} ${wasteReport.unit} · RM ${_money(wasteReport.estimatedLossRm)} estimated loss'),
                const SizedBox(height: 6),
                Text(
                  wasteReport.reason,
                  style: const TextStyle(color: AppColours.textMuted),
                ),
              ],
            ),
          ),
        ],
        if (photoReport != null) ...[
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${photoReport.photoCount} operational photos submitted by ${photoReport.userName}.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photoReport.photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (_, index) {
              final photo = photoReport.photos[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _RemoteReportImage(
                  api: api,
                  storageKey: photo.photoStorageKey,
                  width: double.infinity,
                  height: double.infinity,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportDateSelector extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onTap;

  const _ReportDateSelector({required this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppColours.blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Report Date',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _formatDate(date),
                style: const TextStyle(
                  color: AppColours.blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColours.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String? note;

  const _StatusBanner({required this.status, this.note});

  @override
  Widget build(BuildContext context) {
    final normalised = status.toUpperCase();
    final colour = switch (normalised) {
      'APPROVED' => AppColours.green,
      'REJECTED' => AppColours.red,
      'SUBMITTED' => AppColours.orange,
      _ => AppColours.blue,
    };
    final icon = switch (normalised) {
      'APPROVED' => Icons.verified_rounded,
      'REJECTED' => Icons.cancel_rounded,
      'SUBMITTED' => Icons.hourglass_top_rounded,
      _ => Icons.edit_note_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colour.withOpacity(.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colour.withOpacity(.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleCase(normalised.toLowerCase()),
                  style: TextStyle(
                    color: colour,
                    fontSize: AppTextSize.s14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (note?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    note!.trim(),
                    style: const TextStyle(
                      color: AppColours.textMain,
                      fontSize: AppTextSize.s12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final Color colour;

  const _MetricData(this.label, this.value, this.colour);
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> items;

  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 82),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: item.colour.withOpacity(.075),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: item.colour.withOpacity(.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.value,
                            style: TextStyle(
                              color: item.colour,
                              fontSize: AppTextSize.s20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;

  const _AmountField({
    required this.controller,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: AppInputStyle.decoration('0.00', prefixText: 'RM ').copyWith(
        labelText: label,
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
    );
  }
}

class _ValidationText extends StatelessWidget {
  final String message;

  const _ValidationText(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColours.redSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColours.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColours.red,
                fontSize: AppTextSize.s12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoidBillRow extends StatelessWidget {
  final EastAppApi api;
  final VoidBill item;

  const _VoidBillRow({required this.api, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColours.mutedBox,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 54,
              height: 54,
              child: _RemoteReportImage(
                api: api,
                storageKey: item.photoStorageKey,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill ${item.billNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  item.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontSize: AppTextSize.s12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'RM ${_money(item.amountRm)}',
            style: const TextStyle(
              color: AppColours.red,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCapture extends StatelessWidget {
  final String? photoPath;
  final String title;
  final String subtitle;
  final VoidCallback onCapture;

  const _EvidenceCapture({
    required this.photoPath,
    required this.title,
    required this.subtitle,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onCapture,
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photoPath != null)
                  Image.file(File(photoPath!), fit: BoxFit.cover)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF15285F), Color(0xFF1557F2)],
                      ),
                    ),
                  ),
                if (photoPath != null)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(.68)],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.94),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          photoPath == null
                              ? Icons.add_a_photo_rounded
                              : Icons.cameraswitch_rounded,
                          color: AppColours.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        photoPath == null ? title : '$title Captured',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.s18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        photoPath == null ? subtitle : 'Tap to retake',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double value;
  final Color colour;

  const _DonutPainter({required this.value, required this.colour});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = AppColours.border;
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = colour;
    canvas.drawCircle(centre, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.colour != colour;
  }
}

Color _healthColour(double score) {
  if (score >= 80) return AppColours.green;
  if (score >= 55) return AppColours.orange;
  return AppColours.red;
}

class _SeverityPill extends StatelessWidget {
  final String severity;

  const _SeverityPill(this.severity);

  @override
  Widget build(BuildContext context) {
    final colour = switch (severity.toUpperCase()) {
      'CRITICAL' => AppColours.red,
      'HIGH' => AppColours.orange,
      'OVERSTOCK' => AppColours.purple,
      _ => AppColours.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _titleCase(severity.toLowerCase()),
        style: TextStyle(
          color: colour,
          fontSize: AppTextSize.s10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final colour = switch (status.toUpperCase()) {
      'APPROVED' || 'RESOLVED' => AppColours.green,
      'REJECTED' => AppColours.red,
      'SUBMITTED' || 'OPEN' => AppColours.orange,
      _ => AppColours.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _titleCase(status.toLowerCase()),
        style: TextStyle(
          color: colour,
          fontSize: AppTextSize.s10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color colour;

  const _MiniInsight({
    required this.icon,
    required this.title,
    required this.value,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withOpacity(.075),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour, size: 20),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colour,
              fontSize: AppTextSize.s16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteReportImage extends StatefulWidget {
  final EastAppApi api;
  final String storageKey;
  final BoxFit fit;
  final double? width;
  final double? height;

  const _RemoteReportImage({
    required this.api,
    required this.storageKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<_RemoteReportImage> createState() => _RemoteReportImageState();
}

class _RemoteReportImageState extends State<_RemoteReportImage> {
  late Future<Uint8List> request;

  @override
  void initState() {
    super.initState();
    request = widget.api.reportImageBytes(widget.storageKey);
  }

  @override
  void didUpdateWidget(covariant _RemoteReportImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey || oldWidget.api != widget.api) {
      request = widget.api.reportImageBytes(widget.storageKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          );
        }
        if (snapshot.hasError) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: AppColours.mutedBox,
            child: const Icon(Icons.broken_image_outlined, color: AppColours.textMuted),
          );
        }
        return Container(
          width: widget.width,
          height: widget.height,
          color: AppColours.mutedBox,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

class _ReportCameraPage extends StatefulWidget {
  final String title;

  const _ReportCameraPage({required this.title});

  @override
  State<_ReportCameraPage> createState() => _ReportCameraPageState();
}

class _ReportCameraPageState extends State<_ReportCameraPage> {
  CameraController? controller;
  bool capturing = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(initialiseCamera());
  }

  Future<void> initialiseCamera() async {
    final oldController = controller;
    controller = null;
    await oldController?.dispose();
    if (mounted) setState(() => errorMessage = null);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final value = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await value.initialize();
      if (!mounted) {
        await value.dispose();
        return;
      }
      AppDiagnostics.instance.setCameraInfo(
        'Report camera · cameraCount=${cameras.length}, '
        'selected=${camera.name}, lens=${camera.lensDirection.name}, '
        'sensorOrientation=${camera.sensorOrientation}, preset=medium',
      );
      setState(() => controller = value);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> capturePhoto() async {
    final value = controller;
    if (value == null || !value.value.isInitialized || capturing) return;
    setState(() => capturing = true);
    try {
      final photo = await value.takePicture();
      AppDiagnostics.instance.log('Report photo captured · ${photo.name}');
      if (!mounted) return;
      Navigator.of(context).pop(photo.path);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        capturing = false;
        errorMessage = error.toString();
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white70,
                              size: 54,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: initialiseCamera,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry Camera'),
                            ),
                          ],
                        ),
                      )
                    : value == null || !value.value.isInitialized
                        ? const CircularProgressIndicator(color: Colors.white)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final previewSize = value.value.previewSize;
                              if (previewSize == null) return CameraPreview(value);
                              return ClipRect(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: previewSize.height,
                                    height: previewSize.width,
                                    child: CameraPreview(value),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SizedBox(
                width: 76,
                height: 76,
                child: FloatingActionButton(
                  heroTag: 'report-photo-capture-${widget.title}',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  onPressed: value == null || !value.value.isInitialized || capturing
                      ? null
                      : capturePhoto,
                  child: capturing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _reportTypeColour(String type) {
  return switch (type.toUpperCase()) {
    'SALES' => AppColours.blue,
    'WASTE' => AppColours.orange,
    'DAILY_PHOTO' => AppColours.purple,
    'COMPLAINT' => AppColours.red,
    _ => AppColours.textMuted,
  };
}

IconData _reportTypeIcon(String type) {
  return switch (type.toUpperCase()) {
    'SALES' => Icons.point_of_sale_rounded,
    'WASTE' => Icons.delete_sweep_rounded,
    'DAILY_PHOTO' => Icons.photo_camera_rounded,
    'COMPLAINT' => Icons.support_agent_rounded,
    _ => Icons.analytics_outlined,
  };
}

Future<DateTime?> _pickReportDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime earliestDate,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final first = DateTime(
    earliestDate.year,
    earliestDate.month,
    earliestDate.day,
  );
  final requested = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  final initial = requested.isBefore(first)
      ? first
      : requested.isAfter(today)
          ? today
          : requested;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: today,
  );
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _lastUpdatedText(DateTime? value) {
  if (value == null) return 'Not loaded';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return 'Updated $hour:$minute $suffix';
}

Widget _approvalDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:$minute';
}

String _money(num value) => value.toStringAsFixed(2);

String _compact(num value) {
  final number = value.toDouble();
  if (number.abs() >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}m';
  if (number.abs() >= 1000) return '${(number / 1000).toStringAsFixed(1)}k';
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(1);
}

String _editableNumber(num value) {
  final number = value.toDouble();
  if (number == 0) return '';
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(2);
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _titleCase(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}
