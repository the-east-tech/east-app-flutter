import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_text_scope.dart';
import '../models/api_models.dart';
import '../models/advertisement_models.dart';
import '../models/app_models.dart';
import '../models/google_place_models.dart';
import '../models/report_models.dart';
import '../models/stock_api_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';


const Duration _googleRatingCacheDuration = Duration(hours: 1);
final Map<String, _GoogleRatingCacheEntry> _googleRatingCache =
    <String, _GoogleRatingCacheEntry>{};
final Map<String, Future<EastAppGoogleRating>> _googleRatingRequests =
    <String, Future<EastAppGoogleRating>>{};

class _GoogleRatingCacheEntry {
  final EastAppGoogleRating value;
  final DateTime fetchedAt;

  const _GoogleRatingCacheEntry({
    required this.value,
    required this.fetchedAt,
  });

  bool isFresh(DateTime now) {
    return now.difference(fetchedAt) < _googleRatingCacheDuration;
  }
}

Future<EastAppGoogleRating> _refreshGoogleRating(
  EastAppApi api,
  String tenantId,
) {
  final existingRequest = _googleRatingRequests[tenantId];
  if (existingRequest != null) {
    return existingRequest;
  }

  late final Future<EastAppGoogleRating> request;
  request = api.currentGoogleRating().then((value) {
    _googleRatingCache[tenantId] = _GoogleRatingCacheEntry(
      value: value,
      fetchedAt: DateTime.now(),
    );
    return value;
  }).whenComplete(() {
    if (identical(_googleRatingRequests[tenantId], request)) {
      _googleRatingRequests.remove(tenantId);
    }
  });
  _googleRatingRequests[tenantId] = request;
  return request;
}

class HomeScreen extends StatefulWidget {
  final UserRole role;
  final bool isOwner;
  final EastAppApi api;
  final String tenantId;
  final String businessName;
  final List<StaffTask> tasks;
  final int googleRatingRefreshSignal;
  final VoidCallback onViewTasks;
  final VoidCallback onReports;
  final VoidCallback onRewards;
  final VoidCallback onRanking;
  final VoidCallback onKnowledge;

  const HomeScreen({
    super.key,
    required this.role,
    required this.isOwner,
    required this.api,
    required this.tenantId,
    required this.businessName,
    required this.tasks,
    required this.googleRatingRefreshSignal,
    required this.onViewTasks,
    required this.onReports,
    required this.onRewards,
    required this.onRanking,
    required this.onKnowledge,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StockReviewSummary? reviewSummary;
  ReportDashboard? reportDashboard;
  List<RecentActivity> homeRecentActivities = const [];
  List<Advertisement> activeAdvertisements = const [];
  Timer? _advertisementScheduleTimer;
  int _loadGeneration = 0;
  int _advertisementLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadHomeData();
    unawaited(_loadAdvertisements());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advertisementScheduleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadAdvertisements());
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId) {
      _advertisementScheduleTimer?.cancel();
      _advertisementLoadGeneration++;
      activeAdvertisements = const [];
      unawaited(_loadAdvertisements());
    }
    if (oldWidget.tenantId != widget.tenantId ||
        oldWidget.role != widget.role ||
        oldWidget.isOwner != widget.isOwner) {
      loadHomeData();
    }
  }

  Future<void> loadHomeData() async {
    final loadGeneration = ++_loadGeneration;
    final now = DateTime.now();
    final auditFuture = widget.api.stockAudit(
      from: now.subtract(const Duration(days: 29)),
      to: now,
      mine: true,
      page: 0,
      size: 5,
    );
    final summaryFuture = widget.role == UserRole.staff
        ? Future<StockReviewSummary?>.value(null)
        : widget.api.todayStockReviewSummary();
    final reportFuture = widget.api
        .reportDashboard(days: 7, tenantId: widget.tenantId)
        .then<ReportDashboard?>((value) => value)
        .catchError((Object _) => null);

    try {
      final results = await Future.wait<Object?>([
        auditFuture,
        summaryFuture,
        reportFuture,
      ]);
      final audit = results[0] as EastAppPage<StockAuditEntry>;
      final summary = results[1] as StockReviewSummary?;
      final reports = results[2] as ReportDashboard?;
      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() {
        reviewSummary = summary;
        reportDashboard = reports;
        homeRecentActivities = audit.content
            .take(5)
            .map(
              (entry) => RecentActivity(
                title: '${entry.action}: ${entry.itemName}',
                time: entry.timestampText,
                score: 1,
                status: entry.module,
              ),
            )
            .toList(growable: false);
      });
    } on EastAppApiException {
      // The global API error handler already shows the request failure.
    }
  }

  List<Advertisement> _publishedAdvertisements(
    AdvertisementFeed feed,
    DateTime now,
  ) {
    return feed.advertisements
        .where(
          (item) =>
              item.publicationStatus(now) == AdvertisementPublicationStatus.published,
        )
        .toList(growable: false);
  }

  Future<void> _loadAdvertisements({bool forceRefresh = false}) async {
    if (!mounted) return;
    final tenantId = widget.tenantId;
    final generation = ++_advertisementLoadGeneration;
    try {
      var feed = await widget.api.advertisementFeed(
        tenantId: tenantId,
        forceRefresh: forceRefresh,
      );
      if (!mounted || tenantId != widget.tenantId || generation != _advertisementLoadGeneration) {
        return;
      }

      var now = DateTime.now();
      if (!forceRefresh &&
          feed.nextChangeAt != null &&
          !now.isBefore(feed.nextChangeAt!)) {
        feed = await widget.api.advertisementFeed(
          tenantId: tenantId,
          forceRefresh: true,
        );
        if (!mounted ||
            tenantId != widget.tenantId ||
            generation != _advertisementLoadGeneration) {
          return;
        }
        now = DateTime.now();
      }

      setState(() => activeAdvertisements = _publishedAdvertisements(feed, now));
      _scheduleAdvertisementRefreshAt(feed.nextChangeAt);
    } on EastAppApiException {
      // Keep the currently displayed cached advertisements. Do not poll/retry.
    }
  }

  void _scheduleAdvertisementRefreshAt(DateTime? nextChangeAt) {
    _advertisementScheduleTimer?.cancel();
    if (nextChangeAt == null || !mounted) return;
    final delay = nextChangeAt.difference(DateTime.now()) +
        const Duration(milliseconds: 500);
    if (delay <= Duration.zero) {
      unawaited(_loadAdvertisements(forceRefresh: true));
      return;
    }
    _advertisementScheduleTimer = Timer(
      delay,
      () => _loadAdvertisements(forceRefresh: true),
    );
  }

  Future<void> _openAdvertisementManager(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdvertisementManagerScreen(api: widget.api),
      ),
    );
    if (!mounted) return;
    await widget.api.invalidateFeatureCache(
      EastAppApi.advertisementFeedCacheKey(widget.tenantId),
    );
    await _loadAdvertisements(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final isManagement = widget.role != UserRole.staff;
    final pendingReviewCount = reviewSummary?.pendingReview ?? 0;
    final doneReviewCount = reviewSummary?.done ?? 0;
    final totalReviewCount = reviewSummary?.total ?? 0;
    final photoOverview = reportDashboard?.dailyPhotos;
    final photoCount = photoOverview?.currentUserPhotoCount ?? 0;
    final photoMinimum = photoOverview?.minimumRequired ?? 5;
    final photoProgress = photoMinimum == 0
        ? 0.0
        : (photoCount / photoMinimum).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PageTitle(
          title: widget.businessName,
          subtitle: text.t('Home Dashboard'),
        ),
        const SizedBox(height: 4),
        _GoogleRatingCard(
          api: widget.api,
          tenantId: widget.tenantId,
          businessName: widget.businessName,
          refreshSignal: widget.googleRatingRefreshSignal,
        ),
        const SizedBox(height: 10),
        if (activeAdvertisements.isNotEmpty) ...[
          _AdvertisementCarousel(api: widget.api, advertisements: activeAdvertisements),
          const SizedBox(height: 10),
        ],
        WhiteCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColours.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: AppColours.blue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isManagement
                          ? text.t("Today's Reviews")
                          : text.t("Today's Progress"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isManagement
                          ? text.t('Submissions Reviewed')
                          : text.t('Daily Photos'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    isManagement
                        ? '$doneReviewCount/$totalReviewCount'
                        : '$photoCount/$photoMinimum',
                    style: const TextStyle(
                      fontSize: AppTextSize.s15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: isManagement
                      ? (totalReviewCount == 0 ? 0 : doneReviewCount / totalReviewCount)
                      : photoProgress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFD1D1D6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF050014),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ProgressInfoCard(
                      title: isManagement
                          ? text.t('Pending Review')
                          : text.t('Photos Taken'),
                      value: isManagement
                          ? '$pendingReviewCount'
                          : '$photoCount',
                      colour: AppColours.green,
                      background: AppColours.greenSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProgressInfoCard(
                      title: isManagement ? text.t('Done') : text.t('Pending'),
                      value: isManagement
                          ? '$doneReviewCount'
                          : '${(photoMinimum - photoCount).clamp(0, photoMinimum)}',
                      colour: const Color(0xFFC73500),
                      background: AppColours.orangeSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ReportSnapshotCard(
          dashboard: reportDashboard,
          isManagement: isManagement,
          onTap: widget.onReports,
        ),
        const SizedBox(height: 10),
        _HomeMenuGrid(
          children: [
            _ActionTile(
              label: isManagement ? text.t('Approvals') : text.t('Report'),
              icon: isManagement
                  ? Icons.fact_check_outlined
                  : Icons.analytics_outlined,
              colour: AppColours.blueSoft,
              onTap: widget.onViewTasks,
            ),
            _ActionTile(
              label: isManagement ? text.t('Knowledge') : text.t('Rewards'),
              icon: isManagement
                  ? Icons.menu_book_outlined
                  : Icons.workspace_premium_outlined,
              colour: AppColours.green,
              onTap: isManagement ? widget.onKnowledge : widget.onRewards,
            ),
            _ActionTile(
              label: text.t('Leaderboard'),
              icon: Icons.trending_up_rounded,
              colour: AppColours.purple,
              onTap: widget.onRanking,
            ),
            if (widget.isOwner)
              _ActionTile(
                label: text.t('Advertisement'),
                icon: Icons.campaign_outlined,
                colour: AppColours.blue,
                onTap: () => _openAdvertisementManager(context),
              ),
            _ActionTile(
              label: text.t('Career Path'),
              icon: Icons.track_changes_rounded,
              colour: AppColours.orange,
              onTap: () => showTemporaryDisabledMessage(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        WhiteCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColours.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star_border_rounded,
                        color: AppColours.blue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text.t('Recent Activity'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.s16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...homeRecentActivities.map(
                (item) => _RecentActivityRow(activity: item),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _ReportSnapshotCard extends StatelessWidget {
  final ReportDashboard? dashboard;
  final bool isManagement;
  final VoidCallback onTap;

  const _ReportSnapshotCard({
    required this.dashboard,
    required this.isManagement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = dashboard;
    final firstValue = isManagement
        ? 'RM ${(data?.sales?.netSalesRm ?? 0).toStringAsFixed(2)}'
        : '${data?.dailyPhotos.currentUserPhotoCount ?? 0}/${data?.dailyPhotos.minimumRequired ?? 5}';
    final firstLabel = isManagement ? 'Total Sales Today' : 'Daily Photos';
    final secondValue = isManagement
        ? '${data?.inventory?.healthScorePercent.toStringAsFixed(0) ?? '0'}%'
        : (data?.dailyPhotos.currentUserComplete == true ? 'Complete' : 'Pending');
    final secondLabel = isManagement ? 'Stock Health' : 'Submission';
    final thirdValue = isManagement
        ? '${data?.complaints?.openCount ?? 0}'
        : '${data?.pendingApprovals ?? 0}';
    final thirdLabel = isManagement ? 'Open Complaints' : 'Review Status';

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF091B4D), Color(0xFF1557F2)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: Colors.white, size: 21),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Report Intelligence',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _ReportSnapshotMetric(label: firstLabel, value: firstValue)),
                  const SizedBox(width: 8),
                  Expanded(child: _ReportSnapshotMetric(label: secondLabel, value: secondValue)),
                  const SizedBox(width: 8),
                  Expanded(child: _ReportSnapshotMetric(label: thirdLabel, value: thirdValue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSnapshotMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReportSnapshotMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTextSize.s16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: AppTextSize.s10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleRatingCard extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final String businessName;
  final int refreshSignal;

  const _GoogleRatingCard({
    required this.api,
    required this.tenantId,
    required this.businessName,
    required this.refreshSignal,
  });

  @override
  State<_GoogleRatingCard> createState() => _GoogleRatingCardState();
}

class _GoogleRatingCardState extends State<_GoogleRatingCard> {
  EastAppGoogleRating? rating;
  String? error;
  bool loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _GoogleRatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId ||
        oldWidget.refreshSignal != widget.refreshSignal) {
      load();
    }
  }

  Future<void> load() async {
    final loadGeneration = ++_loadGeneration;
    final tenantId = widget.tenantId;
    final cached = _googleRatingCache[tenantId];
    final now = DateTime.now();

    if (cached != null) {
      setState(() {
        rating = cached.value;
        error = null;
        loading = false;
      });
      if (cached.isFresh(now)) {
        return;
      }
    } else {
      setState(() {
        loading = true;
        error = null;
        rating = null;
      });
    }

    try {
      final value = await _refreshGoogleRating(widget.api, tenantId);
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          tenantId != widget.tenantId) {
        return;
      }
      setState(() {
        rating = value;
        error = null;
        loading = false;
      });
    } on EastAppApiException catch (apiError) {
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          tenantId != widget.tenantId) {
        return;
      }
      setState(() {
        if (cached == null) {
          error = apiError.message;
        }
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = rating;
    return WhiteCard(
      padding: const EdgeInsets.all(12),
      child: loading
          ? const SizedBox(
              height: 72,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : error != null
              ? Row(
                  children: [
                    const Icon(
                      Icons.star_outline_rounded,
                      color: AppColours.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Google rating unavailable',
                            style: TextStyle(
                              fontSize: AppTextSize.s15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            error!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTextSize.s12,
                              color: AppColours.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retry',
                      onPressed: load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1D6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFE39A00),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data?.placeName.isNotEmpty == true
                                ? data!.placeName
                                : widget.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTextSize.s16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            data?.formattedAddress ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTextSize.s12,
                              color: AppColours.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Image.network(
                            'https://maps.gstatic.com/mapfiles/api-3/images/powered-by-google-on-white3.png',
                            height: 14,
                            errorBuilder: (_, _, _) => const Text(
                              'Google Maps',
                              style: TextStyle(
                                fontSize: AppTextSize.s12,
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          data?.rating == null
                              ? '—'
                              : data!.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: AppTextSize.s26,
                            fontWeight: FontWeight.w800,
                            color: AppColours.textMain,
                          ),
                        ),
                        Text(
                          data?.userRatingCount == null
                              ? 'No ratings yet'
                              : '${data!.userRatingCount} reviews',
                          style: const TextStyle(
                            fontSize: AppTextSize.s12,
                            color: AppColours.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

class _ProgressInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color colour;
  final Color background;

  const _ProgressInfoCard({
    required this.title,
    required this.value,
    required this.colour,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colour,
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colour,
              fontSize: AppTextSize.s18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const _HomeMenuGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 330;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: cardWidth, height: 100, child: child))
              .toList(),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color colour;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.colour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColours.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  final RecentActivity activity;

  const _RecentActivityRow({
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColours.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSize.s16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${activity.score}',
                style: const TextStyle(
                  fontSize: AppTextSize.s16,
                  fontWeight: FontWeight.w800,
                  color: AppColours.blue,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColours.greenSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  activity.status,
                  style: TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _AdvertisementCarousel extends StatefulWidget {
  static const double bannerAspectRatio = 3.45;

  final EastAppApi api;
  final List<Advertisement> advertisements;

  const _AdvertisementCarousel({
    required this.api,
    required this.advertisements,
  });

  @override
  State<_AdvertisementCarousel> createState() =>
      _AdvertisementCarouselState();
}

class _AdvertisementCarouselState extends State<_AdvertisementCarousel> {
  final PageController _controller = PageController();
  Timer? _autoAdvanceTimer;
  int _page = 0;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _scheduleNextPage();
  }

  @override
  void didUpdateWidget(covariant _AdvertisementCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAdvertisementIds(
      oldWidget.advertisements,
      widget.advertisements,
    )) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(0);
        }
      });
      _scheduleNextPage();
    }
  }

  bool _sameAdvertisementIds(
    List<Advertisement> first,
    List<Advertisement> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index].id != second[index].id ||
          first[index].imageStorageKey != second[index].imageStorageKey) {
        return false;
      }
    }
    return true;
  }

  void _scheduleNextPage() {
    _autoAdvanceTimer?.cancel();
    if (_userScrolling || widget.advertisements.length <= 1) return;
    _autoAdvanceTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.advertisements.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScrolling = true;
      _autoAdvanceTimer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _userScrolling = false;
      _scheduleNextPage();
    }
    return false;
  }

  Future<void> _enlarge(Advertisement advertisement) async {
    _autoAdvanceTimer?.cancel();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.api.reportMediaUrl(
                    advertisement.imageStorageKey,
                  ),
                  headers: widget.api.authenticatedImageHeaders,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) _scheduleNextPage();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: _AdvertisementCarousel.bannerAspectRatio,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.advertisements.length,
              onPageChanged: (value) {
                if (mounted) setState(() => _page = value);
                if (!_userScrolling) _scheduleNextPage();
              },
              itemBuilder: (_, index) {
                final advertisement = widget.advertisements[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Pressable(
                    onTap: () => _enlarge(advertisement),
                    borderRadius: BorderRadius.circular(18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        widget.api.reportMediaUrl(
                          advertisement.imageStorageKey,
                        ),
                        headers: widget.api.authenticatedImageHeaders,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, _) {
                          if (frame != null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.advertisements.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.advertisements.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _page ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == _page ? AppColours.blue : Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdvertisementManagerScreen extends StatefulWidget {
  final EastAppApi api;

  const _AdvertisementManagerScreen({required this.api});

  @override
  State<_AdvertisementManagerScreen> createState() =>
      _AdvertisementManagerScreenState();
}

class _AdvertisementManagerScreenState
    extends State<_AdvertisementManagerScreen> {
  List<Advertisement> items = const [];
  bool loading = true;
  bool mutating = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final value = await widget.api.advertisements();
      if (!mounted) return;
      setState(() {
        items = value;
        loading = false;
      });
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = error.message;
      });
    }
  }

  Future<void> edit([Advertisement? advertisement]) async {
    if (mutating) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdvertisementEditor(
          api: widget.api,
          advertisement: advertisement,
        ),
      ),
    );
    if (changed == true) await load();
  }

  Future<void> deleteAdvertisement(Advertisement advertisement) async {
    if (mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Advertisement?'),
        content: const Text(
          'This advertisement will be removed permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => mutating = true);
    try {
      await widget.api.deleteAdvertisement(advertisement.id);
      await load();
    } on EastAppApiException {
      return;
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  String statusLabel(Advertisement advertisement) {
    return switch (advertisement.publicationStatus(DateTime.now())) {
      AdvertisementPublicationStatus.published => 'Published',
      AdvertisementPublicationStatus.scheduled => 'Scheduled',
      AdvertisementPublicationStatus.expired => 'Expired',
      AdvertisementPublicationStatus.inactive => 'Inactive',
    };
  }

  Color statusColour(Advertisement advertisement) {
    return switch (advertisement.publicationStatus(DateTime.now())) {
      AdvertisementPublicationStatus.published => AppColours.green,
      AdvertisementPublicationStatus.scheduled => AppColours.blue,
      AdvertisementPublicationStatus.expired => AppColours.textMuted,
      AdvertisementPublicationStatus.inactive => AppColours.orange,
    };
  }

  String formatDateTime(BuildContext context, DateTime value) {
    final localisations = MaterialLocalizations.of(context);
    final date = localisations.formatMediumDate(value);
    final time = TimeOfDay.fromDateTime(value).format(context);
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advertisement')),
      floatingActionButton: FloatingActionButton(
        onPressed: mutating ? null : () => edit(),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loadError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : items.isEmpty
                  ? const Center(child: Text('No advertisements yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final advertisement = items[index];
                        final status = statusLabel(advertisement);
                        final colour = statusColour(advertisement);
                        return WhiteCard(
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.api.reportMediaUrl(
                                    advertisement.imageStorageKey,
                                  ),
                                  headers:
                                      widget.api.authenticatedImageHeaders,
                                  width: 72,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 72,
                                    height: 48,
                                    alignment: Alignment.center,
                                    color: AppColours.background,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                formatDateTime(
                                  context,
                                  advertisement.startsAt,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Until ${formatDateTime(context, advertisement.endsAt)}\n'
                                  '$status · Position ${advertisement.displayOrder + 1}',
                                ),
                              ),
                              isThreeLine: true,
                              onTap: mutating
                                  ? null
                                  : () => edit(advertisement),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: colour,
                                ),
                                onPressed: mutating
                                    ? null
                                    : () => deleteAdvertisement(
                                          advertisement,
                                        ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _AdvertisementEditor extends StatefulWidget {
  final EastAppApi api;
  final Advertisement? advertisement;

  const _AdvertisementEditor({
    required this.api,
    this.advertisement,
  });

  @override
  State<_AdvertisementEditor> createState() => _AdvertisementEditorState();
}

class _AdvertisementEditorState extends State<_AdvertisementEditor> {
  final ImagePicker picker = ImagePicker();
  String? imageStorageKey;
  DateTime? startsAt;
  DateTime? endsAt;
  int displayOrder = 0;
  bool active = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final advertisement = widget.advertisement;
    if (advertisement != null) {
      imageStorageKey = advertisement.imageStorageKey;
      startsAt = advertisement.startsAt;
      endsAt = advertisement.endsAt;
      displayOrder = advertisement.displayOrder;
      active = advertisement.active;
    }
  }

  Future<DateTime?> pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String formatDateTime(DateTime? value) {
    if (value == null) return 'Select';
    final localisations = MaterialLocalizations.of(context);
    final date = localisations.formatMediumDate(value);
    final time = TimeOfDay.fromDateTime(value).format(context);
    return '$date · $time';
  }

  Future<void> chooseImage() async {
    if (busy) return;
    final selected = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (selected == null || !mounted) return;

    setState(() => busy = true);
    try {
      final uploaded = await widget.api.uploadReportImage(selected.path);
      if (mounted) setState(() => imageStorageKey = uploaded);
    } on EastAppApiException {
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (imageStorageKey == null || startsAt == null || endsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image, start date/time and end date/time are compulsory.',
          ),
        ),
      );
      return;
    }
    if (!endsAt!.isAfter(startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'End date and time must be later than start date and time.',
          ),
        ),
      );
      return;
    }

    setState(() => busy = true);
    try {
      if (widget.advertisement == null) {
        await widget.api.createAdvertisement(
          imageStorageKey: imageStorageKey!,
          startsAt: startsAt!,
          endsAt: endsAt!,
          displayOrder: displayOrder,
          active: active,
        );
      } else {
        await widget.api.updateAdvertisement(
          id: widget.advertisement!.id,
          imageStorageKey: imageStorageKey!,
          startsAt: startsAt!,
          endsAt: endsAt!,
          displayOrder: displayOrder,
          active: active,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on EastAppApiException {
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.advertisement == null
                ? 'Create Advertisement'
                : 'Edit Advertisement',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : chooseImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                imageStorageKey == null
                    ? 'Upload advertisement image'
                    : 'Replace image',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a wide banner image. Recommended ratio: 3.45:1.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColours.textMuted,
                fontSize: AppTextSize.s12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (imageStorageKey != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: _AdvertisementCarousel.bannerAspectRatio,
                  child: Image.network(
                    widget.api.reportMediaUrl(imageStorageKey!),
                    headers: widget.api.authenticatedImageHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start date & time *'),
              subtitle: Text(formatDateTime(startsAt)),
              trailing: const Icon(Icons.calendar_month),
              enabled: !busy,
              onTap: () async {
                final value = await pickDateTime(startsAt);
                if (value != null && mounted) {
                  setState(() => startsAt = value);
                }
              },
            ),
            ListTile(
              title: const Text('End date & time *'),
              subtitle: Text(formatDateTime(endsAt)),
              trailing: const Icon(Icons.calendar_month),
              enabled: !busy,
              onTap: () async {
                final value = await pickDateTime(endsAt);
                if (value != null && mounted) {
                  setState(() => endsAt = value);
                }
              },
            ),
            DropdownButtonFormField<int>(
              initialValue: displayOrder,
              decoration: const InputDecoration(
                labelText: 'Carousel position',
              ),
              items: List.generate(
                4,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text('Position ${index + 1}'),
                ),
              ),
              onChanged: busy
                  ? null
                  : (value) => setState(() => displayOrder = value ?? 0),
            ),
            SwitchListTile(
              value: active,
              onChanged: busy
                  ? null
                  : (value) => setState(() => active = value),
              title: const Text('Active'),
              subtitle: const Text(
                'Only active advertisements publish during their schedule.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy ? 'Processing... Please Wait!' : 'Save Advertisement',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
