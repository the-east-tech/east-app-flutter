import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/auth_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'knowledge_audit_screen.dart';

class KnowledgeScreen extends StatefulWidget {
  final UserRole role;
  final EastAppApi api;
  final Set<EastAppPermission> permissions;
  final List<KnowledgeItem> knowledgeItems;
  final List<StockTag> tags;
  final Future<KnowledgeItem> Function(KnowledgeItem item) onCreateSop;
  final Future<KnowledgeItem> Function(KnowledgeItem item) onUpdateSop;
  final Future<void> Function(Set<String> sopIds) onDeleteSops;

  const KnowledgeScreen({
    super.key,
    required this.role,
    required this.api,
    required this.permissions,
    required this.knowledgeItems,
    required this.tags,
    required this.onCreateSop,
    required this.onUpdateSop,
    required this.onDeleteSops,
  });

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final homeSearchController = TextEditingController();
  final listSearchController = TextEditingController();
  bool showSopList = false;
  bool showAudit = false;
  KnowledgeItem? selectedSop;
  bool selectedSopOpenedFromManagement = false;
  String? homeSelectedTagId;
  String? listSelectedTagId;
  bool deleteMode = false;
  final Set<String> selectedSopGroupIds = <String>{};

  bool get canManageSops => widget.role != UserRole.staff;
  bool get canViewAudit =>
      widget.permissions.contains(EastAppPermission.knowledgeAuditView);

  String tagNameFor(String tagId) {
    for (final tag in widget.tags) {
      if (tag.id == tagId) return tag.tag;
    }
    for (final item in widget.knowledgeItems) {
      if (item.tagId == tagId && item.tagName.isNotEmpty) return item.tagName;
    }
    return 'Unknown Tag';
  }

  List<_SopGroup> allSopGroups() {
    final grouped = <String, List<KnowledgeItem>>{};
    for (final item in widget.knowledgeItems.where((item) => item.type == 'SOP')) {
      final groupId = item.linkGroupId.isEmpty ? item.id : item.linkGroupId;
      grouped.putIfAbsent(groupId, () => <KnowledgeItem>[]).add(item);
    }
    final groups = grouped.entries
        .map((entry) => _SopGroup(entry.key, entry.value))
        .toList();
    groups.sort((left, right) => right.latestCreatedAt.compareTo(left.latestCreatedAt));
    return groups;
  }

  _SopGroup? sopGroupFor(String groupId) {
    for (final group in allSopGroups()) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  List<_SopGroup> filteredSops(
    TextEditingController controller,
    String? selectedTagId,
  ) {
    final query = controller.text.trim().toLowerCase();
    return allSopGroups().where((group) {
      if (selectedTagId != null &&
          !group.versions.any((item) => item.tagId == selectedTagId)) {
        return false;
      }
      if (query.isEmpty) return true;

      return group.versions.any((item) {
        final searchable = [
          item.title,
          item.description,
          item.expectedOutcome,
          item.language.label,
          tagNameFor(item.tagId),
        ].join(' ').toLowerCase();
        return searchable.contains(query);
      });
    }).toList();
  }

  @override
  void didUpdateWidget(covariant KnowledgeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (homeSelectedTagId != null &&
        !widget.tags.any((tag) => tag.id == homeSelectedTagId)) {
      homeSelectedTagId = null;
    }
    if (listSelectedTagId != null &&
        !widget.tags.any((tag) => tag.id == listSelectedTagId)) {
      listSelectedTagId = null;
    }
    final availableGroupIds = allSopGroups().map((group) => group.id).toSet();
    selectedSopGroupIds.removeWhere(
      (id) => !availableGroupIds.contains(id),
    );
    final selected = selectedSop;
    if (selected != null) {
      for (final item in widget.knowledgeItems) {
        if (item.id == selected.id) {
          selectedSop = item;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    homeSearchController.dispose();
    listSearchController.dispose();
    super.dispose();
  }

  Future<void> openCreateSop() async {
    await showSopEditorDialog(
      context,
      tags: widget.tags,
      knowledgeItems: widget.knowledgeItems,
      onSaved: (item) async {
        final saved = await widget.onCreateSop(item);
        if (!mounted) return saved;
        setState(() {
          listSelectedTagId = saved.tagId;
          listSearchController.clear();
        });
        showSuccessSnackBar(
          context,
          AppTextScope.of(context).t('SOP created. Staff can view it now.'),
        );
        return saved;
      },
    );
  }

  Future<void> openEditSop(KnowledgeItem item) async {
    await showSopEditorDialog(
      context,
      tags: widget.tags,
      knowledgeItems: widget.knowledgeItems,
      existingItem: item,
      onSaved: (updated) async {
        final saved = await widget.onUpdateSop(updated);
        if (!mounted) return saved;
        setState(() => selectedSop = saved);
        showSuccessSnackBar(
          context,
          AppTextScope.of(context).t('SOP updated.'),
        );
        return saved;
      },
    );
  }

  void enterDeleteMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      deleteMode = true;
      selectedSopGroupIds.clear();
    });
  }

  void cancelDeleteMode() {
    setState(() {
      deleteMode = false;
      selectedSopGroupIds.clear();
    });
  }

  void toggleSopSelection(String groupId) {
    setState(() {
      if (!selectedSopGroupIds.add(groupId)) {
        selectedSopGroupIds.remove(groupId);
      }
    });
  }

  void toggleAllVisibleSops(List<_SopGroup> visibleItems) {
    final visibleIds = visibleItems.map((group) => group.id).toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(selectedSopGroupIds.contains);
    setState(() {
      if (allVisibleSelected) {
        selectedSopGroupIds.removeAll(visibleIds);
      } else {
        selectedSopGroupIds.addAll(visibleIds);
      }
    });
  }

  Future<void> deleteSelectedSops() async {
    if (selectedSopGroupIds.isEmpty) return;
    final selectedGroups = allSopGroups()
        .where((group) => selectedSopGroupIds.contains(group.id))
        .toList();
    final sopIds = selectedGroups
        .expand((group) => group.versions)
        .map((item) => item.id)
        .toSet();
    final groupCount = selectedGroups.length;
    final videoCount = sopIds.length;
    final confirmed = await confirmDataChange(
      context,
      action: groupCount == 1
          ? 'Delete Selected SOP?'
          : 'Delete $groupCount SOPs?',
      details:
          'This permanently removes $groupCount SOP ${groupCount == 1 ? 'group' : 'groups'} and all $videoCount linked video ${videoCount == 1 ? 'version' : 'versions'} from EastApp. The original YouTube ${videoCount == 1 ? 'video is' : 'videos are'} not deleted.',
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.onDeleteSops(sopIds);
      if (!mounted) return;
      setState(() {
        deleteMode = false;
        selectedSopGroupIds.clear();
      });
      showSuccessSnackBar(
        context,
        AppTextScope.of(context).t(
          groupCount == 1 ? 'SOP deleted.' : 'SOPs deleted.',
        ),
      );
    } on EastAppApiException catch (_) {
      // The global API error dialog presents the failure; keep the selection
      // so the user can retry without selecting the SOPs again.
    }
  }

  void openSopList() {
    FocusScope.of(context).unfocus();
    setState(() => showSopList = true);
  }

  void closeSopList() {
    if (deleteMode) {
      cancelDeleteMode();
      return;
    }
    FocusScope.of(context).unfocus();
    listSearchController.clear();
    setState(() {
      showSopList = false;
      selectedSop = null;
      selectedSopOpenedFromManagement = false;
      listSelectedTagId = null;
      selectedSopGroupIds.clear();
    });
  }

  void openAudit() {
    FocusScope.of(context).unfocus();
    setState(() => showAudit = true);
  }

  void closeAudit() {
    FocusScope.of(context).unfocus();
    setState(() => showAudit = false);
  }

  void openSopDetail(
    KnowledgeItem item, {
    required bool openedFromManagement,
  }) {
    FocusScope.of(context).unfocus();
    setState(() {
      selectedSop = item;
      selectedSopOpenedFromManagement = openedFromManagement;
    });
  }

  void openReadOnlySopDetail(KnowledgeItem item) => openSopDetail(
        item,
        openedFromManagement: false,
      );

  void openManagementSopDetail(KnowledgeItem item) => openSopDetail(
        item,
        openedFromManagement: true,
      );

  void closeSopDetail() {
    setState(() {
      selectedSop = null;
      selectedSopOpenedFromManagement = false;
    });
  }

  Future<bool> handleBackNavigation() async {
    if (selectedSop != null) {
      closeSopDetail();
      return false;
    }
    if (deleteMode) {
      cancelDeleteMode();
      return false;
    }
    if (showSopList) {
      closeSopList();
      return false;
    }
    if (showAudit) {
      closeAudit();
      return false;
    }
    return true;
  }

  Widget buildKnowledgeHome(BuildContext context) {
    final text = AppTextScope.of(context);
    final visibleItems = filteredSops(
      homeSearchController,
      homeSelectedTagId,
    );
    final totalSops = allSopGroups().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PageTitle(
          title: text.t('Knowledge Pool'),
          subtitle: text.t('Access SOPs, recipes, and ingredients'),
        ),
        const SizedBox(height: 4),
        _KnowledgeSectionTitle(text.t('Knowledge')),
        _KnowledgeMenuGrid(
          children: [
            _KnowledgeMenuCard(
              title: text.t('Manage SOP'),
              subtitle: text.t('View SOP'),
              icon: Icons.description_outlined,
              badgeText: '$totalSops',
              onTap: openSopList,
            ),
            if (canViewAudit)
              _KnowledgeMenuCard(
                title: text.t('Audit'),
                subtitle: text.t('Playback effort'),
                icon: Icons.insights_rounded,
                onTap: openAudit,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          text.t('SOP'),
          style: const TextStyle(
            fontSize: AppTextSize.s22,
            fontWeight: FontWeight.w800,
            color: AppColours.textMain,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: homeSearchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: AppInputStyle.decoration(
            text.t('Search SOP...'),
          ).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: homeSearchController.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      homeSearchController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _TagSegmentedFilter(
          tags: widget.tags,
          selectedTagId: homeSelectedTagId,
          onChanged: (tagId) {
            FocusScope.of(context).unfocus();
            setState(() => homeSelectedTagId = tagId);
          },
        ),
        const SizedBox(height: 14),
        if (visibleItems.isEmpty)
          _KnowledgeEmptyState(text: text.t('No SOP found.'))
        else
          ...visibleItems.map(
            (group) => _SopGroupCard(
              group: group,
              tagName: tagNameFor(group.primary.tagId),
              showDescription: true,
              onVersionTap: openReadOnlySopDetail,
            ),
          ),
      ],
    );
  }

  Widget buildSopList(BuildContext context) {
    final text = AppTextScope.of(context);
    final visibleItems = filteredSops(
      listSearchController,
      listSelectedTagId,
    );
    final visibleIds = visibleItems.map((group) => group.id).toSet();
    final allVisibleSelected = visibleIds.isNotEmpty &&
        visibleIds.every(selectedSopGroupIds.contains);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: IconButton(
                onPressed: closeSopList,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: PageTitle(
                title: text.t('Manage SOP'),
                subtitle: deleteMode
                    ? '${selectedSopGroupIds.length} ${text.t('selected')}'
                    : text.t('Select SOP'),
              ),
            ),
          ],
        ),
        if (canManageSops) ...[
          if (deleteMode) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: cancelDeleteMode,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(text.t('Cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: visibleItems.isEmpty
                        ? null
                        : () => toggleAllVisibleSops(visibleItems),
                    icon: Icon(
                      allVisibleSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                    ),
                    label: Text(
                      text.t(allVisibleSelected ? 'Clear All' : 'Select All'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    selectedSopGroupIds.isEmpty ? null : deleteSelectedSops,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColours.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(
                  selectedSopGroupIds.isEmpty
                      ? text.t('Delete')
                      : '${text.t('Delete')} (${selectedSopGroupIds.length})',
                ),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: visibleItems.isEmpty ? null : enterDeleteMode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColours.red,
                      side: const BorderSide(color: AppColours.red),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(text.t('Delete')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    text: text.t('Create SOP'),
                    icon: Icons.add_rounded,
                    onPressed: openCreateSop,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: listSearchController,
          style: AppTextStyles.formValue,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: AppInputStyle.decoration(
            text.t('Search SOP...'),
          ).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: listSearchController.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      listSearchController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _TagSegmentedFilter(
          tags: widget.tags,
          selectedTagId: listSelectedTagId,
          onChanged: (tagId) {
            FocusScope.of(context).unfocus();
            setState(() => listSelectedTagId = tagId);
          },
        ),
        const SizedBox(height: 12),
        if (visibleItems.isEmpty)
          _KnowledgeEmptyState(text: text.t('No SOP found.'))
        else
          _SopGroupList(
            groups: visibleItems,
            tagNameFor: tagNameFor,
            selecting: deleteMode,
            selectedGroupIds: selectedSopGroupIds,
            onToggleSelection: toggleSopSelection,
            onVersionTap: openManagementSopDetail,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedSop;
    final selectedGroup = selected == null
        ? null
        : sopGroupFor(
            selected.linkGroupId.isEmpty ? selected.id : selected.linkGroupId,
          );
    final viewKey = selected != null
        ? 3
        : showAudit
            ? 2
            : showSopList
                ? 1
                : 0;
    return PopScope(
      canPop: selected == null && !showSopList && !showAudit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(handleBackNavigation());
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey<int>(viewKey),
          child: selected != null
              ? _SopDetailPage(
                  api: widget.api,
                  item: selected,
                  versions: selectedGroup?.versions ?? [selected],
                  tagNameFor: tagNameFor,
                  onBack: closeSopDetail,
                  onEdit:
                      canManageSops && selectedSopOpenedFromManagement
                          ? openEditSop
                          : null,
                )
              : showAudit
                  ? KnowledgeAuditScreen(api: widget.api, onBack: closeAudit)
                  : showSopList
                      ? buildSopList(context)
                      : buildKnowledgeHome(context),
        ),
      ),
    );
  }
}

class _SopDetailPage extends StatefulWidget {
  final EastAppApi api;
  final KnowledgeItem item;
  final List<KnowledgeItem> versions;
  final String Function(String tagId) tagNameFor;
  final VoidCallback onBack;
  final ValueChanged<KnowledgeItem>? onEdit;

  const _SopDetailPage({
    required this.api,
    required this.item,
    required this.versions,
    required this.tagNameFor,
    required this.onBack,
    this.onEdit,
  });

  @override
  State<_SopDetailPage> createState() => _SopDetailPageState();
}

class _SopDetailPageState extends State<_SopDetailPage>
    with WidgetsBindingObserver {
  late KnowledgeItem selectedItem;
  late YoutubePlayerController controller;
  late _PlaybackTrackingSession trackingSession;
  StreamSubscription<YoutubePlayerValue>? playerSubscription;
  Timer? trackingTimer;
  bool playerIsPlaying = false;
  bool appIsForeground = true;

  YoutubePlayerController buildController(KnowledgeItem item) {
    return YoutubePlayerController.fromVideoId(
      videoId: item.youtubeVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    selectedItem = widget.item;
    controller = buildController(selectedItem);
    trackingSession = _PlaybackTrackingSession(selectedItem.id);
    WidgetsBinding.instance.addObserver(this);
    playerSubscription = controller.stream.listen(handlePlayerValue);
    trackingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => capturePlayingSecond(),
    );
  }

  @override
  void didUpdateWidget(covariant _SopDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    KnowledgeItem nextItem = widget.item;
    for (final version in widget.versions) {
      if (version.id == selectedItem.id) {
        nextItem = version;
        break;
      }
    }
    if (selectedItem.id != nextItem.id) {
      unawaited(flushSession(trackingSession, force: true));
      trackingSession = _PlaybackTrackingSession(nextItem.id);
      playerIsPlaying = false;
    }
    if (selectedItem.youtubeVideoId != nextItem.youtubeVideoId) {
      unawaited(
        controller.cueVideoById(videoId: nextItem.youtubeVideoId),
      );
    }
    selectedItem = nextItem;
  }

  void selectVersion(KnowledgeItem item) {
    if (item.id == selectedItem.id) return;
    unawaited(flushSession(trackingSession, force: true));
    trackingSession = _PlaybackTrackingSession(item.id);
    playerIsPlaying = false;
    setState(() {
      selectedItem = item;
    });
    unawaited(
      controller.cueVideoById(videoId: item.youtubeVideoId),
    );
  }

  void handlePlayerValue(YoutubePlayerValue value) {
    final wasPlaying = playerIsPlaying;
    playerIsPlaying = value.playerState == PlayerState.playing;
    if (!wasPlaying && playerIsPlaying) {
      unawaited(flushSession(trackingSession));
    } else if (wasPlaying && !playerIsPlaying) {
      unawaited(flushSession(trackingSession, force: true));
    }
  }

  void capturePlayingSecond() {
    if (!playerIsPlaying || !appIsForeground) return;
    trackingSession.playedSeconds += 1;
    if (trackingSession.playedSeconds - trackingSession.lastSentSeconds >= 10) {
      unawaited(flushSession(trackingSession));
    }
  }

  Future<void> flushSession(
    _PlaybackTrackingSession session, {
    bool force = false,
  }) async {
    if (session.flushInFlight) {
      session.flushAgain = session.flushAgain || force;
      return;
    }
    if (!force &&
        session.nextRetryAt != null &&
        DateTime.now().isBefore(session.nextRetryAt!)) {
      return;
    }
    final seconds = session.playedSeconds;
    if (session.acknowledged && seconds <= session.lastSentSeconds) return;

    session.flushInFlight = true;
    try {
      await widget.api.recordSopWatchTime(
        sopId: session.sopId,
        sessionId: session.id,
        playedSeconds: seconds,
      );
      session.acknowledged = true;
      if (seconds > session.lastSentSeconds) {
        session.lastSentSeconds = seconds;
      }
      session.nextRetryAt = null;
    } on EastAppApiException catch (_) {
      session.nextRetryAt = DateTime.now().add(const Duration(seconds: 10));
    } finally {
      session.flushInFlight = false;
      final shouldFlushAgain = session.flushAgain ||
          session.playedSeconds - session.lastSentSeconds >= 10;
      session.flushAgain = false;
      if (shouldFlushAgain && session.nextRetryAt == null) {
        unawaited(flushSession(session));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = appIsForeground;
    appIsForeground = state == AppLifecycleState.resumed;
    if (wasForeground && !appIsForeground) {
      unawaited(flushSession(trackingSession, force: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    trackingTimer?.cancel();
    unawaited(playerSubscription?.cancel() ?? Future<void>.value());
    unawaited(flushSession(trackingSession, force: true));
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final versions = [...widget.versions]
      ..sort((left, right) => left.language.index.compareTo(right.language.index));
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: PageTitle(
                title: text.content(selectedItem.title),
                subtitle: '${text.t('SOP Details')} · ${text.t(selectedItem.language.label)}',
              ),
            ),
          ],
        ),
        if (widget.onEdit != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => widget.onEdit!(selectedItem),
              icon: const Icon(Icons.edit_outlined),
              label: Text(text.t('Edit')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (versions.length > 1) ...[
          Text(text.t('Select Video Language'), style: AppTextStyles.formLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var index = 0; index < versions.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(
                  child: _VideoLanguageCard(
                    item: versions[index],
                    selected: versions[index].id == selectedItem.id,
                    onTap: () => selectVersion(versions[index]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        WhiteCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: YoutubePlayer(
              controller: controller,
              aspectRatio: 16 / 9,
            ),
          ),
        ),
        const SizedBox(height: 10),
        WhiteCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SmallStatusPill(
                    text: text.t('SOP'),
                    icon: Icons.description_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                  SmallStatusPill(
                    text: text.content(
                      text.t(widget.tagNameFor(selectedItem.tagId)),
                    ),
                    icon: Icons.sell_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                  SmallStatusPill(
                    text: text.t('Video'),
                    icon: Icons.videocam_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                  SmallStatusPill(
                    text: text.t(selectedItem.language.label),
                    icon: Icons.language_rounded,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                text.t('Expected Outcome'),
                style: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text.content(selectedItem.expectedOutcome),
                style: AppTextStyles.formHint.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                text.t('Description'),
                style: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text.content(selectedItem.description),
                style: AppTextStyles.formHint.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                text.t('YouTube URL'),
                style: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                selectedItem.youtubeUrl,
                style: AppTextStyles.formHint.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackTrackingSession {
  final String id = const Uuid().v4();
  final String sopId;
  int playedSeconds = 0;
  int lastSentSeconds = 0;
  bool acknowledged = false;
  bool flushInFlight = false;
  bool flushAgain = false;
  DateTime? nextRetryAt;

  _PlaybackTrackingSession(this.sopId);
}

class _KnowledgeSectionTitle extends StatelessWidget {
  final String title;

  const _KnowledgeSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 7),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: AppTextSize.s15,
          fontWeight: FontWeight.w700,
          color: AppColours.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _KnowledgeMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const _KnowledgeMenuGrid({required this.children});

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
              .map(
                (child) => SizedBox(
                  width: cardWidth,
                  height: 100,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KnowledgeMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badgeText;
  final VoidCallback onTap;

  const _KnowledgeMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeText,
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
                      color: AppColours.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColours.blue, size: 22),
                  ),
                  const Spacer(),
                  if (badgeText != null)
                    SmallStatusPill(
                      text: badgeText!,
                      textColour: AppColours.green,
                      backgroundColour: AppColours.greenSoft,
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColours.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w600,
                  color: AppColours.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagSegmentedFilter extends StatelessWidget {
  final List<StockTag> tags;
  final String? selectedTagId;
  final ValueChanged<String?> onChanged;

  const _TagSegmentedFilter({
    required this.tags,
    required this.selectedTagId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E9ED),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _TagSegment(
              label: text.t('All'),
              selected: selectedTagId == null,
              onTap: () => onChanged(null),
            ),
            for (final tag in tags)
              _TagSegment(
                label: text.content(tag.tag),
                selected: selectedTagId == tag.id,
                onTap: () => onChanged(tag.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: AppTextSize.s14,
            fontWeight: FontWeight.w700,
            color: AppColours.textMain,
          ),
        ),
      ),
    );
  }
}

class _KnowledgeEmptyState extends StatelessWidget {
  final String text;

  const _KnowledgeEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 36,
              color: AppColours.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: AppTextStyles.formValue.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SopGroup {
  final String id;
  final List<KnowledgeItem> versions;

  _SopGroup(this.id, List<KnowledgeItem> items)
      : versions = [...items]
          ..sort(
            (left, right) => left.language.index.compareTo(right.language.index),
          );

  KnowledgeItem get primary {
    for (final item in versions) {
      if (item.language == KnowledgeVideoLanguage.english) return item;
    }
    return versions.first;
  }

  DateTime get latestCreatedAt {
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final item in versions) {
      final createdAt = item.createdAt;
      if (createdAt != null && createdAt.isAfter(latest)) latest = createdAt;
    }
    return latest;
  }
}

class _SopGroupList extends StatelessWidget {
  final List<_SopGroup> groups;
  final String Function(String tagId) tagNameFor;
  final bool selecting;
  final Set<String> selectedGroupIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<KnowledgeItem> onVersionTap;

  const _SopGroupList({
    required this.groups,
    required this.tagNameFor,
    required this.selecting,
    required this.selectedGroupIds,
    required this.onToggleSelection,
    required this.onVersionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final group in groups)
          _CompactSopGroupCard(
            group: group,
            tagName: tagNameFor(group.primary.tagId),
            selecting: selecting,
            selected: selectedGroupIds.contains(group.id),
            onToggleSelection: () => onToggleSelection(group.id),
            onVersionTap: onVersionTap,
          ),
      ],
    );
  }
}

class _CompactSopGroupCard extends StatelessWidget {
  final _SopGroup group;
  final String tagName;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelection;
  final ValueChanged<KnowledgeItem> onVersionTap;

  const _CompactSopGroupCard({
    required this.group,
    required this.tagName,
    required this.selecting,
    required this.selected,
    required this.onToggleSelection,
    required this.onVersionTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final primary = group.primary;
    final summary = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColours.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.videocam_outlined,
            color: AppColours.blue,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text.content(primary.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${text.content(text.t(tagName))} · ${group.versions.length} ${group.versions.length == 1 ? text.t('Video Version') : text.t('Video Versions')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s12,
                  fontWeight: FontWeight.w600,
                  color: AppColours.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          if (selecting) ...[
            Checkbox(
              value: selected,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => onToggleSelection(),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: selecting
                ? Pressable(
                    onTap: onToggleSelection,
                    borderRadius: BorderRadius.circular(10),
                    child: summary,
                  )
                : summary,
          ),
          if (!selecting) ...[
            const SizedBox(width: 8),
            for (var index = 0; index < group.versions.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              _CompactSopVersionButton(
                item: group.versions[index],
                onTap: () => onVersionTap(group.versions[index]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompactSopVersionButton extends StatelessWidget {
  final KnowledgeItem item;
  final VoidCallback onTap;

  const _CompactSopVersionButton({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final languageCode = item.language == KnowledgeVideoLanguage.english
        ? 'EN'
        : 'MY';
    return Tooltip(
      message: '${text.t('Edit')} ${text.t(item.language.label)}',
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFD5E2FF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 15,
                color: AppColours.blue,
              ),
              const SizedBox(width: 3),
              Text(
                languageCode,
                style: const TextStyle(
                  fontSize: AppTextSize.s12,
                  fontWeight: FontWeight.w800,
                  color: AppColours.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SopGroupCard extends StatelessWidget {
  final _SopGroup group;
  final String tagName;
  final bool selecting;
  final bool selected;
  final bool showDescription;
  final VoidCallback? onToggleSelection;
  final ValueChanged<KnowledgeItem> onVersionTap;

  const _SopGroupCard({
    required this.group,
    required this.tagName,
    this.selecting = false,
    this.selected = false,
    this.showDescription = false,
    this.onToggleSelection,
    required this.onVersionTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final primary = group.primary;
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selecting) ...[
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelection?.call(),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColours.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videocam_outlined,
                  color: AppColours.blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.content(primary.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                        color: AppColours.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${text.content(text.t(tagName))} · ${group.versions.length} ${group.versions.length == 1 ? text.t('Video Version') : text.t('Video Versions')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        fontWeight: FontWeight.w600,
                        color: AppColours.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showDescription) ...[
            const SizedBox(height: 8),
            Text(
              text.content(primary.description),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.formHint.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < group.versions.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(
                  child: _VideoLanguageCard(
                    item: group.versions[index],
                    selected: selecting && selected,
                    onTap: selecting
                        ? () => onToggleSelection?.call()
                        : () => onVersionTap(group.versions[index]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoLanguageCard extends StatelessWidget {
  final KnowledgeItem item;
  final bool selected;
  final VoidCallback onTap;

  const _VideoLanguageCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FF) : AppColours.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColours.blue : AppColours.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.play_circle_outline,
              color: AppColours.blue,
              size: 20,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text.t(item.language.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s14,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSopEditorDialog(
  BuildContext context, {
  required List<StockTag> tags,
  required List<KnowledgeItem> knowledgeItems,
  required Future<KnowledgeItem> Function(KnowledgeItem item) onSaved,
  KnowledgeItem? existingItem,
}) async {
  final text = AppTextScope.of(context);
  final youtubeController = TextEditingController(
    text: existingItem?.youtubeUrl ?? '',
  );
  final titleController = TextEditingController(
    text: existingItem?.title ?? '',
  );
  final descriptionController = TextEditingController(
    text: existingItem?.description ?? '',
  );
  final outcomeController = TextEditingController(
    text: existingItem?.expectedOutcome ?? '',
  );
  String? selectedTagId = existingItem?.tagId;
  KnowledgeVideoLanguage selectedLanguage =
      existingItem?.language ?? KnowledgeVideoLanguage.english;
  String? selectedLinkedSopId;
  final editing = existingItem != null;
  final existingGroupId = existingItem == null
      ? null
      : existingItem.linkGroupId.isEmpty
          ? existingItem.id
          : existingItem.linkGroupId;
  final existingGroupSize = existingGroupId == null
      ? 0
      : knowledgeItems
          .where(
            (item) =>
                (item.linkGroupId.isEmpty ? item.id : item.linkGroupId) ==
                existingGroupId,
          )
          .length;
  final groupedCandidates = <String, List<KnowledgeItem>>{};
  for (final item in knowledgeItems.where((item) => item.type == 'SOP')) {
    final groupId = item.linkGroupId.isEmpty ? item.id : item.linkGroupId;
    groupedCandidates.putIfAbsent(groupId, () => <KnowledgeItem>[]).add(item);
  }
  final linkableVideos = groupedCandidates.values
      .where((versions) => versions.length < 2)
      .map((versions) => versions.first)
      .toList();
  bool showValidation = false;
  bool submitting = false;
  String? submitError;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final youtubeUrl = youtubeController.text.trim();
          final title = titleController.text.trim();
          final outcome = outcomeController.text.trim();
          final description = descriptionController.text.trim();
          final videoId = _youtubeVideoIdFromUrl(youtubeUrl);
          KnowledgeItem? linkedSop;
          for (final item in linkableVideos) {
            if (item.id == selectedLinkedSopId) {
              linkedSop = item;
              break;
            }
          }
          final sharedFieldsLocked = linkedSop != null;
          final duplicateLinkedVideo = linkedSop != null &&
              videoId != null &&
              linkedSop.youtubeVideoId == videoId;
          final youtubeError = !showValidation
              ? null
              : videoId == null
                  ? text.t('Enter a valid YouTube video URL.')
                  : duplicateLinkedVideo
                      ? text.t(
                          'English and Myanmar must use different YouTube videos.',
                        )
                      : null;
          final availableLinkedVideos = linkableVideos;

          Future<void> submit() async {
            setDialogState(() {
              showValidation = true;
              submitError = null;
            });
            if (videoId == null ||
                duplicateLinkedVideo ||
                selectedTagId == null ||
                title.isEmpty ||
                outcome.isEmpty ||
                description.isEmpty) {
              return;
            }

            final confirmed = await confirmDataChange(
              dialogContext,
              action: text.t(editing ? 'Update SOP?' : 'Create SOP?'),
              details: editing
                  ? text.t('This will save the edited SOP information.')
                  : linkedSop == null
                      ? text.t(
                          'This will create a new SOP for the selected Stock tag.',
                        )
                      : text.t(
                          'This will create and link the ${selectedLanguage.label} video with ${linkedSop.language.label}. Both versions will be deleted together.',
                        ),
            );
            if (!confirmed || !dialogContext.mounted) return;

            setDialogState(() => submitting = true);
            try {
              await onSaved(
                KnowledgeItem(
                  id: existingItem?.id ?? '',
                  youtubeUrl: youtubeUrl,
                  youtubeVideoId: videoId,
                  title: title,
                  description: description,
                  type: 'SOP',
                  tagId: selectedTagId!,
                  tagName: existingItem?.tagName ?? '',
                  mediaType: 'video',
                  expectedOutcome: outcome,
                  language: selectedLanguage,
                  linkGroupId: existingItem?.linkGroupId ?? '',
                  linkedSopId: selectedLinkedSopId,
                  createdBy: existingItem?.createdBy ?? '',
                  createdAt: existingItem?.createdAt,
                ),
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } on EastAppApiException catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                submitting = false;
                submitError = error.message;
              });
            }
          }

          return PopScope(
            canPop: !submitting,
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text.t(editing ? 'Edit SOP' : 'Create New SOP'),
                              style: const TextStyle(
                                fontSize: AppTextSize.s22,
                                fontWeight: FontWeight.w800,
                                color: AppColours.textMain,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _DialogInput(
                        controller: youtubeController,
                        label: text.t('YouTube URL'),
                        hint: 'https://www.youtube.com/watch?v=...',
                        keyboardType: TextInputType.url,
                        errorText: youtubeError,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(text.t('Language'), style: AppTextStyles.formLabel),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<KnowledgeVideoLanguage>(
                        key: ValueKey(
                          'language:${selectedLanguage.apiValue}:$selectedLinkedSopId',
                        ),
                        initialValue: selectedLanguage,
                        isExpanded: true,
                        style: AppTextStyles.formValue,
                        decoration: AppInputStyle.decoration(
                          text.t('Select Language'),
                        ),
                        items: KnowledgeVideoLanguage.values
                            .map(
                              (language) =>
                                  DropdownMenuItem<KnowledgeVideoLanguage>(
                                value: language,
                                child: Text(text.t(language.label)),
                              ),
                            )
                            .toList(),
                        onChanged: submitting ||
                                sharedFieldsLocked ||
                                (editing && existingGroupSize > 1)
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedLanguage = value;
                                  if (linkedSop?.language == value) {
                                    selectedLinkedSopId = null;
                                  }
                                  submitError = null;
                                });
                              },
                      ),
                      if (editing && existingGroupSize > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          text.t(
                            'Language is fixed while two video versions are linked.',
                          ),
                          style: AppTextStyles.formHint,
                        ),
                      ],
                      if (!editing) ...[
                        const SizedBox(height: 16),
                        Text(
                          text.t('Linked Video'),
                          style: AppTextStyles.formLabel,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'linked:${selectedLinkedSopId ?? ''}:${selectedLanguage.apiValue}',
                          ),
                          initialValue: selectedLinkedSopId ?? '',
                          isExpanded: true,
                          style: AppTextStyles.formValue,
                          decoration: AppInputStyle.decoration(
                            text.t('Select a previously created video'),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(text.t('No linked video')),
                            ),
                            ...availableLinkedVideos.map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(
                                  '${text.content(item.title)} · ${text.t(item.language.label)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedLinkedSopId =
                                        value == null || value.isEmpty
                                            ? null
                                            : value;
                                    if (selectedLinkedSopId != null) {
                                      final target = linkableVideos.firstWhere(
                                        (item) => item.id == selectedLinkedSopId,
                                      );
                                      selectedLanguage = target.language ==
                                              KnowledgeVideoLanguage.english
                                          ? KnowledgeVideoLanguage.myanmar
                                          : KnowledgeVideoLanguage.english;
                                      selectedTagId = target.tagId;
                                      titleController.text = target.title;
                                      outcomeController.text =
                                          target.expectedOutcome;
                                      descriptionController.text =
                                          target.description;
                                    }
                                    submitError = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          text.t(
                            'Maximum two linked videos. Linked versions are deleted together.',
                          ),
                          style: AppTextStyles.formHint,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(text.t('Tag'), style: AppTextStyles.formLabel),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'tag:$selectedTagId:${selectedLinkedSopId ?? ''}',
                        ),
                        initialValue: selectedTagId,
                        isExpanded: true,
                        style: AppTextStyles.formValue,
                        decoration: AppInputStyle.decoration(
                          text.t('Select Tag'),
                        ).copyWith(
                          fillColor: sharedFieldsLocked
                              ? AppColours.border
                              : AppColours.mutedBox,
                          errorText: showValidation && selectedTagId == null
                              ? text.t('Tag is required')
                              : null,
                        ),
                        items: tags
                            .map(
                              (tag) => DropdownMenuItem<String>(
                                value: tag.id,
                                child: Text(
                                  tag.tag,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: submitting ||
                                tags.isEmpty ||
                                selectedLinkedSopId != null
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedTagId = value;
                                  submitError = null;
                                });
                              },
                      ),
                      if (tags.isEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          text.t('Create a Tag in Stock first.'),
                          style: AppTextStyles.formHint.copyWith(
                            color: AppColours.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _DialogInput(
                        controller: titleController,
                        label: text.t('Title'),
                        hint: text.t('Example: Belly Pork Preparation'),
                        enabled: !sharedFieldsLocked,
                        errorText: showValidation && title.isEmpty
                            ? text.t('Title is required.')
                            : null,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _DialogInput(
                        controller: outcomeController,
                        label: text.t('Expected Outcome'),
                        hint: text.t(
                          'What should staff achieve after following this?',
                        ),
                        maxLines: 2,
                        enabled: !sharedFieldsLocked,
                        errorText: showValidation && outcome.isEmpty
                            ? text.t('Expected Outcome is required.')
                            : null,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _DialogInput(
                        controller: descriptionController,
                        label: text.t('Description'),
                        hint: text.t('Describe the SOP content'),
                        maxLines: 3,
                        enabled: !sharedFieldsLocked,
                        errorText: showValidation && description.isEmpty
                            ? text.t('Description is required.')
                            : null,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          submitError!,
                          style: AppTextStyles.formHint.copyWith(
                            color: AppColours.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      PrimaryButton(
                        text: submitting
                            ? text.t('Processing... Please Wait!')
                            : text.t(editing ? 'Save' : 'Create SOP'),
                        icon: submitting
                            ? Icons.hourglass_top_rounded
                            : editing
                                ? Icons.save_outlined
                                : Icons.add_rounded,
                        onPressed: submitting || tags.isEmpty ? null : submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  youtubeController.dispose();
  titleController.dispose();
  descriptionController.dispose();
  outcomeController.dispose();
}

String? _youtubeVideoIdFromUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  if (host.startsWith('m.')) host = host.substring(2);

  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    if (uri.path == '/watch') {
      candidate = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        const {'shorts', 'embed', 'live'}.contains(uri.pathSegments.first)) {
      candidate = uri.pathSegments[1];
    }
  }

  return candidate != null &&
          RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)
      ? candidate
      : null;
}

class _DialogInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const _DialogInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.formLabel),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppTextStyles.formValue.copyWith(
            color: enabled ? AppColours.textMain : AppColours.textMuted,
          ),
          decoration: AppInputStyle.decoration(hint).copyWith(
            fillColor: enabled ? AppColours.mutedBox : AppColours.border,
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}
