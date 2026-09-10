import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/storage_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class StorageManagementScreen extends StatefulWidget {
  final EastAppApi api;

  const StorageManagementScreen({
    super.key,
    required this.api,
  });

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  StorageOverview? overview;
  bool loading = true;
  String? cleaningKey;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final value = await widget.api.storageOverview();
      if (!mounted) return;
      setState(() {
        overview = value;
        loading = false;
      });
    } on EastAppApiException {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> cleanup(StorageCleanupAction action) async {
    if (cleaningKey != null) return;
    final confirmed = await confirmDataChange(
      context,
      action: 'Permanently delete old ${action.title.toLowerCase()}?',
      confirmLabel: 'Delete permanently',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action.description,
            style: const TextStyle(
              color: AppColours.textMain,
              fontSize: AppTextSize.s14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This deletes matching old data across all company codes and cannot be undone. PostgreSQL will reuse the freed space, but the physical table size may not reduce immediately.',
            style: TextStyle(
              color: AppColours.red,
              fontSize: AppTextSize.s13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (!confirmed || !mounted) return;

    setState(() => cleaningKey = action.key);
    try {
      final result = await widget.api.cleanupStorage(action.key);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Storage cleanup completed: ${result.deletedRows} rows deleted',
      );
      await load();
    } on EastAppApiException {
      // The shared API error dialog already explains the failure.
    } finally {
      if (mounted) setState(() => cleaningKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final value = overview;

    return Scaffold(
      backgroundColor: AppColours.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: IconButton(
                      onPressed: Navigator.of(context).pop,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Expanded(
                    child: PageTitle(
                      title: text.t('Storage & Cleanup'),
                      subtitle: text.t('Database use and 30-day cleanup'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: IconButton(
                      tooltip: text.t('Refresh'),
                      onPressed: loading ? null : load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                ],
              ),
              if (loading && value == null)
                const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (value == null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(text.t('Try again')),
                    ),
                  ),
                )
              else ...[
                _StorageSummary(overview: value),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: text.t('Operational cleanup'),
                  subtitle: text.t(
                    'Only growing history is removable. Setup and master data are protected.',
                  ),
                ),
                const SizedBox(height: 10),
                ...value.cleanupActions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CleanupCard(
                      action: action,
                      busy: cleaningKey != null,
                      onDelete: () => cleanup(action),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SectionTitle(
                  title: text.t('All database tables'),
                  subtitle: text.t(
                    'Rows are PostgreSQL estimates. Sizes include stored data and indexes.',
                  ),
                ),
                const SizedBox(height: 10),
                WhiteCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var index = 0;
                          index < value.tables.length;
                          index++) ...[
                        _TableUsageTile(table: value.tables[index]),
                        if (index != value.tables.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.overview});

  final StorageOverview overview;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'Database',
              value: formatBytes(overview.databaseBytes),
            ),
          ),
          Container(width: 1, height: 44, color: AppColours.border),
          Expanded(
            child: _SummaryMetric(
              label: 'Application tables',
              value: formatBytes(overview.applicationTablesBytes),
            ),
          ),
          Container(width: 1, height: 44, color: AppColours.border),
          Expanded(
            child: _SummaryMetric(
              label: 'Tables',
              value: '${overview.tables.length}',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColours.textMain,
              fontSize: AppTextSize.s17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColours.textMain,
            fontSize: AppTextSize.s17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: AppTextStyles.formHint),
      ],
    );
  }
}

class _CleanupCard extends StatelessWidget {
  const _CleanupCard({
    required this.action,
    required this.busy,
    required this.onDelete,
  });

  final StorageCleanupAction action;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(
                    color: AppColours.textMain,
                    fontSize: AppTextSize.s15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(label: '${action.retentionDays} days'),
            ],
          ),
          const SizedBox(height: 5),
          Text(action.description, style: AppTextStyles.formHint),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Related tables: ${formatBytes(action.currentBytes)}',
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontSize: AppTextSize.s12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Delete old'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColours.blue.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColours.blue,
          fontSize: AppTextSize.s11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TableUsageTile extends StatelessWidget {
  const _TableUsageTile({required this.table});

  final StorageTableUsage table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  table.tableName,
                  style: const TextStyle(
                    color: AppColours.textMain,
                    fontSize: AppTextSize.s13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatBytes(table.totalBytes),
                style: const TextStyle(
                  color: AppColours.blue,
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${table.group} · ${table.dataUse}',
            style: AppTextStyles.formHint.copyWith(fontSize: AppTextSize.s12),
          ),
          const SizedBox(height: 5),
          Text(
            '~${table.estimatedRows} rows  ·  Data ${formatBytes(table.dataBytes)}  ·  Index ${formatBytes(table.indexBytes)}',
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}
