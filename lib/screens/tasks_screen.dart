import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/auth_models.dart';
import '../models/task_models.dart';
import '../models/people_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../utils/app_diagnostics.dart';
import '../widgets/app_components.dart';
import 'knowledge_screen.dart';

enum TasksEntry { tasks, setup, approvals }

enum _SelectedPhotoAction { remove, retake }

class _TaskTabState {
  DateTimeRange selectedRange;
  TaskStatus? selectedStatus;
  String? selectedTagId;
  List<TaskRecord> records = const [];
  TaskOverview overview = TaskOverview.empty;
  bool loadingRecords = false;
  bool hasLoadedRecords = false;
  int requestVersion = 0;

  _TaskTabState({required this.selectedRange});
}

class TasksScreen extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final EastAppUser currentUser;
  final Set<EastAppPermission> permissions;
  final Future<void> Function()? onChanged;
  final TasksEntry initialEntry;

  const TasksScreen({
    super.key,
    required this.api,
    required this.tenantId,
    required this.currentUser,
    required this.permissions,
    this.onChanged,
    this.initialEntry = TasksEntry.tasks,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final List<_TaskTabState> taskTabStates;
  List<StockTag> tags = const [];
  List<TaskTemplate> templates = const [];
  bool loadingTemplates = false;
  bool loadingTags = false;
  int selectedTab = 0;

  _TaskTabState get selectedTaskTab => taskTabStates[selectedTab];

  bool get canViewAllTasks {
    return widget.permissions.contains(EastAppPermission.taskViewAll);
  }

  bool get canManageTasks {
    return widget.permissions.contains(EastAppPermission.taskManage);
  }

  bool get showingSetup => widget.initialEntry == TasksEntry.setup;

  bool get showingApprovals => widget.initialEntry == TasksEntry.approvals;

  bool get showingActiveTasks => !showingSetup && selectedTab == 1;

  bool get showingPersonalHistory =>
      !showingSetup && !canViewAllTasks && selectedTab == 0;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    final defaultRange = DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
    taskTabStates = [
      _TaskTabState(selectedRange: defaultRange),
      _TaskTabState(selectedRange: DateTimeRange(start: today, end: today)),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (showingApprovals) {
        unawaited(loadRecords(tabIndex: 0));
      } else {
        unawaited(loadTags());
        if (showingSetup) unawaited(loadTemplates());
      }
    });
  }

  Future<void> loadRecords({
    int? tabIndex,
    bool forceRefresh = false,
  }) async {
    final requestedTab = tabIndex ?? selectedTab;
    if (!mounted ||
        requestedTab < 0 ||
        requestedTab >= taskTabStates.length) {
      return;
    }
    final tab = taskTabStates[requestedTab];
    if (tab.loadingRecords) return;
    final requestVersion = ++tab.requestVersion;
    final tagId = tab.selectedTagId;
    final status = tab.selectedStatus;
    final submittedByMe = !canViewAllTasks && requestedTab == 0;
    setState(() => tab.loadingRecords = true);
    try {
      final TaskList result;
      if (showingApprovals) {
        result = await widget.api.taskApprovals();
      } else if (requestedTab == 1) {
        result = await widget.api.taskRecords(
          tenantId: widget.tenantId,
          tagId: tagId,
          upcoming: true,
          limit: 3,
          forceRefresh: forceRefresh,
        );
      } else {
        result = await widget.api.taskRecords(
          tenantId: widget.tenantId,
          dateFrom: tab.selectedRange.start,
          dateTo: tab.selectedRange.end,
          tagId: tagId,
          status: status,
          statuses: status == null
              ? const [TaskStatus.submitted, TaskStatus.done]
              : null,
          submittedByMe: submittedByMe,
          forceRefresh: forceRefresh,
        );
      }
      if (!mounted || tab.requestVersion != requestVersion) return;
      setState(() {
        tab.records = result.records;
        tab.overview = result.overview;
        tab.hasLoadedRecords = true;
        tab.loadingRecords = false;
      });
    } on EastAppApiException {
      if (mounted && tab.requestVersion == requestVersion) {
        setState(() => tab.loadingRecords = false);
      }
    }
  }

  Future<void> loadTemplates({bool forceRefresh = false}) async {
    if (loadingTemplates) return;
    setState(() => loadingTemplates = true);
    try {
      final result = await widget.api.taskTemplates(
        tenantId: widget.tenantId,
        forceRefresh: forceRefresh,
      );
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
        forceRefresh: false,
      );
      if (!mounted) return;
      setState(() {
        tags = result;
        loadingTags = false;
        for (final tab in taskTabStates) {
          if (tab.selectedTagId != null &&
              !tags.any((tag) => tag.id == tab.selectedTagId)) {
            tab.selectedTagId = null;
            clearLoadedRecords(tab);
          }
        }
      });
    } on EastAppApiException {
      if (mounted) setState(() => loadingTags = false);
    }
  }

  Future<void> selectDateRange() async {
    final tab = selectedTaskTab;
    if (tab.loadingRecords) return;
    final text = AppTextScope.of(context);
    final today = _dateOnly(DateTime.now());
    final value = await showDateRangePicker(
      context: context,
      initialDateRange: tab.selectedRange,
      firstDate: DateTime(today.year - 2, 1, 1),
      lastDate: today,
      helpText: text.t('Select Task dates'),
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
      tab.selectedRange = value;
      clearLoadedRecords(tab);
    });
  }

  void clearLoadedRecords(_TaskTabState tab) {
    tab.requestVersion += 1;
    tab.records = const [];
    tab.overview = TaskOverview.empty;
    tab.loadingRecords = false;
    tab.hasLoadedRecords = false;
  }

  Future<void> changeTab(int index) async {
    if (selectedTab == index) return;
    var shouldAutomaticallyLoad = false;
    setState(() {
      selectedTab = index;
      if (index == 1) {
        shouldAutomaticallyLoad = true;
      }
    });
    if (shouldAutomaticallyLoad) await loadRecords(tabIndex: index);
  }

  Future<void> openRecord(
    TaskRecord record, {
    bool allowRating = false,
  }) async {
    final openedTab = selectedTab;
    final tab = taskTabStates[openedTab];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _TaskDetailPage(
          api: widget.api,
          initialRecord: record,
          allowRating: allowRating,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      final shouldReload = tab.hasLoadedRecords;
      widget.api.invalidateTaskRecords(widget.tenantId);
      setState(() {
        for (final taskTab in taskTabStates) {
          clearLoadedRecords(taskTab);
        }
      });
      if (shouldReload) {
        await loadRecords(tabIndex: openedTab, forceRefresh: true);
      }
    }
    final callback = widget.onChanged;
    if (changed == true && callback != null) await callback();
  }

  Future<void> openTemplate([TaskTemplate? template]) async {
    final saved = await Navigator.of(context).push<TaskTemplate>(
      MaterialPageRoute(
        builder: (_) => TaskTemplatePage(
          api: widget.api,
          tenantId: widget.tenantId,
          initialTags: tags,
          template: template,
        ),
      ),
    );
    if (!mounted || saved == null) return;
    setState(() {
      final next = template == null
          ? [saved, ...templates]
          : templates
              .map((item) => item.id == saved.id ? saved : item)
              .toList();
      next.sort((left, right) {
        if (left.active != right.active) return left.active ? -1 : 1;
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
      templates = List.unmodifiable(next);
    });
    final callback = widget.onChanged;
    if (callback != null) await callback();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final tabs = ['Task History', 'Active Task'];
    return Scaffold(
      backgroundColor: AppColours.background,
      appBar: AppBar(
        title: Text(
          text.t(
            showingSetup
                ? 'Task Setup'
                : showingApprovals
                    ? 'Task Approvals'
                    : 'Task',
          ),
        ),
        backgroundColor: AppColours.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: showingSetup
          ? _buildTemplates(text)
          : showingApprovals
              ? _buildApprovals(text)
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
      floatingActionButton: showingSetup && canManageTasks
          ? FloatingActionButton.extended(
              onPressed: () => openTemplate(),
              icon: const Icon(Icons.add_rounded),
              label: Text(text.t('Create Task')),
            )
          : null,
    );
  }

  Widget _buildRecords(AppText text) {
    final tab = selectedTaskTab;
    return RefreshIndicator(
      onRefresh: tab.hasLoadedRecords
          ? () => loadRecords(tabIndex: selectedTab, forceRefresh: true)
          : () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        children: [
          _TaskFilterCard(
            selectedRange: tab.selectedRange,
            activeTasks: showingActiveTasks,
            selectedStatus: tab.selectedStatus,
            selectedTagId: tab.selectedTagId,
            tags: tags,
            loadingTags: loadingTags,
            onDateRange: selectDateRange,
            onStatus: (value) => setState(() {
              tab.selectedStatus = value;
              clearLoadedRecords(tab);
            }),
            onTag: (value) => setState(() {
              tab.selectedTagId = value;
              clearLoadedRecords(tab);
            }),
            onLoad: () => loadRecords(tabIndex: selectedTab),
          ),
          if (tab.hasLoadedRecords) ...[
            const SizedBox(height: 12),
            _TaskOverviewCard(overview: tab.overview),
          ],
          const SizedBox(height: 12),
          if (tab.loadingRecords)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!tab.hasLoadedRecords)
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
                      text.t(
                        showingActiveTasks
                            ? 'Tap Load Tasks to load the next 3 pending Tasks.'
                            : 'Select a date range, then tap Load Tasks.',
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
          else if (tab.records.isEmpty)
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
                        showingPersonalHistory
                            ? 'No task submitted by u in this date range.'
                            : 'No Task matches these filters.',
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
            for (final record in tab.records)
              _TaskRecordCard(
                record: record,
                onTap: () => openRecord(record),
              ),
        ],
      ),
    );
  }

  Widget _buildApprovals(AppText text) {
    final tab = taskTabStates.first;
    return RefreshIndicator(
      onRefresh: () => loadRecords(tabIndex: 0, forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        children: [
          if (tab.loadingRecords)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tab.records.isEmpty)
            WhiteCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 48,
                      color: AppColours.green,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.t('All Tasks reviewed'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            WhiteCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: AppColours.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text.t(
                        'Open a submitted Task to review its evidence and rate it.',
                      ),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final record in tab.records)
              _TaskRecordCard(
                record: record,
                onTap: () => openRecord(record, allowRating: true),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplates(AppText text) {
    return RefreshIndicator(
      onRefresh: () => loadTemplates(forceRefresh: true),
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
                      'Each active Task appears only on its scheduled date and is shared by users assigned to its Stock Tag.',
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
                      text.t('No Task created yet.'),
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
                              const SizedBox(height: 3),
                              Text(
                                _formatTemplateSchedule(template),
                                style: const TextStyle(
                                  color: AppColours.blue,
                                  fontSize: AppTextSize.s12,
                                  fontWeight: FontWeight.w700,
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

class _TaskFilterCard extends StatefulWidget {
  final DateTimeRange selectedRange;
  final bool activeTasks;
  final TaskStatus? selectedStatus;
  final String? selectedTagId;
  final List<StockTag> tags;
  final bool loadingTags;
  final VoidCallback onDateRange;
  final ValueChanged<TaskStatus?> onStatus;
  final ValueChanged<String?> onTag;
  final Future<void> Function() onLoad;

  const _TaskFilterCard({
    required this.selectedRange,
    required this.activeTasks,
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
  State<_TaskFilterCard> createState() => _TaskFilterCardState();
}

class _TaskFilterCardState extends State<_TaskFilterCard> {
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
          if (widget.activeTasks)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColours.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: AppColours.green,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      text.t('Only the next 3 pending active Tasks are loaded.'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            )
          else ...[
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
            DropdownButtonFormField<TaskStatus?>(
              value: widget.selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem<TaskStatus?>(
                  value: null,
                  child: Text(text.t('Submitted & Done')),
                ),
                ...TaskStatus.values
                    .where((status) => status != TaskStatus.pending)
                    .map(
                      (status) => DropdownMenuItem<TaskStatus?>(
                        value: status,
                        child: Text(text.t(_statusLabel(status))),
                      ),
                    ),
              ],
              onChanged: widget.onStatus,
            ),
          ],
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
            text.t(
              widget.activeTasks
                  ? 'Change Tag, then tap Load Tasks.'
                  : 'Changing a filter does not reload until u tap Load Tasks.',
            ),
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

class _TaskOverviewCard extends StatelessWidget {
  final TaskOverview overview;

  const _TaskOverviewCard({required this.overview});

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

class _TaskRecordCard extends StatelessWidget {
  final TaskRecord record;
  final VoidCallback onTap;

  const _TaskRecordCard({required this.record, required this.onTap});

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
                '${record.tagName} · ${record.scheduleType.label} · ${_formatDate(record.taskDate)}',
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
              if (record.status == TaskStatus.submitted &&
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
              if (record.status == TaskStatus.done &&
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

class _TaskDetailPage extends StatefulWidget {
  final EastAppApi api;
  final TaskRecord initialRecord;
  final bool allowRating;

  const _TaskDetailPage({
    required this.api,
    required this.initialRecord,
    required this.allowRating,
  });

  @override
  State<_TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<_TaskDetailPage> {
  late TaskRecord record;
  late Set<String> selectedChecklistItemIds;
  final List<String> selectedPhotoPaths = [];
  bool changed = false;
  bool loading = false;
  bool loadingLinkedSop = false;
  List<KnowledgeItem>? linkedSopVersions;

  bool get acceptingInput =>
      record.status == TaskStatus.pending && record.canContribute;

  bool get scheduledToday =>
      _dateOnly(record.taskDate) == _dateOnly(DateTime.now());

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
      final result = await widget.api.taskRecord(record.id);
      if (!mounted) return;
      final serverRecordChanged = result.status != record.status ||
          result.photoCount != record.photoCount ||
          result.submittedAt != record.submittedAt ||
          result.ratedAt != record.ratedAt;
      final pathsToDelete = result.status == TaskStatus.pending
          ? const <String>[]
          : List<String>.from(selectedPhotoPaths);
      setState(() {
        record = result;
        changed = changed || serverRecordChanged;
        loading = false;
        if (result.status != TaskStatus.pending) {
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

  void applyServerUpdate(TaskRecord value) {
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

  void toggleCheck(TaskChecklistItem item, bool completed) {
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
      MaterialPageRoute(builder: (_) => const _TaskCameraPage()),
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
      MaterialPageRoute(builder: (_) => const _TaskCameraPage()),
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
    if (mounted) {
      changed = true;
      await refresh();
    }
  }

  Future<void> submit() async {
    final confirmed = await _confirmAction(
      context,
      title: 'Submit Task?',
      message:
          'The final checklist and selected photos will be stored and locked permanently.',
      action: 'Submit',
    );
    if (!confirmed || !mounted) return;
    try {
      applyServerUpdate(
        await widget.api.submitTask(
          recordId: record.id,
          completedChecklistItemIds:
              selectedChecklistItemIds.toList(growable: false),
          photoPaths: List<String>.from(selectedPhotoPaths),
        ),
      );
    } on EastAppApiException catch (error) {
      if (error.code == 'TASK_ALREADY_SUBMITTED' && mounted) {
        await showAlreadySubmitted(error);
      }
      return;
    }
  }

  Future<void> rate() async {
    final value = await showDialog<_RatingResult>(
      context: context,
      builder: (_) => const _TaskRatingDialog(),
    );
    if (value == null || !mounted) return;
    try {
      applyServerUpdate(
        await widget.api.rateTask(
          recordId: record.id,
          rating: value.rating,
          comment: value.comment,
        ),
      );
    } on EastAppApiException {
      return;
    }
  }

  Future<void> openLinkedSop() async {
    final linkedSopId = record.linkedSopId;
    if (linkedSopId == null || loadingLinkedSop) return;
    setState(() => loadingLinkedSop = true);
    try {
      final versions = linkedSopVersions ??
          await widget.api.knowledgeSopVersions(linkedSopId);
      if (!mounted) return;
      linkedSopVersions = versions;
      setState(() => loadingLinkedSop = false);
      if (versions.isEmpty) return;
      final selected = versions.firstWhere(
        (item) => item.id == linkedSopId,
        orElse: () => versions.first,
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (routeContext) => Scaffold(
            backgroundColor: AppColours.background,
            body: SafeArea(
              child: KnowledgeSopDetailView(
                api: widget.api,
                item: selected,
                versions: versions,
                tagNameFor: (tagId) {
                  for (final version in versions) {
                    if (version.tagId == tagId && version.tagName.isNotEmpty) {
                      return version.tagName;
                    }
                  }
                  return 'Unknown Tag';
                },
                onBack: () => Navigator.of(routeContext).pop(),
              ),
            ),
          ),
        ),
      );
    } on EastAppApiException {
      if (mounted) setState(() => loadingLinkedSop = false);
    }
  }

  void close() {
    Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) close();
      },
      child: Scaffold(
        backgroundColor: AppColours.background,
        appBar: AppBar(
          leading: IconButton(
            onPressed: close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(text.t('Task')),
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
                      '${record.tagName} · ${record.scheduleType.label} · ${_formatDate(record.taskDate)}',
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
                        value: record.status == TaskStatus.pending
                            ? selectedChecklistItemIds.contains(item.id)
                            : item.completed,
                        onChanged: acceptingInput
                            ? (value) => toggleCheck(item, value ?? false)
                            : null,
                        title: Text(
                          item.description,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: record.status == TaskStatus.pending ||
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
                            '${text.t(record.status == TaskStatus.pending ? 'Selected Photos' : 'Submitted Photos')} '
                            '${record.status == TaskStatus.pending ? selectedPhotoPaths.length : record.photoCount}'
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
                        record.status == TaskStatus.pending
                            ? 'Photos remain only on this screen and upload only when u tap Submit Task. Tap a selected photo to view, remove or retake it.'
                            : 'Submitted photos are permanently locked.',
                      ),
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontSize: AppTextSize.s13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.status == TaskStatus.pending &&
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
                          return _SelectedTaskPhotoTile(
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
                          return _TaskPhotoTile(
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
              if (record.status != TaskStatus.pending) ...[
                const SizedBox(height: 12),
                _SubmissionCard(record: record),
              ],
              if (record.status == TaskStatus.done) ...[
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
              ] else if (record.status == TaskStatus.pending) ...[
                const SizedBox(height: 12),
                Text(
                  text.t(
                    record.canContribute
                        ? 'Complete every checklist item and the minimum photo count to submit.'
                        : !scheduledToday
                            ? 'This Task can only be completed on its scheduled date.'
                            : 'Only users assigned to this Tag may contribute or submit.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (widget.allowRating && record.canRate) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Rate Task',
                  icon: Icons.star_rounded,
                  onPressed: rate,
                ),
              ],
              if (record.linkedSopId != null) ...[
                const SizedBox(height: 16),
                WhiteCard(
                  padding: EdgeInsets.zero,
                  child: Pressable(
                    onTap: loadingLinkedSop ? null : openLinkedSop,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColours.blue.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.play_circle_outline_rounded,
                              color: AppColours.blue,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.content(
                                    record.linkedSopTitle ??
                                        text.t('Linked Video'),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  text.t('View SOP'),
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final TaskRecord record;

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
  final TaskRecord record;

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
  final List<TaskAuditEntry> entries;

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

class _SelectedTaskPhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onTap;

  const _SelectedTaskPhotoTile({
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

class _TaskPhotoTile extends StatefulWidget {
  final EastAppApi api;
  final TaskPhoto photo;
  final Future<void> Function(Uint8List bytes) onTap;

  const _TaskPhotoTile({
    super.key,
    required this.api,
    required this.photo,
    required this.onTap,
  });

  @override
  State<_TaskPhotoTile> createState() => _TaskPhotoTileState();
}

class _TaskPhotoTileState extends State<_TaskPhotoTile> {
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

class _TaskCameraPage extends StatefulWidget {
  const _TaskCameraPage();

  @override
  State<_TaskCameraPage> createState() => _TaskCameraPageState();
}

class _TaskCameraPageState extends State<_TaskCameraPage> {
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

class TaskTemplatePage extends StatefulWidget {
  final EastAppApi api;
  final String tenantId;
  final List<StockTag> initialTags;
  final TaskTemplate? template;

  const TaskTemplatePage({
    required this.api,
    required this.tenantId,
    required this.initialTags,
    this.template,
  });

  @override
  State<TaskTemplatePage> createState() =>
      _TaskTemplatePageState();
}

class _TaskTemplatePageState extends State<TaskTemplatePage> {
  late final TextEditingController titleController;
  late final TextEditingController instructionController;
  final List<TextEditingController> checklistControllers = [];
  late List<StockTag> tags;
  String? tagId;
  int requiredPhotoCount = 1;
  int checklistCount = 1;
  TaskScheduleType scheduleType = TaskScheduleType.daily;
  late DateTime firstTaskDate;
  DateTime? endDate;
  bool active = true;
  bool loadingTags = false;
  String? linkedSopId;
  String? linkedSopTitle;
  List<KnowledgeItem>? sopOptions;
  bool loadingSops = false;

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
    scheduleType = template?.scheduleType ?? TaskScheduleType.daily;
    firstTaskDate = _dateOnly(template?.firstTaskDate ?? DateTime.now());
    endDate = template?.endDate == null
        ? null
        : _dateOnly(template!.endDate!);
    active = template?.active ?? true;
    linkedSopId = template?.linkedSopId;
    linkedSopTitle = template?.linkedSopTitle;
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
        forceRefresh: false,
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

  Future<void> selectFirstTaskDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: firstTaskDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: scheduleType == TaskScheduleType.adHoc
          ? 'Select Task Date'
          : 'Select First Task Date',
    );
    if (selected == null || !mounted) return;
    setState(() {
      firstTaskDate = _dateOnly(selected);
      if (endDate?.isBefore(firstTaskDate) == true) endDate = null;
    });
  }

  Future<void> selectEndDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: endDate ?? firstTaskDate,
      firstDate: firstTaskDate,
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Select End Date',
    );
    if (selected == null || !mounted) return;
    setState(() => endDate = _dateOnly(selected));
  }

  Future<void> selectLinkedSop() async {
    if (loadingSops) return;
    var options = sopOptions;
    if (options == null) {
      setState(() => loadingSops = true);
      try {
        final page = await widget.api.knowledgeSops(size: 100);
        if (!mounted) return;
        options = page.content;
        sopOptions = options;
        setState(() => loadingSops = false);
      } on EastAppApiException {
        if (mounted) setState(() => loadingSops = false);
        return;
      }
    }
    final loadedOptions = options;
    if (!mounted || loadedOptions == null) return;
    final selected = await Navigator.of(context).push<KnowledgeItem>(
      MaterialPageRoute(
        builder: (_) => _TaskSopPickerPage(
          items: loadedOptions,
          selectedSopId: linkedSopId,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      linkedSopId = selected.id;
      linkedSopTitle = selected.title;
    });
  }

  Future<void> save() async {
    final title = titleController.text.trim();
    final selectedTagId = tagId;
    final checks = checklistControllers
        .take(checklistCount)
        .map((controller) => controller.text.trim())
        .toList(growable: false);
    if (endDate?.isBefore(firstTaskDate) == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before the first task date.'),
        ),
      );
      return;
    }
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
          ? 'Create Task?'
          : 'Update Task?',
      message: widget.template == null
          ? 'This creates one shared ${scheduleType.label.toLowerCase()} Task for users assigned to the selected Tag.'
          : 'Existing Task records stay unchanged. This update applies to future scheduled Tasks.',
      action: 'Save',
    );
    if (!confirmed || !mounted) return;
    try {
      late final TaskTemplate saved;
      if (widget.template == null) {
        saved = await widget.api.createTaskTemplate(
          tenantId: widget.tenantId,
          title: title,
          instruction: instructionController.text,
          tagId: selectedTagId,
          linkedSopId: linkedSopId,
          requiredPhotoCount: requiredPhotoCount,
          scheduleType: scheduleType,
          firstTaskDate: firstTaskDate,
          endDate: scheduleType == TaskScheduleType.adHoc ? null : endDate,
          checklistItems: checks,
          active: active,
        );
      } else {
        saved = await widget.api.updateTaskTemplate(
          tenantId: widget.tenantId,
          templateId: widget.template!.id,
          title: title,
          instruction: instructionController.text,
          tagId: selectedTagId,
          linkedSopId: linkedSopId,
          requiredPhotoCount: requiredPhotoCount,
          scheduleType: scheduleType,
          firstTaskDate: firstTaskDate,
          endDate: scheduleType == TaskScheduleType.adHoc ? null : endDate,
          checklistItems: checks,
          active: active,
        );
      }
      if (mounted) Navigator.of(context).pop(saved);
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
          text.t(widget.template == null ? 'Create Task' : 'Edit Task'),
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
                  'Schedule',
                  style: TextStyle(
                    fontSize: AppTextSize.s18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<TaskScheduleType>(
                  value: scheduleType,
                  decoration: const InputDecoration(
                    labelText: 'Schedule Type',
                    prefixIcon: Icon(Icons.event_repeat_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: TaskScheduleType.values
                      .map(
                        (type) => DropdownMenuItem<TaskScheduleType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      scheduleType = value;
                      if (value == TaskScheduleType.adHoc) endDate = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: selectFirstTaskDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    '${scheduleType == TaskScheduleType.adHoc ? 'Task date' : 'First task date'}: ${_formatDate(firstTaskDate)}',
                  ),
                ),
                if (scheduleType != TaskScheduleType.adHoc) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectEndDate,
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text(
                            endDate == null
                                ? 'End date: No end date'
                                : 'End date: ${_formatDate(endDate!)}',
                          ),
                        ),
                      ),
                      if (endDate != null) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Remove end date',
                          onPressed: () => setState(() => endDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _scheduleDescription(scheduleType, firstTaskDate),
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontSize: AppTextSize.s13,
                    fontWeight: FontWeight.w600,
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
                    labelText: 'Minimum photos required',
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
                  subtitle: const Text('Active Tasks appear on their scheduled dates.'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${text.t('Linked Video')} (${text.t('Optional')})',
                  style: const TextStyle(
                    fontSize: AppTextSize.s18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text.t(
                    'Link an existing Knowledge SOP to teach staff how to complete this task.',
                  ),
                  style: const TextStyle(
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loadingSops ? null : selectLinkedSop,
                        icon: Icon(
                          linkedSopId == null
                              ? Icons.video_library_outlined
                              : Icons.play_circle_outline_rounded,
                        ),
                        label: Text(
                          linkedSopTitle == null
                              ? text.t('Select SOP')
                              : text.content(linkedSopTitle!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (linkedSopId != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: text.t('Clear'),
                        onPressed: () => setState(() {
                          linkedSopId = null;
                          linkedSopTitle = null;
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
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

class _TaskSopPickerPage extends StatefulWidget {
  final List<KnowledgeItem> items;
  final String? selectedSopId;

  const _TaskSopPickerPage({
    required this.items,
    required this.selectedSopId,
  });

  @override
  State<_TaskSopPickerPage> createState() => _TaskSopPickerPageState();
}

class _TaskSopPickerPageState extends State<_TaskSopPickerPage> {
  final searchController = TextEditingController();
  String appliedSearch = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_TaskSopGroup> visibleGroups() {
    final grouped = <String, List<KnowledgeItem>>{};
    for (final item in widget.items.where((item) => item.type == 'SOP')) {
      final groupId = item.linkGroupId.isEmpty ? item.id : item.linkGroupId;
      grouped.putIfAbsent(groupId, () => <KnowledgeItem>[]).add(item);
    }
    final query = appliedSearch.trim().toLowerCase();
    final groups = grouped.entries
        .map((entry) => _TaskSopGroup(entry.key, entry.value))
        .where((group) {
          if (query.isEmpty) return true;
          return group.versions.any(
            (item) => [
              item.title,
              item.description,
              item.expectedOutcome,
              item.tagName,
              item.language.label,
            ].join(' ').toLowerCase().contains(query),
          );
        })
        .toList();
    groups.sort(
      (left, right) => left.title.toLowerCase().compareTo(
            right.title.toLowerCase(),
          ),
    );
    return groups;
  }

  void applySearch() {
    FocusScope.of(context).unfocus();
    setState(() => appliedSearch = searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final groups = visibleGroups();
    return Scaffold(
      backgroundColor: AppColours.background,
      appBar: AppBar(
        title: Text(text.t('Select SOP')),
        backgroundColor: AppColours.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        children: [
          WhiteCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => applySearch(),
                    decoration: InputDecoration(
                      labelText: text.t('Search SOP...'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: applySearch,
                  child: Text(text.t('Search')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            WhiteCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    text.t('No SOP found.'),
                    style: const TextStyle(
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            for (final group in groups) ...[
              WhiteCard(
                key: ValueKey(group.id),
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(group.selectionFor(
                    widget.selectedSopId,
                  )),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColours.blue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.video_library_outlined,
                            color: AppColours.blue,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.content(group.title),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  text.content(group.tagName),
                                  ...group.versions.map(
                                    (item) => text.t(item.language.label),
                                  ),
                                ].where((value) => value.isNotEmpty).join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColours.textMuted,
                                  fontSize: AppTextSize.s13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          group.contains(widget.selectedSopId)
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: group.contains(widget.selectedSopId)
                              ? AppColours.green
                              : AppColours.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _TaskSopGroup {
  final String id;
  final List<KnowledgeItem> versions;

  _TaskSopGroup(this.id, List<KnowledgeItem> items)
      : versions = [...items]
          ..sort(
            (left, right) => left.language.index.compareTo(
              right.language.index,
            ),
          );

  String get title => versions.first.title;
  String get tagName => versions.first.tagName;

  bool contains(String? sopId) =>
      sopId != null && versions.any((item) => item.id == sopId);

  KnowledgeItem selectionFor(String? selectedSopId) {
    for (final item in versions) {
      if (item.id == selectedSopId) return item;
    }
    return versions.first;
  }
}

class _TaskRatingDialog extends StatefulWidget {
  const _TaskRatingDialog();

  @override
  State<_TaskRatingDialog> createState() =>
      _TaskRatingDialogState();
}

class _TaskRatingDialogState extends State<_TaskRatingDialog> {
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
      title: const Text('Rate Task'),
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
  final TaskStatus status;

  const _TaskStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colour = switch (status) {
      TaskStatus.pending => AppColours.orange,
      TaskStatus.submitted => AppColours.blue,
      TaskStatus.done => AppColours.green,
    };
    final background = switch (status) {
      TaskStatus.pending => AppColours.orangeSoft,
      TaskStatus.submitted => const Color(0xFFEAF3FF),
      TaskStatus.done => AppColours.greenSoft,
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

String _statusLabel(TaskStatus status) {
  return switch (status) {
    TaskStatus.pending => 'Pending',
    TaskStatus.submitted => 'Submitted',
    TaskStatus.done => 'Done',
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

String _formatTemplateSchedule(TaskTemplate template) {
  if (template.scheduleType == TaskScheduleType.adHoc) {
    return 'Ad hoc · ${_formatDate(template.firstTaskDate)}';
  }
  final end = template.endDate == null
      ? 'No end date'
      : 'Ends ${_formatDate(template.endDate!)}';
  return '${template.scheduleType.label} · Starts ${_formatDate(template.firstTaskDate)} · $end';
}

String _scheduleDescription(TaskScheduleType type, DateTime firstTaskDate) {
  final date = _formatDate(firstTaskDate);
  return switch (type) {
    TaskScheduleType.adHoc => 'Runs once on $date.',
    TaskScheduleType.daily => 'Repeats every day from $date.',
    TaskScheduleType.weekly => 'Repeats every 7 days from $date.',
    TaskScheduleType.biweekly => 'Repeats every 14 days from $date.',
    TaskScheduleType.monthly =>
      'Repeats monthly from $date. Shorter months use their final day.',
  };
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
