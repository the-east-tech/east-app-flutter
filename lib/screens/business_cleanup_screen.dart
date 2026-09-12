import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_text_scope.dart';
import '../models/storage_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class BusinessCleanupScreen extends StatefulWidget {
  final EastAppApi api;

  const BusinessCleanupScreen({
    super.key,
    required this.api,
  });

  @override
  State<BusinessCleanupScreen> createState() => _BusinessCleanupScreenState();
}

class _BusinessCleanupScreenState extends State<BusinessCleanupScreen> {
  final Set<BusinessCleanupDataType> dataTypes = <BusinessCleanupDataType>{};
  final Set<BusinessCleanupMediaType> mediaTypes =
      BusinessCleanupMediaType.values.toSet();

  late DateTime cutoffDate;
  BusinessCleanupMediaMode mediaMode = BusinessCleanupMediaMode.all;
  BusinessCleanupPreview? preview;
  List<BusinessCleanupRun> runs = const [];
  bool loadingRuns = true;
  bool working = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    cutoffDate = DateTime(now.year, now.month - 6, now.day);
    unawaited(loadRuns());
  }

  BusinessCleanupSelection get selection => BusinessCleanupSelection(
        dataTypes: Set.unmodifiable(dataTypes),
        cutoffDate: cutoffDate,
        mediaMode: mediaMode,
        mediaTypes: Set.unmodifiable(mediaTypes),
      );

  bool get selectionReady =>
      dataTypes.isNotEmpty &&
      (mediaMode != BusinessCleanupMediaMode.selected ||
          mediaTypes.isNotEmpty);

  void selectionChanged(VoidCallback change) {
    setState(() {
      change();
      preview = null;
    });
  }

  Future<void> loadRuns() async {
    try {
      final value = await widget.api.businessCleanupRuns();
      if (!mounted) return;
      setState(() {
        runs = value;
        loadingRuns = false;
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingRuns = false);
    }
  }

  Future<void> chooseCutoffDate() async {
    if (working) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: cutoffDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    selectionChanged(() => cutoffDate = selected);
  }

  Future<void> previewCleanup() async {
    if (working || !selectionReady) return;
    setState(() => working = true);
    try {
      final value = await widget.api.previewBusinessCleanup(selection);
      if (!mounted) return;
      setState(() => preview = value);
    } on EastAppApiException {
      // Shared API error handling explains the failure.
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> createBackup() async {
    final currentPreview = preview;
    if (working || currentPreview == null || currentPreview.recordCount < 1) {
      return;
    }
    setState(() => working = true);
    try {
      final backup = await widget.api.createBusinessCleanupBackup(selection);
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: AppTextScope.of(context).t('Save Business Backup'),
          text: AppTextScope.of(context).t(
            'Save this ZIP to Google Drive or another safe location before cleanup.',
          ),
          files: [
            XFile.fromData(backup.bytes, mimeType: 'application/zip'),
          ],
          fileNameOverrides: [backup.fileName],
          sharePositionOrigin: renderBox == null || !renderBox.hasSize
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
          downloadFallbackEnabled: true,
        ),
      );
      await loadRuns();
      if (!mounted || result.status != ShareResultStatus.success) return;
      BusinessCleanupRun? run;
      for (final item in runs) {
        if (item.id == backup.runId) {
          run = item;
          break;
        }
      }
      if (run != null) await askConfirmSaved(run);
    } on EastAppApiException {
      // Shared API error handling explains the failure.
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Unable to share the backup ZIP.');
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> askConfirmSaved(BusinessCleanupRun run) async {
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final text = AppTextScope.of(dialogContext);
            return AlertDialog(
              title: Text(text.t('Backup saved?')),
              content: Text(
                text.t(
                  'Confirm only after the ZIP is visible in Google Drive or another safe location. The app cannot verify the upload.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(text.t('Not yet')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(text.t('Yes, saved')),
                ),
              ],
            );
          },
        ) ??
        false;
    if (confirmed && mounted) await confirmSaved(run);
  }

  Future<void> confirmSaved(BusinessCleanupRun run) async {
    setState(() => working = true);
    try {
      await widget.api.confirmBusinessCleanupSaved(run.id);
      await loadRuns();
      if (mounted) showSuccessSnackBar(context, 'Backup marked as saved.');
    } on EastAppApiException {
      // Shared API error handling explains the failure.
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> deletePermanently(BusinessCleanupRun run) async {
    if (working) return;
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final text = AppTextScope.of(dialogContext);
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColours.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text.t('Delete permanently?'))),
                ],
              ),
              content: Text(
                text.t(
                  '${run.recordCount} business records and their dependent data will be permanently deleted. Photos are deleted only when no retained record references them. This cannot be undone.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(text.t('Cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColours.red),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(text.t('Delete permanently')),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => working = true);
    try {
      final result = await widget.api.completeBusinessCleanup(run.id);
      await loadRuns();
      if (!mounted) return;
      setState(() => preview = null);
      showSuccessSnackBar(
        context,
        '${result.deletedRecordCount} records and ${result.deletedPhotoCount} orphaned photos deleted.',
      );
    } on EastAppApiException {
      // Shared API error handling explains the failure.
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Scaffold(
      backgroundColor: AppColours.background,
      body: AppProcessingOverlay(
        isProcessing: working,
        child: SafeArea(
          child: ListView(
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
                      title: text.t('Business Backup & Cleanup'),
                      subtitle: text.t(
                        'Back up selected business data before permanent cleanup',
                      ),
                    ),
                  ),
                ],
              ),
              _sectionTitle(
                text.t('1. Choose business data'),
                text.t('Only completed, old or safely inactive data is eligible.'),
              ),
              const SizedBox(height: 10),
              WhiteCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: BusinessCleanupDataType.values
                      .map(
                        (type) => CheckboxListTile(
                          value: dataTypes.contains(type),
                          title: Text(text.t(type.label)),
                          subtitle: Text(text.t(_dataDescription(type))),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: working
                              ? null
                              : (selected) => selectionChanged(() {
                                    if (selected ?? false) {
                                      dataTypes.add(type);
                                    } else {
                                      dataTypes.remove(type);
                                    }
                                  }),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                text.t('2. Choose cutoff date'),
                text.t('Records before this date are considered.'),
              ),
              const SizedBox(height: 10),
              WhiteCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: chooseCutoffDate,
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColours.blue,
                  ),
                  title: Text(
                    formatCleanupDate(cutoffDate),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                text.t('3. Choose photo backup'),
                text.t('Like a chat archive, include all, selected, or no media.'),
              ),
              const SizedBox(height: 10),
              WhiteCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ...BusinessCleanupMediaMode.values.map(
                      (mode) => RadioListTile<BusinessCleanupMediaMode>(
                        value: mode,
                        groupValue: mediaMode,
                        title: Text(text.t(mode.label)),
                        onChanged: working
                            ? null
                            : (value) {
                                if (value != null) {
                                  selectionChanged(() => mediaMode = value);
                                }
                              },
                      ),
                    ),
                    if (mediaMode == BusinessCleanupMediaMode.selected) ...[
                      const Divider(height: 1),
                      ...BusinessCleanupMediaType.values.map(
                        (type) => CheckboxListTile(
                          dense: true,
                          value: mediaTypes.contains(type),
                          title: Text(text.t(type.label)),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: working
                              ? null
                              : (selected) => selectionChanged(() {
                                    if (selected ?? false) {
                                      mediaTypes.add(type);
                                    } else {
                                      mediaTypes.remove(type);
                                    }
                                  }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (mediaMode != BusinessCleanupMediaMode.all) ...[
                const SizedBox(height: 10),
                _warning(
                  text.t(
                    'Excluded photos will not be in the ZIP. During cleanup they are permanently deleted only if no retained record references them.',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: selectionReady && !working ? previewCleanup : null,
                  icon: const Icon(Icons.preview_outlined),
                  label: Text(text.t('Preview backup & cleanup')),
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 16),
                _PreviewCard(preview: preview!),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: preview!.recordCount > 0 && !working
                        ? createBackup
                        : null,
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(text.t('Create & save backup ZIP')),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _sectionTitle(
                text.t('Recent backup & cleanup'),
                text.t('The ZIP itself is not stored in the database.'),
              ),
              const SizedBox(height: 10),
              if (loadingRuns)
                const Center(child: CircularProgressIndicator())
              else if (runs.isEmpty)
                WhiteCard(child: Text(text.t('No backup records yet.')))
              else
                ...runs.map(
                  (run) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RunCard(
                      run: run,
                      busy: working,
                      onConfirm: () => askConfirmSaved(run),
                      onDelete: () => deletePermanently(run),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final BusinessCleanupPreview preview;

  const _PreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.t('Preview'),
            style: const TextStyle(
              fontSize: AppTextSize.s17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('${preview.recordCount}', text.t('records')),
              _metric('${preview.photoCount}', text.t('photos in ZIP')),
              _metric(
                formatCleanupBytes(preview.estimatedZipBytes),
                text.t('estimated ZIP'),
              ),
              if (preview.excludedPhotoCount > 0)
                _metric(
                  '${preview.excludedPhotoCount}',
                  text.t('photos excluded'),
                ),
              if (preview.blockedRecordCount > 0)
                _metric(
                  '${preview.blockedRecordCount}',
                  text.t('inactive records blocked'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...preview.categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text.t(category.dataType.label),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${category.recordCount}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (category.blockedRecordCount > 0)
                    Text(
                      ' · ${category.blockedRecordCount} ${text.t('blocked')}',
                      style: const TextStyle(color: AppColours.orange),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final BusinessCleanupRun run;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  const _RunCard({
    required this.run,
    required this.busy,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final status = run.isCompleted
        ? 'Cleanup completed'
        : run.isSavedConfirmed
            ? 'Backup saved — ready to clean'
            : 'Waiting for saved confirmation';
    final colour = run.isCompleted
        ? AppColours.green
        : run.isSavedConfirmed
            ? AppColours.orange
            : AppColours.blue;
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  run.zipFileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text.t(status),
                style: TextStyle(
                  color: colour,
                  fontSize: AppTextSize.s11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${run.recordCount} ${text.t('records')} · ${run.photoCount} ${text.t('photos')} · ${formatCleanupBytes(run.zipSizeBytes)}',
            style: AppTextStyles.formHint,
          ),
          Text(
            '${text.t('Cutoff')} ${formatCleanupDate(run.cutoffDate)} · ${formatCleanupDateTime(run.createdAt)}',
            style: AppTextStyles.formHint,
          ),
          if (!run.isCompleted) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (run.isBackupCreated)
                  OutlinedButton(
                    onPressed: busy ? null : onConfirm,
                    child: Text(text.t('Confirm saved')),
                  ),
                if (run.isSavedConfirmed)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColours.red,
                    ),
                    onPressed: busy ? null : onDelete,
                    child: Text(text.t('Delete permanently')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget _sectionTitle(String title, String subtitle) {
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

Widget _warning(String message) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColours.orange.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColours.orange.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColours.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

Widget _metric(String value, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColours.blue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$value $label',
      style: const TextStyle(
        color: AppColours.blue,
        fontSize: AppTextSize.s12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String _dataDescription(BusinessCleanupDataType type) {
  return switch (type) {
    BusinessCleanupDataType.inactiveSetup =>
      'Inactive setup records and old advertisements without protected references',
    BusinessCleanupDataType.stockHistory =>
      'Completed counts, receivables and SKU requests',
    BusinessCleanupDataType.reports => 'Completed business reports',
    BusinessCleanupDataType.tasks => 'Completed task records',
    BusinessCleanupDataType.attendance => 'Old attendance events',
    BusinessCleanupDataType.activity =>
      'Old activity with no unread notification',
    BusinessCleanupDataType.videoAnalytics => 'Old SOP viewing sessions',
  };
}

String formatCleanupDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day-$month-${date.year}';
}

String formatCleanupDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatCleanupDate(local)} $hour:$minute';
}

String formatCleanupBytes(int bytes) {
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
