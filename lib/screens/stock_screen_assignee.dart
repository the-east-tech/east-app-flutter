part of 'stock_screen.dart';

class _SkuAssigneePage extends StatefulWidget {
  final EastAppApi api;
  final String currentTenantId;
  final VoidCallback onBack;
  final Future<void> Function(StockSku sku) onUpdateSku;

  const _SkuAssigneePage({
    required this.api,
    required this.currentTenantId,
    required this.onBack,
    required this.onUpdateSku,
  });

  @override
  State<_SkuAssigneePage> createState() => _SkuAssigneePageState();
}

class _SkuAssigneePageState extends State<_SkuAssigneePage> {
  static const _pageSize = 50;

  final searchController = TextEditingController();
  final List<StockSku> loadedSkus = [];
  final List<EastAppUser> availableUsers = [];

  String assignmentFilter = 'Assigned';
  bool hasLoaded = false;
  bool skusLoading = false;
  bool skusLoadingMore = false;
  String? skusError;
  int skusPage = 0;
  int totalSkus = 0;
  bool skusLastPage = true;
  DateTime? updatedAt;

  bool usersLoaded = false;
  bool usersLoading = false;
  bool usersLoadingMore = false;
  String? usersError;
  int usersPage = 0;
  bool usersLastPage = true;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _clearLoadedResults() {
    if (!hasLoaded && loadedSkus.isEmpty && skusError == null) return;
    setState(() {
      hasLoaded = false;
      loadedSkus.clear();
      skusError = null;
      skusPage = 0;
      totalSkus = 0;
      skusLastPage = true;
      updatedAt = null;
    });
  }

  Future<void> loadSkus({required bool reset, bool forceRefresh = false}) async {
    if (skusLoading || skusLoadingMore || (!reset && skusLastPage)) return;
    final nextPage = reset ? 0 : skusPage + 1;
    setState(() {
      if (reset) {
        skusLoading = true;
        skusError = null;
      } else {
        skusLoadingMore = true;
      }
    });

    try {
      if (reset && forceRefresh) {
        await widget.api.invalidateFeatureCache(
          EastAppApi.stockSkusCachePrefix(widget.currentTenantId),
        );
      }
      final result = await widget.api.stockSkus(
        tenantId: widget.currentTenantId,
        search: searchController.text.trim(),
        active: true,
        assigned: assignmentFilter == 'Assigned',
        page: nextPage,
        size: _pageSize,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        if (reset) loadedSkus.clear();
        loadedSkus.addAll(result.content);
        skusPage = result.page;
        totalSkus = result.totalElements;
        skusLastPage = result.last;
        hasLoaded = true;
        updatedAt = DateTime.now();
        skusError = null;
      });
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        skusError = error.message;
        hasLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          skusLoading = false;
          skusLoadingMore = false;
        });
      }
    }
  }

  Future<bool> loadUsers({required bool reset}) async {
    if (usersLoading || usersLoadingMore || (!reset && usersLastPage)) return false;
    final nextPage = reset ? 0 : usersPage + 1;
    setState(() => reset ? usersLoading = true : usersLoadingMore = true);
    try {
      final result = await widget.api.listUsers(
        tenantId: widget.currentTenantId,
        active: true,
        page: nextPage,
        size: _pageSize,
      );
      if (!mounted) return false;
      setState(() {
        if (reset) availableUsers.clear();
        availableUsers.addAll(result.content);
        usersPage = result.page;
        usersLastPage = result.last;
        usersLoaded = true;
        usersError = null;
      });
      return true;
    } on EastAppApiException catch (error) {
      if (mounted) setState(() => usersError = error.message);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          usersLoading = false;
          usersLoadingMore = false;
        });
      }
    }
  }

  List<String> get assigneeOptions {
    final values = availableUsers
        .map((user) => user.fullName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  Future<void> openAssigneePicker(StockSku sku) async {
    final text = AppTextScope.of(context);
    if (!usersLoaded) {
      final loaded = await loadUsers(reset: true);
      if (!mounted) return;
      if (!loaded && usersError != null) {
        showErrorSnackBar(context, usersError!);
        return;
      }
    }

    final result = await showStockBottomSheet<List<String>>(
      context,
      maxHeightFactor: 0.72,
      builder: (sheetContext) {
        final selected = sku.assignedStaffNames.toSet();
        return StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Column(children: [
                  stockBottomSheetHandle(),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text(text.t('Assignee'), style: const TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
                  ]),
                  Align(alignment: Alignment.centerLeft, child: Text(text.content(sku.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s14, color: AppColours.textMuted, fontWeight: FontWeight.w700))),
                ]),
              ),
              Flexible(
                child: assigneeOptions.isEmpty
                    ? Padding(padding: const EdgeInsets.all(16), child: Text(text.t('No user available.'), style: AppTextStyles.formValue))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          ...assigneeOptions.map((user) => CheckboxListTile(
                            value: selected.contains(user),
                            title: Text(user),
                            onChanged: (value) => setSheetState(() => value == true ? selected.add(user) : selected.remove(user)),
                          )),
                          if (!usersLastPage)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: OutlinedButton.icon(
                                onPressed: usersLoadingMore ? null : () async {
                                  await loadUsers(reset: false);
                                  if (sheetContext.mounted) setSheetState(() {});
                                },
                                icon: usersLoadingMore
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.expand_more_rounded),
                                label: Text(text.t(usersLoadingMore ? 'Loading...' : 'Load more users')),
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Row(children: [
                  Expanded(child: PrimaryButton(text: text.t('Clear'), outlined: true, onPressed: () => Navigator.of(sheetContext).pop(<String>[]))),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton(text: text.t('Save'), icon: Icons.save_outlined, onPressed: () => Navigator.of(sheetContext).pop(selected.toList()))),
                ]),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;

    final confirmed = await confirmDataChange(
      context,
      action: 'Update SKU Assignees?',
      details: 'This will replace the assignee list for the selected SKU.',
    );
    if (!confirmed || !mounted) return;

    final updatedSku = sku.copyWith(assignedStaffNames: result);
    final saved = await runStockRequest(context, () => widget.onUpdateSku(updatedSku));
    if (!saved || !mounted) return;

    final stillMatches = assignmentFilter == 'Assigned'
        ? updatedSku.assignedStaffNames.isNotEmpty
        : updatedSku.assignedStaffNames.isEmpty;
    setState(() {
      final index = loadedSkus.indexWhere((item) => item.id == sku.id);
      if (index >= 0) {
        if (stillMatches) {
          loadedSkus[index] = updatedSku;
        } else {
          loadedSkus.removeAt(index);
          if (totalSkus > 0) totalSkus--;
        }
      }
    });
    showSuccessSnackBar(context, text.t('Assignee updated'));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final page = _PageScaffold(
      title: text.t('Assignee'),
      subtitle: text.t('Load Assigned or Unassigned SKU only when needed.'),
      onBack: widget.onBack,
      children: [
        DropdownButtonFormField<String>(
          initialValue: assignmentFilter,
          isExpanded: true,
          decoration: _inputDecoration(text.t('Assignment status')),
          items: const ['Assigned', 'Unassigned'].map((value) => DropdownMenuItem(value: value, child: Text(text.t(value)))).toList(),
          onChanged: (value) {
            if (value == null || value == assignmentFilter) return;
            setState(() => assignmentFilter = value);
            _clearLoadedResults();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => _clearLoadedResults(),
          textInputAction: TextInputAction.search,
          decoration: _inputDecoration(text.t('Search SKU (optional)')).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 12),
        PrimaryButton(text: text.t('Load'), icon: Icons.download_rounded, onPressed: skusLoading ? null : () => loadSkus(reset: true)),
        const SizedBox(height: 14),
        if (skusLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
        else if (skusError != null)
          WhiteCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(skusError!, style: const TextStyle(color: AppColours.red, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            PrimaryButton(text: text.t('Retry'), outlined: true, onPressed: () => loadSkus(reset: true)),
          ]))
        else if (!hasLoaded)
          WhiteCard(child: Text(text.t('Nothing is loaded by default. Select Assigned or Unassigned, then press Load.'), style: const TextStyle(fontSize: AppTextSize.s14, fontWeight: FontWeight.w600, color: AppColours.textMuted)))
        else if (loadedSkus.isEmpty)
          WhiteCard(child: Text(text.t('No SKU matches the selected criteria.'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)))
        else ...[
          Align(alignment: Alignment.centerLeft, child: Text('${text.t('Results')}: $totalSkus', style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w700, color: AppColours.textMuted))),
          const SizedBox(height: 8),
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(children: loadedSkus.map((sku) {
              final count = sku.assignedStaffNames.length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
                child: Row(children: [
                  _SkuPhotoThumb(sku: sku, size: 46),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(text.content(sku.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${text.content(sku.category)} · ${text.content(sku.location)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sku.assignedStaffName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
                  ])),
                  const SizedBox(width: 10),
                  SizedBox(width: 116, child: OutlinedButton.icon(onPressed: () => openAssigneePicker(sku), icon: const Icon(Icons.group_add_outlined, size: 18), label: Text(count == 0 ? text.t('Assign') : '$count ${text.t('user')}'))),
                ]),
              );
            }).toList()),
          ),
          if (!skusLastPage) ...[
            const SizedBox(height: 12),
            PrimaryButton(text: text.t(skusLoadingMore ? 'Loading...' : 'Load more'), outlined: true, icon: Icons.expand_more_rounded, onPressed: skusLoadingMore ? null : () => loadSkus(reset: false)),
          ],
        ],
      ],
    );

    if (!hasLoaded) return page;
    return _DataRefreshShell(
      updatedAt: updatedAt,
      onRefresh: () => loadSkus(reset: true, forceRefresh: true),
      child: page,
    );
  }
}
