import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class KnowledgeScreen extends StatefulWidget {
  final UserRole role;
  final List<KnowledgeItem> knowledgeItems;
  final List<StockTag> tags;
  final Future<KnowledgeItem> Function(KnowledgeItem item) onCreateSop;

  const KnowledgeScreen({
    super.key,
    required this.role,
    required this.knowledgeItems,
    required this.tags,
    required this.onCreateSop,
  });

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final homeSearchController = TextEditingController();
  final listSearchController = TextEditingController();
  bool showSopList = false;
  KnowledgeItem? selectedSop;
  String? homeSelectedTagId;
  String? listSelectedTagId;

  bool get canCreateSop => widget.role == UserRole.head;

  String tagNameFor(String tagId) {
    for (final tag in widget.tags) {
      if (tag.id == tagId) return tag.tag;
    }
    for (final item in widget.knowledgeItems) {
      if (item.tagId == tagId && item.tagName.isNotEmpty) return item.tagName;
    }
    return 'Unknown Tag';
  }

  List<KnowledgeItem> filteredSops(
    TextEditingController controller,
    String? selectedTagId,
  ) {
    final query = controller.text.trim().toLowerCase();
    return widget.knowledgeItems.where((item) {
      if (item.type != 'SOP') return false;
      if (selectedTagId != null && item.tagId != selectedTagId) return false;
      if (query.isEmpty) return true;

      final searchable = [
        item.title,
        item.description,
        item.expectedOutcome,
        tagNameFor(item.tagId),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
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
    await showCreateSopDialog(
      context,
      tags: widget.tags,
      onCreated: (item) async {
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

  void openSopList() {
    FocusScope.of(context).unfocus();
    setState(() => showSopList = true);
  }

  void closeSopList() {
    FocusScope.of(context).unfocus();
    listSearchController.clear();
    setState(() {
      showSopList = false;
      selectedSop = null;
      listSelectedTagId = null;
    });
  }

  void openSopDetail(KnowledgeItem item) {
    FocusScope.of(context).unfocus();
    setState(() => selectedSop = item);
  }

  void closeSopDetail() {
    setState(() => selectedSop = null);
  }

  Future<bool> handleBackNavigation() async {
    if (selectedSop != null) {
      closeSopDetail();
      return false;
    }
    if (showSopList) {
      closeSopList();
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
    final totalSops = widget.knowledgeItems
        .where((item) => item.type == 'SOP')
        .length;

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
              title: 'SOP',
              subtitle: text.t('View SOP'),
              icon: Icons.description_outlined,
              badgeText: '$totalSops',
              onTap: openSopList,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'SOP',
          style: TextStyle(
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
            (item) => _KnowledgeCard(
              item: item,
              tagName: tagNameFor(item.tagId),
              onTap: () => openSopDetail(item),
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
                title: 'SOP',
                subtitle: text.t('Select SOP'),
              ),
            ),
            if (canCreateSop)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: 150,
                  child: PrimaryButton(
                    text: text.t('Create SOP'),
                    icon: Icons.add_rounded,
                    onPressed: openCreateSop,
                  ),
                ),
              ),
          ],
        ),
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
          _CompactSopList(
            items: visibleItems,
            tagNameFor: tagNameFor,
            onTap: openSopDetail,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedSop;
    final viewKey = selected != null ? 2 : showSopList ? 1 : 0;
    return WillPopScope(
      onWillPop: handleBackNavigation,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey<int>(viewKey),
          child: selected != null
              ? _SopDetailPage(
                  item: selected,
                  tagName: tagNameFor(selected.tagId),
                  onBack: closeSopDetail,
                )
              : showSopList
                  ? buildSopList(context)
                  : buildKnowledgeHome(context),
        ),
      ),
    );
  }
}

class _SopDetailPage extends StatefulWidget {
  final KnowledgeItem item;
  final String tagName;
  final VoidCallback onBack;

  const _SopDetailPage({
    required this.item,
    required this.tagName,
    required this.onBack,
  });

  @override
  State<_SopDetailPage> createState() => _SopDetailPageState();
}

class _SopDetailPageState extends State<_SopDetailPage> {
  late final YoutubePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController.fromVideoId(
      videoId: widget.item.youtubeVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                title: widget.item.title,
                subtitle: 'SOP Details',
              ),
            ),
          ],
        ),
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
                    text: 'SOP',
                    icon: Icons.description_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                  SmallStatusPill(
                    text: widget.tagName,
                    icon: Icons.sell_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                  const SmallStatusPill(
                    text: 'Video',
                    icon: Icons.videocam_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Expected Outcome',
                style: TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.expectedOutcome,
                style: AppTextStyles.formHint.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.description,
                style: AppTextStyles.formHint.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'YouTube URL',
                style: TextStyle(
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                widget.item.youtubeUrl,
                style: AppTextStyles.formHint.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
                label: tag.tag,
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

class _CompactSopList extends StatelessWidget {
  final List<KnowledgeItem> items;
  final String Function(String tagId) tagNameFor;
  final ValueChanged<KnowledgeItem> onTap;

  const _CompactSopList({
    required this.items,
    required this.tagNameFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _CompactSopRow(
              item: items[index],
              tagName: tagNameFor(items[index].tagId),
              onTap: () => onTap(items[index]),
            ),
            if (index != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _CompactSopRow extends StatelessWidget {
  final KnowledgeItem item;
  final String tagName;
  final VoidCallback onTap;

  const _CompactSopRow({
    required this.item,
    required this.tagName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = item.mediaType == 'video';
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColours.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.image_outlined,
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
                    item.title,
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
                    '$tagName · ${isVideo ? 'Video' : 'Picture'}',
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
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  final KnowledgeItem item;
  final String tagName;
  final VoidCallback onTap;

  const _KnowledgeCard({
    required this.item,
    required this.tagName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        fontWeight: FontWeight.w700,
                        color: AppColours.textMain,
                      ),
                    ),
                  ),
                  SmallStatusPill(
                    text: item.type,
                    icon: Icons.description_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.description,
                style: AppTextStyles.formHint.copyWith(height: 1.35),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SmallStatusPill(
                    text: tagName,
                    icon: Icons.sell_outlined,
                    textColour: AppColours.textMain,
                    backgroundColour: AppColours.background,
                  ),
                  if (item.mediaType != null)
                    SmallStatusPill(
                      text: item.mediaType == 'video' ? 'Video' : 'Picture',
                      icon: item.mediaType == 'video'
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      textColour: AppColours.textMain,
                      backgroundColour: AppColours.background,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showCreateSopDialog(
  BuildContext context, {
  required List<StockTag> tags,
  required Future<KnowledgeItem> Function(KnowledgeItem item) onCreated,
}) async {
  final text = AppTextScope.of(context);
  final youtubeController = TextEditingController();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final outcomeController = TextEditingController();
  String? selectedTagId;
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

          Future<void> submit() async {
            setDialogState(() {
              showValidation = true;
              submitError = null;
            });
            if (videoId == null ||
                selectedTagId == null ||
                title.isEmpty ||
                outcome.isEmpty ||
                description.isEmpty) {
              return;
            }

            final confirmed = await confirmDataChange(
              dialogContext,
              action: 'Create SOP?',
              details:
                  'This will create a new SOP for the selected Stock tag.',
            );
            if (!confirmed || !dialogContext.mounted) return;

            setDialogState(() => submitting = true);
            try {
              await onCreated(
                KnowledgeItem(
                  youtubeUrl: youtubeUrl,
                  youtubeVideoId: videoId,
                  title: title,
                  description: description,
                  type: 'SOP',
                  tagId: selectedTagId!,
                  mediaType: 'video',
                  expectedOutcome: outcome,
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
                              text.t('Create New SOP'),
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
                        label: 'YouTube URL',
                        hint: 'https://www.youtube.com/watch?v=...',
                        keyboardType: TextInputType.url,
                        errorText: showValidation && videoId == null
                            ? 'Enter a valid YouTube video URL.'
                            : null,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(text.t('Tag'), style: AppTextStyles.formLabel),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedTagId,
                        isExpanded: true,
                        style: AppTextStyles.formValue,
                        decoration: AppInputStyle.decoration(
                          text.t('Select Tag'),
                        ).copyWith(
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
                        onChanged: submitting || tags.isEmpty
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
                        hint: 'Example: Belly Pork Preparation',
                        errorText: showValidation && title.isEmpty
                            ? 'Title is required.'
                            : null,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _DialogInput(
                        controller: outcomeController,
                        label: 'Expected Outcome',
                        hint: 'What should staff achieve after following this?',
                        maxLines: 2,
                        errorText: showValidation && outcome.isEmpty
                            ? 'Expected Outcome is required.'
                            : null,
                        onChanged: (_) => setDialogState(() {
                          submitError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _DialogInput(
                        controller: descriptionController,
                        label: text.t('Description'),
                        hint: 'Describe the SOP content',
                        maxLines: 3,
                        errorText: showValidation && description.isEmpty
                            ? 'Description is required.'
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
                            : text.t('Create SOP'),
                        icon: submitting
                            ? Icons.hourglass_top_rounded
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
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const _DialogInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
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
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppTextStyles.formValue,
          decoration: AppInputStyle.decoration(hint).copyWith(
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}
