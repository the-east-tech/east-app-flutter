part of 'stock_screen.dart';

class _AuditTrailPage extends StatefulWidget {
  final Future<EastAppPage<StockAuditEntry>> Function(DateTime rangeStart, DateTime rangeEnd, int page, int size) onLoadEntries;
  final VoidCallback onBack;

  const _AuditTrailPage({required this.onLoadEntries, required this.onBack});

  @override
  State<_AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<_AuditTrailPage> {
  final searchController = TextEditingController();
  String moduleFilter = 'All';
  String actorFilter = 'All';
  late DateTime rangeStart;
  late DateTime rangeEnd;
  List<StockAuditEntry> loadedEntries = const [];
  bool hasLoaded = false;
  bool loading = false;
  bool loadingMore = false;
  int loadedPage = -1;
  int totalEntries = 0;
  bool lastPage = true;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    rangeEnd = today;
    rangeStart = today.subtract(const Duration(days: 29));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
  bool _sameDate(DateTime left, DateTime right) => left.year == right.year && left.month == right.month && left.day == right.day;

  String _formatDate(DateTime value) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String get rangeLabel => '${_formatDate(rangeStart)} – ${_formatDate(rangeEnd)}';

  List<String> get moduleOptions {
    final values = loadedEntries.map((e) => e.module).where((v) => v.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<String> get actorOptions {
    final values = loadedEntries.map((e) => e.actorName).where((v) => v.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<StockAuditEntry> get filteredEntries {
    final query = searchController.text.trim().toLowerCase();
    final entries = loadedEntries.where((entry) {
      final matchesSearch = query.isEmpty ||
          entry.module.toLowerCase().contains(query) ||
          entry.action.toLowerCase().contains(query) ||
          entry.itemName.toLowerCase().contains(query) ||
          entry.itemId.toLowerCase().contains(query) ||
          entry.actorName.toLowerCase().contains(query) ||
          entry.actorId.toLowerCase().contains(query) ||
          entry.changes.any((change) => change.field.toLowerCase().contains(query) || change.oldValue.toLowerCase().contains(query) || change.newValue.toLowerCase().contains(query));
      return matchesSearch && (moduleFilter == 'All' || entry.module == moduleFilter) && (actorFilter == 'All' || entry.actorName == actorFilter);
    }).toList()..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return entries;
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
      if (mounted) showWarningSnackBar(context, text.t('Maximum 30 days.'));
      return;
    }
    setState(() {
      rangeStart = start;
      rangeEnd = end;
      moduleFilter = 'All';
      actorFilter = 'All';
      searchController.clear();
      loadedEntries = const [];
      hasLoaded = false;
      loadedPage = -1;
      totalEntries = 0;
      lastPage = true;
    });
  }

  Future<void> loadAuditEntries({bool reset = true}) async {
    if (loading || loadingMore || (!reset && lastPage)) return;
    setState(() => reset ? loading = true : loadingMore = true);
    try {
      final result = await widget.onLoadEntries(rangeStart, rangeEnd, reset ? 0 : loadedPage + 1, 50);
      if (!mounted) return;
      setState(() {
        loadedEntries = reset ? result.content : [...loadedEntries, ...result.content];
        hasLoaded = true;
        loadedPage = result.page;
        totalEntries = result.totalElements;
        lastPage = result.last;
        if (reset) {
          moduleFilter = 'All';
          actorFilter = 'All';
          searchController.clear();
        }
      });
    } on EastAppApiException catch (_) {
      // Global API error handling already presents the failure.
    } finally {
      if (mounted) setState(() { loading = false; loadingMore = false; });
    }
  }

  Widget auditDropdown({required String label, required String value, required List<String> options, required ValueChanged<String> onChanged}) {
    final safeValue = options.contains(value) ? value : 'All';
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      isDense: true,
      style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13),
      items: options.map((option) => DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis, style: AppTextStyles.formValue.copyWith(fontSize: AppTextSize.s13, fontWeight: FontWeight.w500)))).toList(),
      onChanged: (newValue) { if (newValue != null) onChanged(newValue); },
      decoration: _inputDecoration(label).copyWith(isDense: true, hintText: null, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11)),
    );
  }

  List<Widget> auditRows(List<StockAuditEntry> entries) {
    final rows = <Widget>[];
    DateTime? previousDate;
    for (final entry in entries) {
      final entryDate = _dateOnly(entry.capturedAt);
      if (previousDate == null || !_sameDate(previousDate, entryDate)) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 4));
        rows.add(Padding(padding: const EdgeInsets.fromLTRB(2, 2, 2, 8), child: Text(_formatDate(entryDate), style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w800, color: AppColours.textMuted))));
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: _AuditEntryCard(entry: entry)));
      previousDate = entryDate;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final entries = hasLoaded ? filteredEntries : const <StockAuditEntry>[];
    final actorCount = loadedEntries.map((e) => e.actorId).where((v) => v.trim().isNotEmpty).toSet().length;
    return _PageScaffold(
      title: text.t('Audit Trail'),
      subtitle: text.t('State changes only. Select up to 30 days.'),
      onBack: widget.onBack,
      children: [
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: selectDateRange, icon: const Icon(Icons.date_range_rounded, size: 20), label: Row(children: [Expanded(child: Text(rangeLabel, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w800))), const Icon(Icons.chevron_right_rounded, size: 20)]))),
        const SizedBox(height: 12),
        PrimaryButton(text: loading ? text.t('Loading...') : text.t(hasLoaded ? 'Reload Audit' : 'Load Audit'), icon: loading ? null : Icons.download_rounded, onPressed: loading ? null : () => loadAuditEntries()),
        const SizedBox(height: 12),
        if (!hasLoaded)
          WhiteCard(child: Text(text.t('Select a date range, then load the audit trail.'), style: const TextStyle(fontSize: AppTextSize.s15, fontWeight: FontWeight.w600, color: AppColours.textMuted)))
        else ...[
          Row(children: [
            Expanded(child: _MiniMetric(label: text.t('Entries'), value: '$totalEntries', icon: Icons.manage_history_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _MiniMetric(label: text.t('Actors'), value: '$actorCount', icon: Icons.people_outline_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _MiniMetric(label: text.t('Showing'), value: '${entries.length}', icon: Icons.filter_alt_outlined)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: searchController, style: AppTextStyles.formValue, onChanged: (_) => setState(() {}), decoration: _inputDecoration(text.t('Search audit trail')).copyWith(prefixIcon: const Icon(Icons.search_rounded))),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: width, child: auditDropdown(label: text.t('Actor'), value: actorFilter, options: actorOptions, onChanged: (value) => setState(() => actorFilter = value))),
              SizedBox(width: width, child: auditDropdown(label: text.t('Module'), value: moduleFilter, options: moduleOptions, onChanged: (value) => setState(() => moduleFilter = value))),
            ]);
          }),
          const SizedBox(height: 14),
          if (entries.isEmpty) WhiteCard(child: Text(text.t('No audit trail found.'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700))) else ...auditRows(entries),
          if (!lastPage) ...[
            const SizedBox(height: 4),
            PrimaryButton(text: loadingMore ? text.t('Loading...') : text.t('Load More'), icon: loadingMore ? null : Icons.expand_more_rounded, onPressed: loadingMore ? null : () => loadAuditEntries(reset: false)),
          ],
        ],
      ],
    );
  }
}
