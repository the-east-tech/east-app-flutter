part of 'stock_screen.dart';

class _TagSetupPage extends StatefulWidget {
  final EastAppApi api;
  final String currentTenantId;
  final List<StockTag> tags;
  final VoidCallback onBack;
  final Future<void> Function(StockTag tag) onCreateTag;
  final Future<void> Function(StockTag tag) onUpdateTag;
  final Future<bool> Function(Set<String> tagIds) onDeleteTags;

  const _TagSetupPage({
    required this.api,
    required this.currentTenantId,
    required this.tags,
    required this.onBack,
    required this.onCreateTag,
    required this.onUpdateTag,
    required this.onDeleteTags,
  });

  @override
  State<_TagSetupPage> createState() => _TagSetupPageState();
}

class _TagSetupPageState extends State<_TagSetupPage> {
  final searchController = TextEditingController();
  final Set<String> selectedIds = <String>{};

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<StockTag> get filteredTags {
    final query = searchController.text.trim().toLowerCase();
    return query.isEmpty ? widget.tags : widget.tags.where((tag) => tag.tag.toLowerCase().contains(query)).toList();
  }

  void toggleSelected(String id) {
    setState(() => selectedIds.contains(id) ? selectedIds.remove(id) : selectedIds.add(id));
  }

  Future<void> deleteSelected() async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(context, action: 'Delete Selected Tags?', details: 'This will permanently delete the selected unassigned tags.');
    if (!confirmed || !mounted) return;
    final deleted = await widget.onDeleteTags(Set<String>.from(selectedIds));
    if (!mounted) return;
    if (!deleted) {
      showErrorSnackBar(context, text.t('Assigned tags cannot be deleted'));
      return;
    }
    setState(selectedIds.clear);
    showSuccessSnackBar(context, text.t('Deleted'));
  }

  void addTag() {
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.9,
      builder: (_) => _TagEditorSheet(
        api: widget.api,
        currentTenantId: widget.currentTenantId,
        allTags: widget.tags,
        onSave: (name, assignedUsers) => widget.onCreateTag(
          StockTag(
            id: 'TAG${DateTime.now().millisecondsSinceEpoch}',
            tag: name,
            createdBy: headId,
            createdDate: 'Today',
            lastUpdated: 'Today just now',
            assignedUsers: assignedUsers,
          ),
        ),
      ),
    );
  }

  void showTagDetail(StockTag tag) {
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.9,
      builder: (_) => _TagEditorSheet(
        api: widget.api,
        currentTenantId: widget.currentTenantId,
        allTags: widget.tags,
        tag: tag,
        onSave: (name, assignedUsers) => widget.onUpdateTag(tag.copyWith(tag: name, lastUpdated: 'Today just now', assignedUsers: assignedUsers)),
        onDelete: () => widget.onDeleteTags({tag.id}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final items = filteredTags;
    final selecting = selectedIds.isNotEmpty;
    return _PageScaffold(
      title: text.t('Tag'),
      subtitle: text.t('Custom Category'),
      onBack: widget.onBack,
      trailing: SizedBox(
        width: selecting ? 120 : 150,
        child: selecting
            ? ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColours.red, foregroundColor: Colors.white), onPressed: deleteSelected, icon: const Icon(Icons.delete_outline), label: Text(text.t('Delete')))
            : PrimaryButton(text: text.t('Add Tag'), icon: Icons.add_rounded, onPressed: addTag),
      ),
      children: [
        TextField(controller: searchController, style: AppTextStyles.formValue, onChanged: (_) => setState(() {}), decoration: _inputDecoration(text.t('Search')).copyWith(prefixIcon: const Icon(Icons.search_rounded))),
        const SizedBox(height: 12),
        if (items.isEmpty)
          WhiteCard(child: Text(text.t('No tag found'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)))
        else
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                _CompactTagRow(
                  tag: items[i],
                  selected: selectedIds.contains(items[i].id),
                  selecting: selecting,
                  onTap: () => selecting ? toggleSelected(items[i].id) : showTagDetail(items[i]),
                  onLongPress: () => toggleSelected(items[i].id),
                ),
                if (i != items.length - 1) const Divider(height: 1),
              ],
            ]),
          ),
      ],
    );
  }
}

class _CompactTagRow extends StatelessWidget {
  final StockTag tag;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CompactTagRow({required this.tag, required this.selected, required this.selecting, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 180), width: 38, height: 38, decoration: BoxDecoration(color: selected ? AppColours.blue : const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(12)), child: Icon(selected ? Icons.check_rounded : Icons.sell_outlined, color: selected ? Colors.white : AppColours.blue, size: 21)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text.content(tag.tag), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${tag.assignedUsers.length} assigned user${tag.assignedUsers.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
            ])),
            if (selecting) Checkbox(value: selected, onChanged: (_) => onTap()) else const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _TagEditorSheet extends StatefulWidget {
  final EastAppApi api;
  final String currentTenantId;
  final List<StockTag> allTags;
  final StockTag? tag;
  final Future<void> Function(String name, List<StockTagAssignee> assignedUsers) onSave;
  final Future<bool> Function()? onDelete;

  const _TagEditorSheet({required this.api, required this.currentTenantId, required this.allTags, required this.onSave, this.tag, this.onDelete});

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  late final TextEditingController tagController;
  final userSearchController = TextEditingController();
  final Set<String> selectedUserIds = <String>{};
  final Map<String, StockTagAssignee> knownUsers = <String, StockTagAssignee>{};
  List<EastAppUser> loadedUsers = const [];
  bool loadingUsers = false;

  @override
  void initState() {
    super.initState();
    tagController = TextEditingController(text: widget.tag?.tag ?? '');
    for (final user in widget.tag?.assignedUsers ?? const <StockTagAssignee>[]) {
      selectedUserIds.add(user.userId);
      knownUsers[user.userId] = user;
    }
  }

  @override
  void dispose() {
    tagController.dispose();
    userSearchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    if (loadingUsers) return;
    setState(() => loadingUsers = true);
    try {
      final page = await widget.api.listUsers(
        tenantId: widget.currentTenantId,
        search: userSearchController.text,
        active: true,
        page: 0,
        size: 100,
      );
      if (!mounted) return;
      for (final user in page.content) {
        knownUsers[user.id] = StockTagAssignee(userId: user.id, fullName: user.fullName, employeeId: user.employeeId, role: user.role.systemKey);
      }
      setState(() => loadedUsers = page.content);
    } on EastAppApiException {
      // Global API error handling already presents the failure.
    } finally {
      if (mounted) setState(() => loadingUsers = false);
    }
  }

  Future<void> save() async {
    final text = AppTextScope.of(context);
    final name = tagController.text.trim();
    if (name.isEmpty) {
      showErrorSnackBar(context, text.t('Tag is required'));
      return;
    }
    final duplicate = widget.allTags.any((item) => item.id != widget.tag?.id && item.tag.toLowerCase() == name.toLowerCase());
    if (duplicate) {
      showErrorSnackBar(context, text.t('Tag already exists'));
      return;
    }
    final confirmed = await confirmDataChange(context, action: widget.tag == null ? 'Create Tag?' : 'Update Tag?', details: 'This saves the tag name and the users responsible for its shared Tasks.');
    if (!confirmed || !mounted) return;
    final users = selectedUserIds.map((id) => knownUsers[id]).whereType<StockTagAssignee>().toList(growable: false);
    final saved = await runStockRequest(context, () => widget.onSave(name, users));
    if (!saved || !mounted) return;
    showSuccessSnackBar(context, text.t('Saved'));
    Navigator.of(context).pop();
  }

  Future<void> deleteTag() async {
    final callback = widget.onDelete;
    if (callback == null) return;
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(context, action: 'Delete Tag?', details: 'This permanently deletes this unused tag.');
    if (!confirmed || !mounted) return;
    final deleted = await callback();
    if (!mounted) return;
    if (!deleted) {
      showErrorSnackBar(context, text.t('Assigned tags cannot be deleted'));
      return;
    }
    showSuccessSnackBar(context, text.t('Deleted'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final existingUsers = selectedUserIds.map((id) => knownUsers[id]).whereType<StockTagAssignee>().toList(growable: false);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 12, 0), child: Column(children: [
        stockBottomSheetHandle(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(text.t(widget.tag == null ? 'Add Tag' : 'Edit Tag'), style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
        ]),
      ])),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: [
        _DialogInput(label: text.t('Tag'), controller: tagController, hint: text.t('Example: Kitchen')),
        if (widget.tag != null) ...[
          const SizedBox(height: 10),
          Text('${text.t('Created By')}: ${widget.tag!.createdBy} · ${widget.tag!.createdDate}', style: const TextStyle(color: AppColours.textMuted, fontSize: AppTextSize.s12, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text(text.t('Assigned Users (Optional)'), style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w800))),
          SmallStatusPill(text: '${selectedUserIds.length} selected', textColour: AppColours.blue, backgroundColour: const Color(0xFFEAF3FF)),
        ]),
        const SizedBox(height: 6),
        Text(text.t('Everyone assigned here shares the same Tasks. Any one of them may contribute or submit.'), style: const TextStyle(color: AppColours.textMuted, fontSize: AppTextSize.s13, fontWeight: FontWeight.w600)),
        if (existingUsers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: existingUsers.map((user) => InputChip(label: Text('${user.fullName} · ${user.employeeId}'), onDeleted: () => setState(() => selectedUserIds.remove(user.userId)))).toList()),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: userSearchController, textInputAction: TextInputAction.search, onSubmitted: (_) => loadUsers(), decoration: _inputDecoration(text.t('Name or Employee ID')).copyWith(prefixIcon: const Icon(Icons.search_rounded)))),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: loadingUsers ? null : loadUsers, icon: loadingUsers ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded), label: Text(text.t('Load'))),
        ]),
        if (loadedUsers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColours.border), borderRadius: BorderRadius.circular(14)),
            child: Column(children: loadedUsers.map((user) => CheckboxListTile(
              dense: true,
              value: selectedUserIds.contains(user.id),
              title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${user.employeeId} · ${user.role.name}'),
              onChanged: (value) => setState(() => value == true ? selectedUserIds.add(user.id) : selectedUserIds.remove(user.id)),
            )).toList()),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(text: text.t('Save'), icon: Icons.save_outlined, onPressed: save),
        if (widget.onDelete != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: deleteTag, icon: const Icon(Icons.delete_outline), label: Text(text.t('Delete')), style: OutlinedButton.styleFrom(foregroundColor: AppColours.red, padding: const EdgeInsets.symmetric(vertical: 14))),
        ],
      ])),
    ]);
  }
}
