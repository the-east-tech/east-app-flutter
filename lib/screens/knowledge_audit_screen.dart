import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/knowledge_audit_models.dart';
import '../models/people_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

enum _KnowledgeAuditMode { employee, video }

class KnowledgeAuditScreen extends StatefulWidget {
  final EastAppApi api;
  final VoidCallback onBack;

  const KnowledgeAuditScreen({
    super.key,
    required this.api,
    required this.onBack,
  });

  @override
  State<KnowledgeAuditScreen> createState() => _KnowledgeAuditScreenState();
}

class _KnowledgeAuditScreenState extends State<KnowledgeAuditScreen> {
  final searchController = TextEditingController();
  _KnowledgeAuditMode mode = _KnowledgeAuditMode.employee;
  List<EastAppUser> users = const [];
  bool searchRequested = false;
  bool searching = false;
  bool loadingEmployee = false;
  bool loadingImpact = false;
  EastAppUser? selectedUser;
  EmployeeSopAudit? employeeAudit;
  SopImpactAudit? impactAudit;
  String? inlineError;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchUsers() async {
    if (searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      searching = true;
      searchRequested = true;
      inlineError = null;
    });
    try {
      final page = await widget.api.listUsers(
        search: searchController.text,
        active: true,
        size: 30,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => users = page.content);
    } on EastAppApiException catch (_) {
      if (!mounted) return;
      setState(() => inlineError = 'Unable to load employees. Try again.');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> loadEmployee(EastAppUser user) async {
    if (loadingEmployee) return;
    setState(() {
      selectedUser = user;
      employeeAudit = null;
      loadingEmployee = true;
      inlineError = null;
    });
    try {
      final loaded = await widget.api.knowledgeAuditForUser(user.id);
      if (!mounted || selectedUser?.id != user.id) return;
      setState(() => employeeAudit = loaded);
    } on EastAppApiException catch (_) {
      if (!mounted) return;
      setState(() => inlineError = 'Unable to load employee learning time.');
    } finally {
      if (mounted) setState(() => loadingEmployee = false);
    }
  }

  Future<void> loadImpact() async {
    if (loadingImpact) return;
    setState(() {
      loadingImpact = true;
      inlineError = null;
    });
    try {
      final loaded = await widget.api.knowledgeSopImpactAudit();
      if (!mounted) return;
      setState(() => impactAudit = loaded);
    } on EastAppApiException catch (_) {
      if (!mounted) return;
      setState(
        () => inlineError = 'Unable to load video analytics. Try again.',
      );
    } finally {
      if (mounted) setState(() => loadingImpact = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
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
                title: text.t('Knowledge Audit'),
                subtitle: text.t('Measure recorded SOP playback time'),
              ),
            ),
          ],
        ),
        _AuditModeSwitch(
          value: mode,
          onChanged: (value) {
            FocusScope.of(context).unfocus();
            setState(() {
              mode = value;
              inlineError = null;
            });
          },
        ),
        const SizedBox(height: 14),
        if (inlineError != null) ...[
          _InlineAuditMessage(
            icon: Icons.error_outline_rounded,
            message: text.t(inlineError!),
            colour: AppColours.red,
          ),
          const SizedBox(height: 12),
        ],
        if (mode == _KnowledgeAuditMode.employee)
          ...buildEmployeeAudit(context)
        else
          ...buildVideoImpact(context),
      ],
    );
  }

  List<Widget> buildEmployeeAudit(BuildContext context) {
    final text = AppTextScope.of(context);
    final audit = employeeAudit;
    return [
      WhiteCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuditCardHeading(
              icon: Icons.person_search_rounded,
              title: text.t('Employee learning effort'),
              subtitle: text.t('Search, then tap an employee to load'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchUsers(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: AppInputStyle.decoration(
                text.t('Name, employee ID, role or phone'),
              ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: searching
                    ? text.t('Searching...')
                    : text.t('Search Employee'),
                icon: Icons.manage_search_rounded,
                onPressed: searching ? null : searchUsers,
              ),
            ),
          ],
        ),
      ),
      if (searchRequested) ...[
        const SizedBox(height: 12),
        if (!searching && users.isEmpty)
          _InlineAuditMessage(
            icon: Icons.person_off_outlined,
            message: text.t('No employee found.'),
          )
        else
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EmployeeResultCard(
                user: user,
                selected: selectedUser?.id == user.id,
                onTap: () => loadEmployee(user),
              ),
            ),
          ),
      ],
      if (loadingEmployee) ...[
        const SizedBox(height: 18),
        const Center(child: CircularProgressIndicator()),
      ],
      if (audit != null && !loadingEmployee) ...[
        const SizedBox(height: 8),
        _AuditHero(
          icon: Icons.timer_outlined,
          eyebrow: '${audit.user.employeeId} · ${audit.user.role.name}',
          title: audit.user.fullName,
          value: formatPlaybackTime(audit.totalPlayedSeconds),
          caption: text.t('Total active playback time'),
        ),
        const SizedBox(height: 14),
        Text(
          text.t('SOP videos watched'),
          style: const TextStyle(
            fontSize: AppTextSize.s20,
            fontWeight: FontWeight.w800,
            color: AppColours.textMain,
          ),
        ),
        const SizedBox(height: 10),
        if (audit.videos.isEmpty)
          _InlineAuditMessage(
            icon: Icons.ondemand_video_outlined,
            message: text.t('No recorded active playback time yet.'),
          )
        else
          _AnimatedTimeChart(
            rows: audit.videos
                .map(
                  (video) => _AuditChartRow(
                    id: video.sopId,
                    title: video.title,
                    subtitle: languageLabel(video.language),
                    seconds: video.totalPlayedSeconds,
                    trailing: video.lastWatchedAt == null
                        ? null
                        : '${text.t('Last watched')} ${shortDate(video.lastWatchedAt!)}',
                  ),
                )
                .toList(growable: false),
          ),
      ],
    ];
  }

  List<Widget> buildVideoImpact(BuildContext context) {
    final text = AppTextScope.of(context);
    final audit = impactAudit;
    return [
      WhiteCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuditCardHeading(
              icon: Icons.auto_graph_rounded,
              title: text.t('Video Analytics'),
              subtitle: text.t(
                'Compare SOP videos by total active playback time',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: loadingImpact
                    ? text.t('Loading...')
                    : audit == null
                        ? text.t('Load Video Analytics')
                        : text.t('Refresh Video Analytics'),
                icon: Icons.bar_chart_rounded,
                onPressed: loadingImpact ? null : loadImpact,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              text.t('Data loads only when u press this button.'),
              style: AppTextStyles.formHint,
            ),
          ],
        ),
      ),
      if (loadingImpact) ...[
        const SizedBox(height: 18),
        const Center(child: CircularProgressIndicator()),
      ],
      if (audit != null && !loadingImpact) ...[
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CompactMetric(
                icon: Icons.schedule_rounded,
                label: text.t('All active playback'),
                value: formatPlaybackTime(audit.totalPlayedSeconds),
                colour: AppColours.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactMetric(
                icon: Icons.groups_2_outlined,
                label: text.t('Unique employees'),
                value: '${audit.uniqueViewers}',
                colour: AppColours.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          text.t('Most watched SOP videos'),
          style: const TextStyle(
            fontSize: AppTextSize.s20,
            fontWeight: FontWeight.w800,
            color: AppColours.textMain,
          ),
        ),
        const SizedBox(height: 10),
        if (audit.videos.isEmpty)
          _InlineAuditMessage(
            icon: Icons.ondemand_video_outlined,
            message: text.t('No SOP videos available.'),
          )
        else
          _AnimatedTimeChart(
            rows: audit.videos
                .map(
                  (video) => _AuditChartRow(
                    id: video.sopId,
                    title: video.title,
                    subtitle:
                        '${languageLabel(video.language)} · ${video.uniqueViewers} ${text.t('employees')}',
                    seconds: video.totalPlayedSeconds,
                    trailing: video.lastWatchedAt == null
                        ? null
                        : '${text.t('Last watched')} ${shortDate(video.lastWatchedAt!)}',
                  ),
                )
                .toList(growable: false),
          ),
      ],
      const SizedBox(height: 12),
      _InlineAuditMessage(
        icon: Icons.info_outline_rounded,
        message: text.t(
          'Playback time is recorded only while the SOP video is actively playing in the foreground. It cannot prove attention or understanding.',
        ),
        colour: AppColours.orange,
      ),
    ];
  }
}

class _AuditModeSwitch extends StatelessWidget {
  final _KnowledgeAuditMode value;
  final ValueChanged<_KnowledgeAuditMode> onChanged;

  const _AuditModeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9ED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuditModeButton(
              label: text.t('By Employee'),
              icon: Icons.person_outline_rounded,
              selected: value == _KnowledgeAuditMode.employee,
              onTap: () => onChanged(_KnowledgeAuditMode.employee),
            ),
          ),
          Expanded(
            child: _AuditModeButton(
              label: text.t('Video Analytics'),
              icon: Icons.video_library_outlined,
              selected: value == _KnowledgeAuditMode.video,
              onTap: () => onChanged(_KnowledgeAuditMode.video),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AuditModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColours.blue : AppColours.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTextSize.s14,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColours.textMain : AppColours.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditCardHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AuditCardHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColours.blue),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textMain,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.formHint),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeeResultCard extends StatelessWidget {
  final EastAppUser user;
  final bool selected;
  final VoidCallback onTap;

  const _EmployeeResultCard({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColours.blue : AppColours.border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? AppColours.blue : AppColours.mutedBox,
              foregroundColor: selected ? Colors.white : AppColours.textMain,
              child: Text(
                user.fullName.trim().isEmpty
                    ? '?'
                    : user.fullName.trim().substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s16,
                      fontWeight: FontWeight.w800,
                      color: AppColours.textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${user.employeeId} · ${user.role.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.formHint,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: selected ? AppColours.blue : AppColours.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditHero extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String value;
  final String caption;

  const _AuditHero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123CA6), Color(0xFF2878FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331557F2),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: AppTextSize.s12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSize.s19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSize.s28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: AppTextSize.s12,
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

class _CompactMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color colour;

  const _CompactMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour, size: 24),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSize.s20,
              fontWeight: FontWeight.w900,
              color: AppColours.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.formHint,
          ),
        ],
      ),
    );
  }
}

class _AuditChartRow {
  final String id;
  final String title;
  final String subtitle;
  final int seconds;
  final String? trailing;

  const _AuditChartRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.seconds,
    this.trailing,
  });
}

class _AnimatedTimeChart extends StatelessWidget {
  final List<_AuditChartRow> rows;

  const _AnimatedTimeChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maximum = rows.fold<int>(
      0,
      (value, row) => row.seconds > value ? row.seconds : value,
    );
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnimatedTimeBar(
              key: ValueKey('${rows[index].id}:${rows[index].seconds}'),
              row: rows[index],
              rank: index + 1,
              maximum: maximum,
            ),
          ),
      ],
    );
  }
}

class _AnimatedTimeBar extends StatelessWidget {
  final _AuditChartRow row;
  final int rank;
  final int maximum;

  const _AnimatedTimeBar({
    super.key,
    required this.row,
    required this.rank,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maximum <= 0 ? 0.0 : row.seconds / maximum;
    final colour = rank == 1
        ? AppColours.gold
        : rank == 2
            ? AppColours.blue
            : rank == 3
                ? AppColours.purple
                : AppColours.green;
    return WhiteCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: colour,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s15,
                        fontWeight: FontWeight.w800,
                        color: AppColours.textMain,
                      ),
                    ),
                    Text(
                      row.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.formHint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatPlaybackTime(row.seconds),
                style: TextStyle(
                  color: colour,
                  fontSize: AppTextSize.s15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 9,
              color: AppColours.mutedBox,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value.clamp(0, 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colour.withValues(alpha: 0.7), colour],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (row.trailing != null) ...[
            const SizedBox(height: 7),
            Text(row.trailing!, style: AppTextStyles.formHint),
          ],
        ],
      ),
    );
  }
}

class _InlineAuditMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color colour;

  const _InlineAuditMessage({
    required this.icon,
    required this.message,
    this.colour = AppColours.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.formHint.copyWith(
                color: AppColours.textMain,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String languageLabel(String value) {
  return switch (value) {
    'MYANMAR' => 'Myanmar',
    'ENGLISH' => 'English',
    _ => value,
  };
}

String formatPlaybackTime(int seconds) {
  if (seconds <= 0) return '0m';
  final totalMinutes = seconds ~/ 60;
  if (totalMinutes == 0) return '<1m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String shortDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
