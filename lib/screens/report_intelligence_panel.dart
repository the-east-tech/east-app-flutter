import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/report_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class ReportIntelligencePanel extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final ReportDashboard? initialDashboard;
  final ValueChanged<ReportDashboard>? onDashboardLoaded;

  const ReportIntelligencePanel({
    super.key,
    required this.api,
    required this.tenantId,
    required this.initialDashboard,
    this.onDashboardLoaded,
  });

  @override
  State<ReportIntelligencePanel> createState() =>
      _ReportIntelligencePanelState();
}

class _ReportIntelligencePanelState extends State<ReportIntelligencePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController heroController;
  ReportDashboard? dashboard;
  bool loading = false;
  int periodDays = 7;
  DateTime? lastUpdatedAt;
  int loadGeneration = 0;

  String get cacheKey => EastAppApi.reportDashboardCacheKey(
        widget.tenantId,
        periodDays,
        managementView: true,
        userId: '',
      );

  @override
  void initState() {
    super.initState();
    heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    dashboard = widget.initialDashboard;
    lastUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey);
    if (dashboard == null) unawaited(loadDashboard());
  }

  @override
  void didUpdateWidget(covariant ReportIntelligencePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId) {
      loadGeneration++;
      periodDays = 7;
      dashboard = widget.initialDashboard;
      lastUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey);
      if (dashboard == null) unawaited(loadDashboard());
      return;
    }
    if (periodDays == 7 &&
        oldWidget.initialDashboard != widget.initialDashboard &&
        widget.initialDashboard != null) {
      dashboard = widget.initialDashboard;
      lastUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey);
    }
  }

  @override
  void dispose() {
    heroController.dispose();
    super.dispose();
  }

  Future<void> loadDashboard({bool forceRefresh = false}) async {
    final generation = ++loadGeneration;
    if (mounted) setState(() => loading = true);
    try {
      final value = await widget.api.reportDashboard(
        days: periodDays,
        tenantId: widget.tenantId,
        managementView: true,
        userId: '',
        forceRefresh: forceRefresh,
      );
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        dashboard = value;
        lastUpdatedAt =
            widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
        loading = false;
      });
      if (periodDays == 7) widget.onDashboardLoaded?.call(value);
    } on EastAppApiException {
      if (!mounted || generation != loadGeneration) return;
      setState(() => loading = false);
    }
  }

  void changePeriod(int value) {
    if (value == periodDays) return;
    setState(() {
      periodDays = value;
      dashboard = null;
      lastUpdatedAt = null;
      loading = true;
    });
    unawaited(loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final data = dashboard;
    return Column(
      children: [
        _ReportHero(
          controller: heroController,
          dashboard: data,
          loading: loading,
          periodDays: periodDays,
          onPeriodChanged: changePeriod,
          onRefresh: loading ? null : () => loadDashboard(forceRefresh: true),
          lastUpdatedAt: lastUpdatedAt,
        ),
        if (data?.trend.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _TrendPanel(points: data!.trend),
        ],
      ],
    );
  }
}

class _ReportHero extends StatelessWidget {
  final AnimationController controller;
  final ReportDashboard? dashboard;
  final bool loading;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;
  final VoidCallback? onRefresh;
  final DateTime? lastUpdatedAt;

  const _ReportHero({
    required this.controller,
    required this.dashboard,
    required this.loading,
    required this.periodDays,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.lastUpdatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
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
                color: AppColours.blue.withValues(alpha: .22),
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
                    color: Colors.white.withValues(alpha: .08),
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
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text.t('Report Intelligence'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppTextSize.s24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              text.t(
                                'Operational evidence transformed into business decisions',
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: AppTextSize.s13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton.filledTonal(
                            tooltip: text.t('Refresh report data'),
                            onPressed: onRefresh,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: .16),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  Colors.white.withValues(alpha: .10),
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
                            text.t(_lastUpdatedText(lastUpdatedAt)),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: AppTextSize.s10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                              : (workforce?.averageStaffPerDay ?? 0)
                                  .toStringAsFixed(1),
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
                  ),
                  if ((dashboard?.workforce?.openShiftCount ?? 0) > 0 ||
                      (dashboard?.countCoverage?.missingCountSkuDays ?? 0) > 0 ||
                      (dashboard?.workforce?.staffCountMismatchDays ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        [
                          if ((dashboard?.workforce?.openShiftCount ?? 0) > 0)
                            text.t(
                              '${dashboard!.workforce!.openShiftCount} open shift(s)',
                            ),
                          if ((dashboard?.countCoverage?.missingCountSkuDays ?? 0) >
                              0)
                            text.t(
                              '${dashboard!.countCoverage!.missingCountSkuDays} missing SKU-day count(s)',
                            ),
                          if ((dashboard?.workforce?.staffCountMismatchDays ?? 0) >
                              0)
                            text.t(
                              'Attendance mismatch: ${dashboard!.workforce!.staffCountMismatchDays} day(s)',
                            ),
                        ].join(' · '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : Colors.white.withValues(alpha: .10),
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppColours.blueDark
                            : Colors.white,
                      ),
                      side: WidgetStateProperty.all(
                        BorderSide(
                          color: Colors.white.withValues(alpha: .18),
                        ),
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
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.t(label),
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
              text.t(value),
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

class _TrendPanel extends StatelessWidget {
  final List<ReportTrendPoint> points;

  const _TrendPanel({required this.points});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final totalSales =
        points.fold<double>(0, (sum, item) => sum + item.netSalesRm);
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
              Expanded(
                child: Text(
                  text.t('Sales vs Operational Leakage'),
                  style: const TextStyle(
                    fontSize: AppTextSize.s17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                text.t('${points.length} days'),
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text.t(
              'RM ${_money(totalSales)} sales · RM ${_money(totalLeakage)} void + waste',
            ),
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
              builder: (_, progress, _) => CustomPaint(
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
    final text = AppTextScope.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text.t(label),
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
        .map(
          (item) => math.max(
            item.netSalesRm,
            math.max(item.voidAmountRm, item.wasteLossRm),
          ),
        )
        .fold<double>(1, math.max);
    final chart = Rect.fromLTWH(6, 6, size.width - 12, size.height - 18);
    final gridPaint = Paint()
      ..color = AppColours.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final step =
        points.length == 1 ? chart.width : chart.width / (points.length - 1);
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

String _lastUpdatedText(DateTime? value) {
  if (value == null) return 'Not loaded';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return 'Updated $hour:$minute $suffix';
}

String _money(num value) => value.toStringAsFixed(2);
