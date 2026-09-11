import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String? cleaningTable;
  String? viewingTable;

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

  Future<void> cleanup(StorageTableUsage table) async {
    if (cleaningTable != null || viewingTable != null || table.deletableRows < 1) {
      return;
    }
    final rowCount = await _chooseDeleteCount(table);
    if (rowCount == null || !mounted) return;

    setState(() => cleaningTable = table.tableName);
    try {
      final result = await widget.api.cleanupStorage(table.tableName, rowCount);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Storage cleanup completed: ${result.deletedRows} oldest rows deleted from ${table.tableName}',
      );
      await load();
    } on EastAppApiException {
      // The shared API error dialog already explains the failure.
    } finally {
      if (mounted) setState(() => cleaningTable = null);
    }
  }

  Future<void> viewTable(StorageTableUsage table) async {
    final value = overview;
    if (value == null ||
        cleaningTable != null ||
        viewingTable != null ||
        table.rowCount < 1) {
      return;
    }
    final selection = await _chooseViewOptions(table, value.maxViewRows);
    if (selection == null || !mounted) return;

    StorageTableData? tableData;
    setState(() => viewingTable = table.tableName);
    try {
      tableData = await widget.api.storageTableData(
        table.tableName,
        selection.rowCount,
        selection.latestFirst,
      );
    } on EastAppApiException {
      // The shared API error dialog already explains the failure.
    } finally {
      if (mounted) setState(() => viewingTable = null);
    }
    if (tableData != null && mounted) {
      await _showTableData(tableData, selection.latestFirst);
    }
  }

  Future<({int rowCount, bool latestFirst})?> _chooseViewOptions(
    StorageTableUsage table,
    int maxViewRows,
  ) async {
    final maximum = table.rowCount < maxViewRows ? table.rowCount : maxViewRows;
    final initial = maximum < 10 ? maximum : 10;
    final controller = TextEditingController(text: '$initial');
    var latestFirst = true;
    String? errorText;
    final selected = await showDialog<({int rowCount, bool latestFirst})>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final text = AppTextScope.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(text.t('View table rows')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<bool>(
                  initialValue: latestFirst,
                  decoration: InputDecoration(labelText: text.t('View order')),
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text(text.t('Latest first')),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text(text.t('Oldest first')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => latestFirst = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: text.t('Rows to view'),
                    helperText: '${text.t('Maximum per view')}: $maximum',
                    errorText: errorText == null ? null : text.t(errorText!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(text.t('Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value == null || value < 1 || value > maximum) {
                    setDialogState(
                      () => errorText = 'Enter a valid row count.',
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop((
                    rowCount: value,
                    latestFirst: latestFirst,
                  ));
                },
                child: Text(text.t('View')),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return selected;
  }

  Future<void> _showTableData(
    StorageTableData table,
    bool latestFirst,
  ) async {
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text = AppTextScope.of(dialogContext);
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: AppColours.background,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(table.tableName),
                  Text(
                    '${table.returnedRows} ${text.t('rows')}',
                    style: const TextStyle(fontSize: AppTextSize.s12),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: text.t('Close'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t(
                      latestFirst
                          ? 'Latest rows are shown first where a date is available. Sensitive values are redacted and binary data is shown by byte size.'
                          : 'Oldest rows are shown first where a date is available. Sensitive values are redacted and binary data is shown by byte size.',
                    ),
                    style: AppTextStyles.formHint,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Scrollbar(
                      controller: verticalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: verticalController,
                        child: Scrollbar(
                          controller: horizontalController,
                          thumbVisibility: true,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              border: TableBorder.all(color: AppColours.border),
                              columnSpacing: 18,
                              horizontalMargin: 12,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 132,
                              columns: table.columns
                                  .map(
                                    (column) => DataColumn(
                                      label: SizedBox(
                                        width: 190,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              column.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '${column.dataType}${column.nullable ? ' · NULL' : ''}',
                                              style: AppTextStyles.formHint
                                                  .copyWith(
                                                fontSize: AppTextSize.s10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              rows: table.rows
                                  .map(
                                    (row) => DataRow(
                                      cells: row
                                          .map(
                                            (value) => DataCell(
                                              SizedBox(
                                                width: 190,
                                                child: SelectableText(
                                                  value ?? 'NULL',
                                                  maxLines: 6,
                                                  style: TextStyle(
                                                    color: value == null
                                                        ? AppColours.textMuted
                                                        : AppColours.textMain,
                                                    fontSize: AppTextSize.s12,
                                                    fontStyle: value == null
                                                        ? FontStyle.italic
                                                        : FontStyle.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    verticalController.dispose();
    horizontalController.dispose();
  }

  Future<int?> _chooseDeleteCount(StorageTableUsage table) async {
    final controller = TextEditingController(text: '1');
    String? errorText;
    final selected = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final text = AppTextScope.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColours.orange,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(text.t('Delete oldest rows?'))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t(table.deleteDescription ?? ''),
                    style: const TextStyle(
                      color: AppColours.textMain,
                      fontSize: AppTextSize.s14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: text.t('Rows to delete'),
                      helperText: '${text.t('Maximum safely deletable')}: '
                          '${table.deletableRows}',
                      errorText: errorText == null ? null : text.t(errorText!),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    text.t(
                      'This permanently deletes the oldest selected rows across all company codes. Related dependent rows may also be deleted. This cannot be undone.',
                    ),
                    style: const TextStyle(
                      color: AppColours.red,
                      fontSize: AppTextSize.s13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(text.t('Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value == null ||
                      value < 1 ||
                      value > table.deletableRows) {
                    setDialogState(
                      () => errorText = 'Enter a valid row count.',
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: Text(text.t('Delete permanently')),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final value = overview;
    final deletableTables = value?.tables
            .where((table) => table.deleteAllowed)
            .toList(growable: false) ??
        const <StorageTableUsage>[];
    final nonDeletableTables = value?.tables
            .where((table) => !table.deleteAllowed)
            .toList(growable: false) ??
        const <StorageTableUsage>[];

    return Scaffold(
      backgroundColor: AppColours.background,
      body: AppProcessingOverlay(
        isProcessing: cleaningTable != null || viewingTable != null,
        child: SafeArea(
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
                        subtitle: text.t('Database use and manual cleanup'),
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
                    title: text.t('Deletable tables'),
                    subtitle: text.t(
                      'Only safely eligible rows can be deleted. View shows table columns and selected rows.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...deletableTables.map(
                    (table) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TableUsageCard(
                        table: table,
                        busy: cleaningTable != null || viewingTable != null,
                        onView: () => viewTable(table),
                        onDelete: () => cleanup(table),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SectionTitle(
                    title: text.t('Non-deletable tables'),
                    subtitle: text.t(
                      'Direct deletion is protected. Child rows may still be removed through a safely deleted parent.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...nonDeletableTables.map(
                    (table) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TableUsageCard(
                        table: table,
                        busy: cleaningTable != null || viewingTable != null,
                        onView: () => viewTable(table),
                        onDelete: () => cleanup(table),
                      ),
                    ),
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

class _TableUsageCard extends StatelessWidget {
  const _TableUsageCard({
    required this.table,
    required this.busy,
    required this.onView,
    required this.onDelete,
  });

  final StorageTableUsage table;
  final bool busy;
  final VoidCallback onView;
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
                  table.tableName,
                  style: const TextStyle(
                    color: AppColours.textMain,
                    fontSize: AppTextSize.s14,
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
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusChip(
                icon: Icons.table_rows_rounded,
                label: '${table.rowCount} rows',
              ),
              _StatusChip(
                icon: Icons.history_rounded,
                label: 'Oldest ${formatTableDate(table.oldestDate)}',
              ),
              _StatusChip(
                icon: Icons.update_rounded,
                label: 'Latest ${formatTableDate(table.latestDate)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data ${formatBytes(table.dataBytes)}  ·  Index ${formatBytes(table.indexBytes)}',
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (table.deleteAllowed) ...[
            const SizedBox(height: 10),
            Text(
              AppTextScope.of(context).t(table.deleteDescription ?? ''),
              style: AppTextStyles.formHint.copyWith(fontSize: AppTextSize.s12),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  table.deleteAllowed
                      ? '${table.deletableRows} safely deletable'
                      : 'Direct deletion protected',
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontSize: AppTextSize.s12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy || table.rowCount < 1 ? null : onView,
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: Text(AppTextScope.of(context).t('View')),
              ),
              if (table.deleteAllowed) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy || table.deletableRows < 1 ? null : onDelete,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(AppTextScope.of(context).t('Delete')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColours.blue.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColours.blue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColours.blue,
              fontSize: AppTextSize.s11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String formatTableDate(DateTime? date) {
  if (date == null) return '—';
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
  final day = date.day.toString().padLeft(2, '0');
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '$day-${months[date.month - 1]}-$year';
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
