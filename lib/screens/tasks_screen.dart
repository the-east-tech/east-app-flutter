import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/daily_task_models.dart';
import '../models/people_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../utils/app_diagnostics.dart';
import '../widgets/app_components.dart';

enum DailyTasksEntry { tasks, setup }

enum _SelectedPhotoAction { remove, retake }

class DailyTasksScreen extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final EastAppUser currentUser;
  final Future<void> Function()? onChanged;
  final DailyTasksEntry initialEntry;

  const DailyTasksScreen({
    super.key,
    required this.api,
    required this.tenantId,
    required this.currentUser,
    this.onChanged,
    this.initialEntry = DailyTasksEntry.tasks,
  });

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  late DateTimeRange selectedRange;
  late DateTimeRange historyRange;
  DailyTaskStatus? selectedStatus;
  String? selectedTagId;
  List<StockTag> tags = const [];
  List<DailyTaskRecord> records = const [];
  List<DailyTaskTemplate> templates = const [];
  DailyTaskOverview overview = DailyTaskOverview.empty;
  bool loadingRecords = false;
  bool hasLoadedRecords = false;
  bool loadingTemplates = false;
  bool loadingTags = false;
  int selectedTab = 0;

  bool get isManagement {
    return const {'OWNER', 'HEAD', 'MANAGER'}
        .contains(widget.currentUser.role.systemKey);
  }

  bool get showingSetup => widget.initialEntry == DailyTasksEntry.setup;

  bool get showingToday => !showingSetup && selectedTab == 1;

  bool get showingSubmissions =>
      !showingSetup && !isManagement && selectedTab == 2;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    selectedRange = DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
    historyRange = selectedRange;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(loadTags());
      if (showingSetup) unawaited(loadTemplates());
    });
  }

  Future<void> loadRecords() async {
    if (loadingRecords) return;
    if (mounted) setState(() => loadingRecords = true);
    try {
      final result = await widget.api.dailyTaskRecords(
        dateFrom: selectedRange.start,
        dateTo: selectedRange.end,
        tagId: selectedTagId,
        status: selectedStatus,
        submittedByMe: showingSubmissions,
      );
      if (!mounted) return;
      setState(() {
        records = result.records;
        overview = result.overview;
        hasLoadedRecords = true;
        loadingRecords = false;
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingRecords = false);
    }
  }

  Future<void> loadTemplates() async {
    if (loadingTemplates) return;
    setState(() => loadingTemplates = true);
    try {
      final result = await widget.api.dailyTaskTemplates();
      if (!mounted) return;
      setState(() {
        templates = result;
        loadingTemplates = false;
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingTemplates = false);
    }
  }

  Future<void> loadTags() async {
    if (loadingTags) return;
    setState(() => loadingTags = true);
    try {
      final result = await widget.api.allStockTags(
        tenantId: widget.tenantId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        tags = result;
        loadingTags = false;
        if (selectedTagId != null &&
            !tags.any((tag) => tag.id == selectedTagId)) {
          selectedTagId = null;
          clearLoadedRecords();
        }
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingTags = false);
    }
  }

  Future<void> selectDateRange() async {
    if (loadingRecords) return;
    final text = AppTextScope.of(context);
    final today = _dateOnly(DateTime.now());
    final value = await showDateRangePicker(
      context: context,
      initialDateRange: selectedRange,
      firstDate: DateTime(today.year - 2, 1, 1),
      lastDate: today,
      helpText: text.t('Select Daily Task dates'),
      saveText: text.t('Use Range'),
    );
    if (value == null || !mounted) return;
    final inclusiveDays = value.end.difference(value.start).inDays + 1;
    if (inclusiveDays > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.t('Select a maximum of 30 days.'))),
      );
      return;
    }
    setState(() {
      selectedRange = value;
      historyRange = value;
      clearLoadedRecords();
    });
  }

  void clearLoadedRecords() {
    records = const [];
    overview = DailyTaskOverview.empty;
    hasLoadedRecords = false;
  }

  Future<void> changeTab(int index) async {
    if (selectedTab == index) return;
    final today = _dateOnly(DateTime.now());
    setState(() {
      selectedTab = index;
      selectedRange = index == 1
          ? DateTimeRange(start: today, end: today)
          : historyRange;
      if (index == 1) {
        selectedStatus = null;
        selectedTagId = null;
      }
      clearLoadedRecords();
    });
    if (index == 1) await loadRecords();
  }

  Future<void> openRecord(DailyTaskRecord record) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DailyTaskDetailPage(
          api: widget.api,
          initialRecord: record,
        ),
      ),
    );
    if (!mounted) return;
    if (hasLoadedRecords) await loadRecords();
    final callback = widget.onChanged;
    if (changed == true && callback != null) await callback();
  }

  Future<void> openTemplate([DailyTaskTemplate? template]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DailyTaskTemplatePage(
          api: widget.api,
          tenantId: widget.tenantId,
          initialTags: tags,
          template: template,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await loadTemplates();
    if (hasLoadedRecords) await loadRecords();
    final callback = widget.onChanged;
    if (callback != null) await callback();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final tabs = isManagement
        ? ['Task History', "Today's Task"]
        : ['Task History', "Today's Task", 'My Submissions'];
    return Scaffold(
      backgroundColor: AppColours.background,
      appBar: AppBar(
        title: Text(text.t(showingSetup ? 'Task Setup' : 'Daily Tasks')),
        backgroundColor: AppColours.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: showingSetup
          ? _buildTemplates(text)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: SegmentedTabs(
                    tabs: tabs,
                    selectedIndex: selectedTab,
                    onChanged: (index) => unawaited(changeTab(index)),
                  ),
                ),
                Expanded(
                  child: _buildRecords(text),
                ),
              ],
            ),
      floatingActionButton: showingSetup && isManagement
          ? FloatingActionButton.extended(
              onPressed: () => openTemplate(),
              icon: const Icon(Icons.add_rounded),
              label: Text(text.t('Create Task')),
            )
          : null,
    );
  }

  Widget _buildRecords(AppText text) {
    return RefreshIndicator(
      onRefresh: hasLoadedRecords ? loadRecords : () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        children: [
          _DailyTaskFilterCard(
            selectedRange: selectedRange,
            todayOnly: showingToday,
            selectedStatus: selectedStatus,
            selectedTagId: selectedTagId,
            tags: tags,
            loadingTags: loadingTags,
            onDateRange: selectDateRange,
            onStatus: (value) => setState(() {
              selectedStatus = value;
              clearLoadedRecords();
            }),
            onTag: (value) => setState(() {
              selectedTagId = value;
              clearLoadedRecords();
            }),
            onLoad: loadRecords,
          ),
          if (hasLoadedRecords) ...[
            const SizedBox(height: 12),
            _DailyTaskOverviewCard(overview: overview),
          ],
          const SizedBox(height: 12),
          if (loadingRecords)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!hasLoadedRecords)
            WhiteCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.manage_search_rounded,
                      size: 42,
                      color: AppColours.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.t('Select a date range, then tap Load Tasks.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (records.isEmpty)
            WhiteCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      size: 42,
                      color: AppColours.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.t(
                        showingSubmissions
                            ? 'No task submitted by u in this date range.'
                            : 'No Daily Task matches these filters.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final record in records)
              _DailyTaskRecordCard(
                record: record,
                onTap: () => openRecord(record),
              ),
        ],
      ),
    );
  }

  Widget _buildTemplates(AppText text) {
    return RefreshIndicator(
      onRefresh: loadTemplates,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
        children: [
          WhiteCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColours.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.t(
                      'Each template creates one shared task per day for its Stock Tag. Template edits apply from the next task record.',
                    ),
                    style: const TextStyle(
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loadingTemplates)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (templates.isEmpty)
            WhiteCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      size: 44,
                      color: AppColours.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.t('No Daily Task template yet.'),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final template in templates)
              WhiteCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openTemplate(template),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: template.active
                                ? AppColours.greenSoft
                                : AppColours.mutedBox,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            color: template.active
                                ? AppColours.green
                                : AppColours.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.title,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${template.tagName} · ${template.requiredPhotoCount} photo${template.requiredPhotoCount == 1 ? '' : 's'} · ${template.checklistItems.length} check${template.checklistItems.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppColours.textMuted,
                                  fontSize: AppTextSize.s13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ActivePill(active: template.active),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColours.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DailyTaskFilterCard extends StatefulWidget {
  final DateTimeRange selectedRange;
  final bool todayOnly;
  final DailyTaskStatus? selectedStatus;
  final String? selectedTagId;
  final List<StockTag> tags;
  final bool loadingTags;
  final VoidCallback onDateRange;
  final ValueChanged<DailyTaskStatus?> onStatus;
  final ValueChanged<String?> onTag;
  final Future<void> Function() onLoad;

  const _DailyTaskFilterCard({
    required this.selectedRange,
    required this.todayOnly,
    required this.selectedStatus,
    required this.selectedTagId,
    required this.tags,
    required this.loadingTags,
    required this.onDateRange,
    required this.onStatus,
    required this.onTag,
    required this.onLoad,
  });

  @override
  State<_DailyTaskFilterCard> createState() => _DailyTaskFilterCardState();
}

class _DailyTaskFilterCardState extends State<_DailyTaskFilterCard> {
  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.t('Filters'),
            style: const TextStyle(
              fontSize: AppTextSize.s17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.todayOnly)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: "Today's Task",
                prefixIcon: Icon(Icons.today_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(_formatDate(widget.selectedRange.start)),
            )
          else
            OutlinedButton.icon(
              onPressed: widget.onDateRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatDate(widget.selectedRange.start)} — '
                      '${_formatDate(widget.selectedRange.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          const SizedBox(height: 10),
          DropdownButtonFormField<DailyTaskStatus?>(
            value: widget.selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<DailyTaskStatus?>(
                value: null,
                child: Text('All Statuses'),
              ),
              ...DailyTaskStatus.values.map(
                (status) => DropdownMenuItem<DailyTaskStatus?>(
                  value: status,
                  child: Text(_statusLabel(status)),
                ),
              ),
            ],
            onChanged: widget.onStatus,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: widget.selectedTagId,
            decoration: InputDecoration(
              labelText: widget.loadingTags ? 'Loading Tags…' : 'Tag',
              prefixIcon: widget.loadingTags
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sell_outlined),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Tags'),
              ),
              ...widget.tags.map(
                (tag) => DropdownMenuItem<String?>(
                  value: tag.id,
                  child: Text(tag.tag),
                ),
              ),
            ],
            onChanged: widget.loadingTags ? null : widget.onTag,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: 'Load Tasks',
            icon: Icons.refresh_rounded,
            onPressed: widget.onLoad,
          ),
          const SizedBox(height: 5),
          Text(
            text.t('Changing a filter does not reload until u tap Load Tasks.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTaskOverviewCard extends StatelessWidget {
  final DailyTaskOverview overview;

  const _DailyTaskOverviewCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _OverviewValue(
                  label: 'Pending',
                  value: '${overview.pending}',
                  colour: AppColours.orange,
                ),
              ),
              Expanded(
                child: _OverviewValue(
                  label: 'Submitted',
                  value: '${overview.submitted}',
                  colour: AppColours.blue,
                ),
              ),
              Expanded(
                child: _OverviewValue(
                  label: 'Done',
                  value: '${overview.done}/${overview.total}',
                  colour: AppColours.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: overview.completionRate,
              minHeight: 9,
              backgroundColor: AppColours.mutedBox,
              color: AppColours.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewValue extends StatelessWidget {
  final String label;
  final String value;
  final Color colour;

  const _OverviewValue({
    required this.label,
    required this.value,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: colour,
            fontSize: AppTextSize.s24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          AppTextScope.of(context).t(label),
          style: const TextStyle(
            color: AppColours.textMuted,
            fontSize: AppTextSize.s12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DailyTaskRecordCard extends StatelessWidget {
  final DailyTaskRecord record;
  final VoidCallback onTap;

  const _DailyTaskRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final completeChecks =
        record.checklistItems.where((item) => item.completed).length;
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _TaskStatusPill(status: record.status),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${record.tagName} · ${_formatDate(record.taskDate)}',
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RequirementChip(
                      icon: Icons.camera_alt_outlined,
                      text: '${record.photoCount}/${record.requiredPhotoCount}',
                      complete: record.photoCount >= record.requiredPhotoCount,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RequirementChip(
                      icon: Icons.checklist_rounded,
                      text: '$completeChecks/${record.checklistItems.length}',
                      complete: completeChecks == record.checklistItems.length,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColours.textMuted,
                  ),
                ],
              ),
              if (record.status == DailyTaskStatus.submitted &&
                  record.submittedAt != null) ...[
                const SizedBox(height: 9),
                Text(
                  'Submitted by ${record.submittedBy?.fullName ?? 'Unknown'} · '
                  '${_formatDateTime(record.submittedAt!)}',
                  style: const TextStyle(
                    color: AppColours.blue,
                    fontSize: AppTextSize.s12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (record.status == DailyTaskStatus.done &&
                  record.rating != null) ...[
                const SizedBox(height: 9),
                _StarDisplay(rating: record.rating!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool complete;

  const _RequirementChip({
    required this.icon,
    required this.text,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: complete ? AppColours.greenSoft : AppColours.mutedBox,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: complete ? AppColours.green : AppColours.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: complete ? AppColours.green : AppColours.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTaskDetailPage extends StatefulWidget {
  final EastAppApi api;
  final DailyTaskRecord initialRecord;

  const _DailyTaskDetailPage({
    required this.api,
    required this.initialRecord,
  });

  @override
  State<_DailyTaskDetailPage> createState() => _DailyTaskDetailPageState();
}

class _DailyTaskDetailPageState extends State<_DailyTaskDetailPage> {
  late DailyTaskRecord record;
  late Set<String> selectedChecklistItemIds;
  final List<String> selectedPhotoPaths = [];
  bool changed = false;
  bool loading = false;

  bool get acceptingInput =>
      record.status == DailyTaskStatus.pending && record.canContribute;

  bool get submissionReady => acceptingInput &&
      selectedChecklistItemIds.length == record.checklistItems.length &&
      record.checklistItems.isNotEmpty &&
      selectedPhotoPaths.length >= record.requiredPhotoCount;

  @override
  void initState() {
    super.initState();
    record = widget.initialRecord;
    selectedChecklistItemIds = {
      for (final item in record.checklistItems)
        if (item.completed) item.id,
    };
    unawaited(refresh());
  }

  @override
  void dispose() {
    for (final path in selectedPhotoPaths) {
      unawaited(_deleteTemporaryPhoto(path));
    }
    super.dispose();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      final result = await widget.api.dailyTaskRecord(record.id);
      if (!mounted) return;
      final pathsToDelete = result.status == DailyTaskStatus.pending
          ? const <String>[]
          : List<String>.from(selectedPhotoPaths);
      setState(() {
        record = result;
        loading = false;
        if (result.status != DailyTaskStatus.pending) {
          selectedChecklistItemIds.clear();
          selectedPhotoPaths.clear();
        }
      });
      for (final path in pathsToDelete) {
        unawaited(_deleteTemporaryPhoto(path));
      }
    } on EastAppApiException {
      if (mounted) setState(() => loading = false);
    }
  }

  void applyServerUpdate(DailyTaskRecord value) {
    if (!mounted) return;
    final pathsToDelete = List<String>.from(selectedPhotoPaths);
    setState(() {
      record = value;
      changed = true;
      selectedChecklistItemIds.clear();
      selectedPhotoPaths.clear();
    });
    for (final path in pathsToDelete) {
      unawaited(_deleteTemporaryPhoto(path));
    }
  }

  void toggleCheck(DailyTaskChecklistItem item, bool completed) {
    setState(() {
      if (completed) {
        selectedChecklistItemIds.add(item.id);
      } else {
        selectedChecklistItemIds.remove(item.id);
      }
    });
  }

  Future<void> capturePhoto() async {
    if (!acceptingInput || selectedPhotoPaths.length >= 40) return;
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _DailyTaskCameraPage()),
    );
    if (path == null || !mounted) return;
    setState(() => selectedPhotoPaths.add(path));
  }

  Future<void> openSelectedPhoto(int index) async {
    if (index < 0 || index >= selectedPhotoPaths.length) return;
    final currentPath = selectedPhotoPaths[index];
    final action = await showDialog<_SelectedPhotoAction>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(dialogContext).height * 0.78,
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Center(child: Image.file(File(currentPath))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (acceptingInput) ...[
                      FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext)
                            .pop(_SelectedPhotoAction.retake),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retake'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(dialogContext)
                            .pop(_SelectedPhotoAction.remove),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _SelectedPhotoAction.remove) {
      final currentIndex = selectedPhotoPaths.indexOf(currentPath);
      if (currentIndex < 0) return;
      setState(() => selectedPhotoPaths.removeAt(currentIndex));
      unawaited(_deleteTemporaryPhoto(currentPath));
      return;
    }
    final replacementPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _DailyTaskCameraPage()),
    );
    if (replacementPath == null || !mounted) return;
    final currentIndex = selectedPhotoPaths.indexOf(currentPath);
    if (currentIndex < 0) {
      unawaited(_deleteTemporaryPhoto(replacementPath));
      return;
    }
    setState(() => selectedPhotoPaths[currentIndex] = replacementPath);
    unawaited(_deleteTemporaryPhoto(currentPath));
  }

  Future<void> openSubmittedPhoto(Uint8List bytes) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(dialogContext).height * 0.78,
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Center(child: Image.memory(bytes)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showAlreadySubmitted(EastAppApiException error) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: AppColours.blue),
        title: const Text('Task Already Submitted'),
        content: Text(error.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> submit() async {
    final confirmed = await _confirmAction(
      context,
      title: 'Submit Daily Task?',
      message:
          'The final checklist and selected photos will be stored and locked permanently.',
      action: 'Submit',
    );
    if (!confirmed || !mounted) return;
    try {
      applyServerUpdate(
        await widget.api.submitDailyTask(
          recordId: record.id,
          completedChecklistItemIds:
              selectedChecklistItemIds.toList(growable: false),
          photoPaths: List<String>.from(selectedPhotoPaths),
        ),
      );
    } on EastAppApiException catch (error) {
      if (error.code == 'DAILY_TASK_ALREADY_SUBMITTED' && mounted) {
        await showAlreadySubmitted(error);
      }
      return;
    }
  }

  Future<void> rate() async {
    final value = await showDialog<_RatingResult>(
      context: context,
      builder: (_) => const _DailyTaskRatingDialog(),
    );
    if (value == null || !mounted) return;
    try {
      applyServerUpdate(
        await widget.api.rateDailyTask(
          recordId: record.id,
          rating: value.rating,
          comment: value.comment,
        ),
      );
    } on EastAppApiException {
      return;
    }
  }

  void close() {
    Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Scaffold(
        backgroundColor: AppColours.background,
        appBar: AppBar(
          leading: IconButton(
            onPressed: close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(text.t('Daily Task')),
          actions: [
            IconButton(
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: text.t('Refresh'),
            ),
          ],
          backgroundColor: AppColours.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
            children: [
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: const TextStyle(
                              fontSize: AppTextSize.s24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _TaskStatusPill(status: record.status),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${record.tagName} · ${_formatDate(record.taskDate)}',
                      style: const TextStyle(
                        color: AppColours.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (record.instruction.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        record.instruction,
                        style: const TextStyle(
                          color: AppColours.textMuted,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColours.mutedBox,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        text.t(
                          'Any user assigned to this Tag may complete it. The first successful submission becomes the final record.',
                        ),
                        style: const TextStyle(
                          color: AppColours.textMuted,
                          fontSize: AppTextSize.s13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t('Checklist'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final item in record.checklistItems)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: record.status == DailyTaskStatus.pending
                            ? selectedChecklistItemIds.contains(item.id)
                            : item.completed,
                        onChanged: acceptingInput
                            ? (value) => toggleCheck(item, value ?? false)
                            : null,
                        title: Text(
                          item.description,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: record.status == DailyTaskStatus.pending ||
                                item.completedAt == null
                            ? null
                            : Text(
                                '${item.completedBy?.fullName ?? 'Unknown'} · '
                                '${_formatDateTime(item.completedAt!)}',
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${text.t(record.status == DailyTaskStatus.pending ? 'Selected Photos' : 'Submitted Photos')} '
                            '${record.status == DailyTaskStatus.pending ? selectedPhotoPaths.length : record.photoCount}'
                            '/${record.requiredPhotoCount}',
                            style: const TextStyle(
                              fontSize: AppTextSize.s18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (acceptingInput && selectedPhotoPaths.length < 40)
                          FilledButton.icon(
                            onPressed: capturePhoto,
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: Text(text.t('Camera')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.t(
                        record.status == DailyTaskStatus.pending
                            ? 'Photos remain only on this screen and upload only when u tap Submit Task. Tap a selected photo to view, remove or retake it.'
                            : 'Submitted photos are permanently locked.',
                      ),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontSize: AppTextSize.s13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.status == DailyTaskStatus.pending &&
                        selectedPhotoPaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: selectedPhotoPaths.length,
                        itemBuilder: (_, index) {
                          final path = selectedPhotoPaths[index];
                          return _SelectedDailyTaskPhotoTile(
                            key: ValueKey(path),
                            path: path,
                            onTap: () => openSelectedPhoto(index),
                          );
                        },
                      ),
                    ] else if (record.photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: record.photos.length,
                        itemBuilder: (_, index) {
                          final photo = record.photos[index];
                          return _DailyTaskPhotoTile(
                            key: ValueKey(photo.id),
                            api: widget.api,
                            photo: photo,
                            onTap: openSubmittedPhoto,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (record.status != DailyTaskStatus.pending) ...[
                const SizedBox(height: 12),
                _SubmissionCard(record: record),
              ],
              if (record.status == DailyTaskStatus.done) ...[
                const SizedBox(height: 12),
                _RatingCard(record: record),
              ],
              if (record.activity.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ActivityCard(entries: record.activity),
              ],
              if (submissionReady) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Submit Task',
                  icon: Icons.send_rounded,
                  onPressed: submit,
                ),
              ] else if (record.status == DailyTaskStatus.pending) ...[
                const SizedBox(height: 12),
                Text(
                  text.t(
                    record.canContribute
                        ? 'Complete every checklist item and the minimum photo count to submit.'
                        : 'Only users assigned to this Tag may contribute or submit.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (record.canRate) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Rate Task',
                  icon: Icons.star_rounded,
                  onPressed: rate,
                ),
              ],
            ],
          ),
        ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final DailyTaskRecord record;

  const _SubmissionCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Row(
        children: [
          const Icon(Icons.send_rounded, color: AppColours.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task submitted',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.submittedBy?.fullName ?? 'Unknown'} · '
                  '${record.submittedAt == null ? '—' : _formatDateTime(record.submittedAt!)}',
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontSize: AppTextSize.s13,
                    fontWeight: FontWeight.w600,
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

class _RatingCard extends StatelessWidget {
  final DailyTaskRecord record;

  const _RatingCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StarDisplay(rating: record.rating ?? 0, size: 28),
          const SizedBox(height: 8),
          Text(
            record.ratingComment ?? '',
            style: const TextStyle(height: 1.35, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            'Rated by ${record.ratedBy?.fullName ?? 'Unknown'} · '
            '${record.ratedAt == null ? '—' : _formatDateTime(record.ratedAt!)}',
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final List<DailyTaskAuditEntry> entries;

  const _ActivityCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Activity & Audit',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: entries.reversed.map((entry) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(
              Icons.history_rounded,
              color: AppColours.textMuted,
            ),
            title: Text(
              _actionLabel(entry.action),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${entry.actor.fullName} · ${_formatDateTime(entry.occurredAt)}'
              '${entry.details.isEmpty ? '' : '\n${entry.details}'}',
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _SelectedDailyTaskPhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onTap;

  const _SelectedDailyTaskPhotoTile({
    super.key,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColours.mutedBox,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.border),
        ),
        child: Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_iphone_rounded,
                    size: 16,
                    color: AppColours.textMuted,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Selected · Not submitted',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColours.textMuted,
                        fontSize: AppTextSize.s12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTaskPhotoTile extends StatefulWidget {
  final EastAppApi api;
  final DailyTaskPhoto photo;
  final Future<void> Function(Uint8List bytes) onTap;

  const _DailyTaskPhotoTile({
    super.key,
    required this.api,
    required this.photo,
    required this.onTap,
  });

  @override
  State<_DailyTaskPhotoTile> createState() => _DailyTaskPhotoTileState();
}

class _DailyTaskPhotoTileState extends State<_DailyTaskPhotoTile> {
  late Future<Uint8List> request;

  @override
  void initState() {
    super.initState();
    request = widget.api.reportImageBytes(widget.photo.photoStorageKey);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: request,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return InkWell(
          onTap: bytes == null ? null : () => unawaited(widget.onTap(bytes)),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColours.mutedBox,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColours.border),
            ),
            child: Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    child: bytes == null
                        ? snapshot.hasError
                            ? const Icon(Icons.broken_image_outlined)
                            : const Center(child: CircularProgressIndicator())
                        : Image.memory(bytes, fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.photo.submittedBy.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.s12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _formatDateTime(widget.photo.submittedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColours.textMuted,
                          fontSize: AppTextSize.s10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DailyTaskCameraPage extends StatefulWidget {
  const _DailyTaskCameraPage();

  @override
  State<_DailyTaskCameraPage> createState() => _DailyTaskCameraPageState();
}

class _DailyTaskCameraPageState extends State<_DailyTaskCameraPage> {
  CameraController? controller;
  XFile? capturedPhoto;
  String? errorMessage;
  bool capturing = false;
  bool confirmed = false;

  @override
  void initState() {
    super.initState();
    unawaited(initialiseCamera());
  }

  Future<void> initialiseCamera() async {
    final old = controller;
    controller = null;
    await old?.dispose();
    if (mounted) setState(() => errorMessage = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() => controller = next);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (mounted) setState(() => errorMessage = error.toString());
    }
  }

  Future<void> takePhoto() async {
    final value = controller;
    if (capturing || value == null || !value.value.isInitialized) return;
    setState(() => capturing = true);
    try {
      final photo = await value.takePicture();
      await value.dispose();
      if (!mounted) return;
      setState(() {
        controller = null;
        capturedPhoto = photo;
        capturing = false;
      });
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        capturing = false;
        errorMessage = error.toString();
      });
    }
  }

  Future<void> retake() async {
    final photo = capturedPhoto;
    if (photo != null) {
      try {
        await File(photo.path).delete();
      } on FileSystemException {
        // Camera temporary files are best-effort cleanup only.
      }
    }
    if (!mounted) return;
    setState(() => capturedPhoto = null);
    await initialiseCamera();
  }

  void confirm() {
    final photo = capturedPhoto;
    if (photo == null) return;
    confirmed = true;
    Navigator.of(context).pop(photo.path);
  }

  @override
  void dispose() {
    controller?.dispose();
    final photo = capturedPhoto;
    if (!confirmed && photo != null) {
      unawaited(_deleteTemporaryPhoto(photo.path));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = capturedPhoto;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(photo == null ? 'Camera' : 'Review Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: photo != null
                  ? Image.file(
                      File(photo.path),
                      width: double.infinity,
                      fit: BoxFit.contain,
                    )
                  : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: initialiseCamera,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry Camera'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : controller == null || !controller!.value.isInitialized
                          ? const Center(child: CircularProgressIndicator())
                          : Center(child: CameraPreview(controller!)),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: photo == null
                  ? SizedBox(
                      width: 76,
                      height: 76,
                      child: FilledButton(
                        onPressed: capturing ? null : takePhoto,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 32),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: retake,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: confirm,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Confirm Photo'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyTaskTemplatePage extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final List<StockTag> initialTags;
  final DailyTaskTemplate? template;

  const DailyTaskTemplatePage({
    required this.api,
    required this.tenantId,
    required this.initialTags,
    this.template,
  });

  @override
  State<DailyTaskTemplatePage> createState() =>
      _DailyTaskTemplatePageState();
}

class _DailyTaskTemplatePageState extends State<DailyTaskTemplatePage> {
  late final TextEditingController titleController;
  late final TextEditingController instructionController;
  final List<TextEditingController> checklistControllers = [];
  late List<StockTag> tags;
  String? tagId;
  int requiredPhotoCount = 1;
  int checklistCount = 1;
  bool active = true;
  bool loadingTags = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    titleController = TextEditingController(text: template?.title ?? '');
    instructionController = TextEditingController(
      text: template?.instruction ?? '',
    );
    tags = List<StockTag>.from(widget.initialTags);
    if (template != null && !tags.any((tag) => tag.id == template.tagId)) {
      tags.add(
        StockTag(
          id: template.tagId,
          tag: template.tagName,
          createdBy: '',
          createdDate: '',
          lastUpdated: '',
        ),
      );
    }
    tagId = template?.tagId;
    requiredPhotoCount = template?.requiredPhotoCount ?? 1;
    checklistCount = template?.checklistItems.length ?? 1;
    active = template?.active ?? true;
    for (var index = 0; index < 5; index++) {
      checklistControllers.add(
        TextEditingController(
          text: index < (template?.checklistItems.length ?? 0)
              ? template!.checklistItems[index]
              : '',
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(loadTags());
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    instructionController.dispose();
    for (final controller in checklistControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadTags() async {
    if (loadingTags) return;
    setState(() => loadingTags = true);
    try {
      final result = await widget.api.allStockTags(
        tenantId: widget.tenantId,
        forceRefresh: true,
      );
      if (!mounted) return;
      final next = List<StockTag>.from(result);
      final template = widget.template;
      if (template != null && !next.any((tag) => tag.id == template.tagId)) {
        next.add(
          StockTag(
            id: template.tagId,
            tag: template.tagName,
            createdBy: '',
            createdDate: '',
            lastUpdated: '',
          ),
        );
      }
      setState(() {
        tags = next;
        loadingTags = false;
        if (tagId != null && !tags.any((tag) => tag.id == tagId)) {
          tagId = null;
        }
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingTags = false);
    }
  }

  Future<void> save() async {
    final title = titleController.text.trim();
    final selectedTagId = tagId;
    final checks = checklistControllers
        .take(checklistCount)
        .map((controller) => controller.text.trim())
        .toList(growable: false);
    if (title.isEmpty || selectedTagId == null || checks.any((item) => item.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the title, Tag and every checklist item.'),
        ),
      );
      return;
    }
    final confirmed = await _confirmAction(
      context,
      title: widget.template == null
          ? 'Create Daily Task?'
          : 'Update Daily Task?',
      message: widget.template == null
          ? 'This creates one shared task each day for users assigned to the selected Tag.'
          : 'Existing daily evidence stays unchanged. This update applies to future task records.',
      action: 'Save',
    );
    if (!confirmed || !mounted) return;
    try {
      if (widget.template == null) {
        await widget.api.createDailyTaskTemplate(
          title: title,
          instruction: instructionController.text,
          tagId: selectedTagId,
          requiredPhotoCount: requiredPhotoCount,
          checklistItems: checks,
          active: active,
        );
      } else {
        await widget.api.updateDailyTaskTemplate(
          templateId: widget.template!.id,
          title: title,
          instruction: instructionController.text,
          tagId: selectedTagId,
          requiredPhotoCount: requiredPhotoCount,
          checklistItems: checks,
          active: active,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on EastAppApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final matchingTags = tags.where((tag) => tag.id == tagId).toList();
    final selectedTag = matchingTags.isEmpty ? null : matchingTags.first;
    return Scaffold(
      backgroundColor: AppColours.background,
      appBar: AppBar(
        title: Text(
          text.t(widget.template == null ? 'Create Daily Task' : 'Edit Daily Task'),
        ),
        backgroundColor: AppColours.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        children: [
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Task title',
                    hintText: 'Example: Kitchen closing check',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: instructionController,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Instruction (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Stock Tag',
                  style: TextStyle(
                    fontSize: AppTextSize.s18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'The task is shared by every user assigned to this Tag.',
                  style: TextStyle(
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: tagId,
                  decoration: InputDecoration(
                    labelText:
                        loadingTags ? 'Loading all Tags…' : 'Assigned Tag',
                    prefixIcon: loadingTags
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sell_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  items: tags
                      .map(
                        (tag) => DropdownMenuItem<String>(
                          value: tag.id,
                          child: Text(
                            tag.createdBy.isEmpty
                                ? tag.tag
                                : '${tag.tag} · ${tag.assignedUsers.length} user${tag.assignedUsers.length == 1 ? '' : 's'}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: loadingTags || tags.isEmpty
                      ? null
                      : (value) => setState(() => tagId = value),
                ),
                if (!loadingTags && tags.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No Stock Tags are available.',
                    style: TextStyle(
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (selectedTag != null &&
                    selectedTag.createdBy.isNotEmpty &&
                    selectedTag.assignedUsers.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No users are assigned to this Tag. Only Owner can complete this task until users are assigned in Stock → Tag.',
                    style: TextStyle(
                      color: AppColours.orange,
                      fontSize: AppTextSize.s13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  value: requiredPhotoCount,
                  decoration: const InputDecoration(
                    labelText: 'Minimum photos required daily',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    40,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (value) => setState(
                    () => requiredPhotoCount = value ?? requiredPhotoCount,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: checklistCount,
                  decoration: const InputDecoration(
                    labelText: 'Number of checklist items',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    5,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (value) => setState(
                    () => checklistCount = value ?? checklistCount,
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < checklistCount; index++) ...[
                  TextField(
                    controller: checklistControllers[index],
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: 'Checklist ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (index != checklistCount - 1) const SizedBox(height: 8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Active',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Active templates create a shared task each day.'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
              ],
            ),
          ),
          if (widget.template?.activity.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ActivityCard(entries: widget.template!.activity),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Save Task',
            icon: Icons.save_outlined,
            onPressed: save,
          ),
        ],
      ),
    );
  }
}

class _DailyTaskRatingDialog extends StatefulWidget {
  const _DailyTaskRatingDialog();

  @override
  State<_DailyTaskRatingDialog> createState() =>
      _DailyTaskRatingDialogState();
}

class _DailyTaskRatingDialogState extends State<_DailyTaskRatingDialog> {
  final commentController = TextEditingController();
  int rating = 0;
  String? error;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void submit() {
    final comment = commentController.text.trim();
    if (rating < 1 || comment.isEmpty) {
      setState(() => error = 'Choose 1–5 stars and explain the rating.');
      return;
    }
    Navigator.of(context).pop(_RatingResult(rating, comment));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Daily Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: () => setState(() => rating = value),
                  icon: Icon(
                    value <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColours.gold,
                    size: 34,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentController,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Comment (Required)',
                hintText: 'Explain why this score was given',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.star_rounded),
          label: const Text('Rate'),
        ),
      ],
    );
  }
}

class _RatingResult {
  final int rating;
  final String comment;

  const _RatingResult(this.rating, this.comment);
}

class _TaskStatusPill extends StatelessWidget {
  final DailyTaskStatus status;

  const _TaskStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colour = switch (status) {
      DailyTaskStatus.pending => AppColours.orange,
      DailyTaskStatus.submitted => AppColours.blue,
      DailyTaskStatus.done => AppColours.green,
    };
    final background = switch (status) {
      DailyTaskStatus.pending => AppColours.orangeSoft,
      DailyTaskStatus.submitted => const Color(0xFFEAF3FF),
      DailyTaskStatus.done => AppColours.greenSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: colour,
          fontSize: AppTextSize.s12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  final bool active;

  const _ActivePill({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColours.greenSoft : AppColours.mutedBox,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: active ? AppColours.green : AppColours.textMuted,
          fontSize: AppTextSize.s10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  final int rating;
  final double size;

  const _StarDisplay({required this.rating, this.size = 19});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: AppColours.gold,
        ),
      ),
    );
  }
}

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

String _statusLabel(DailyTaskStatus status) {
  return switch (status) {
    DailyTaskStatus.pending => 'Pending',
    DailyTaskStatus.submitted => 'Submitted',
    DailyTaskStatus.done => 'Done',
  };
}

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
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${_formatDate(local)}, $hour:$minute $period';
}

String _actionLabel(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
      .join(' ');
}

Future<void> _deleteTemporaryPhoto(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Camera temporary files are best-effort cleanup only.
  }
}
