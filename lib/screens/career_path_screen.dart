import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';

class CareerPathScreen extends StatefulWidget {
  final String currentRoleSystemKey;
  final String currentRoleName;

  const CareerPathScreen({
    super.key,
    required this.currentRoleSystemKey,
    required this.currentRoleName,
  });

  @override
  State<CareerPathScreen> createState() => _CareerPathScreenState();
}

class _CareerPathScreenState extends State<CareerPathScreen>
    with SingleTickerProviderStateMixin {
  static const roles = <_CareerRole>[
    _CareerRole(
      systemKey: 'STAFF_2',
      name: 'Staff 2',
      headline: 'Build the foundation',
      description: 'Learn the essentials and build reliable daily habits.',
      icon: Icons.eco_rounded,
      colour: Color(0xFF00A67A),
    ),
    _CareerRole(
      systemKey: 'STAFF_1',
      name: 'Staff 1',
      headline: 'Own the routine',
      description: 'Handle daily work confidently, consistently and independently.',
      icon: Icons.bolt_rounded,
      colour: Color(0xFF1557F2),
    ),
    _CareerRole(
      systemKey: 'SUPERVISOR',
      name: 'Supervisor',
      headline: 'Guide the shift',
      description: 'Support the team, spot issues early and keep the shift moving.',
      icon: Icons.groups_2_rounded,
      colour: Color(0xFF7C3AED),
    ),
    _CareerRole(
      systemKey: 'MANAGER',
      name: 'Manager',
      headline: 'Lead operations',
      description: 'Make decisions, develop people and own operational results.',
      icon: Icons.insights_rounded,
      colour: Color(0xFFFF6B00),
    ),
    _CareerRole(
      systemKey: 'HEAD',
      name: 'Head',
      headline: 'Reach the summit',
      description: 'Set direction, grow leaders and shape how the business succeeds.',
      icon: Icons.workspace_premium_rounded,
      colour: Color(0xFFF5B800),
    ),
  ];

  late final AnimationController burstController;
  late int selectedRoleIndex;

  int get currentRoleIndex {
    if (widget.currentRoleSystemKey == 'OWNER') return roles.length - 1;
    return roles.indexWhere(
      (role) => role.systemKey == widget.currentRoleSystemKey,
    );
  }

  bool get isOwner => widget.currentRoleSystemKey == 'OWNER';

  @override
  void initState() {
    super.initState();
    final initialIndex = currentRoleIndex;
    selectedRoleIndex = initialIndex < 0 ? 0 : initialIndex;
    burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..value = 1;
  }

  @override
  void dispose() {
    burstController.dispose();
    super.dispose();
  }

  void selectRole(int index) {
    setState(() => selectedRoleIndex = index);
    burstController.forward(from: 0);
    unawaited(AppFeedback.success());
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final selected = roles[selectedRoleIndex];
    final displayRoles = roles.reversed.toList(growable: false);

    return Scaffold(
      backgroundColor: AppColours.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: IconButton(
                        tooltip: text.t('Back'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Expanded(
                      child: PageTitle(
                        title: text.t('Career Path'),
                        subtitle: text.t('Climb from Staff to Head'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CareerHero(
                    currentRoleName: widget.currentRoleName,
                    selectedRole: selected,
                    burstController: burstController,
                    isOwner: isOwner,
                  ),
                  const SizedBox(height: 14),
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.route_rounded,
                              color: AppColours.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text.t('Your climb'),
                                style: const TextStyle(
                                  fontSize: AppTextSize.s18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColours.textMain,
                                ),
                              ),
                            ),
                            Text(
                              text.t('Tap any role'),
                              style: const TextStyle(
                                fontSize: AppTextSize.s12,
                                fontWeight: FontWeight.w700,
                                color: AppColours.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (var displayIndex = 0;
                            displayIndex < displayRoles.length;
                            displayIndex++)
                          _CareerPathEntry(
                            role: displayRoles[displayIndex],
                            sourceIndex: roles.length - 1 - displayIndex,
                            displayIndex: displayIndex,
                            totalEntries: displayRoles.length,
                            selectedRoleIndex: selectedRoleIndex,
                            currentRoleIndex: currentRoleIndex,
                            isOwner: isOwner,
                            onTap: selectRole,
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerHero extends StatelessWidget {
  final String currentRoleName;
  final _CareerRole selectedRole;
  final AnimationController burstController;
  final bool isOwner;

  const _CareerHero({
    required this.currentRoleName,
    required this.selectedRole,
    required this.burstController,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071A44), Color(0xFF1557F2), Color(0xFF6B4EFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331557F2),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -28,
            child: Icon(
              Icons.landscape_rounded,
              size: 170,
              color: Colors.white.withValues(alpha: 0.11),
            ),
          ),
          Positioned(
            right: 20,
            top: 18,
            child: AnimatedBuilder(
              animation: burstController,
              builder: (context, child) {
                final curved = Curves.easeOutBack.transform(
                  burstController.value,
                );
                return Opacity(
                  opacity: (1 - burstController.value)
                      .clamp(0.0, 1.0)
                      .toDouble(),
                  child: Transform.scale(
                    scale: 0.7 + curved,
                    child: child,
                  ),
                );
              },
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFFE27A),
                size: 38,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    isOwner
                        ? '${text.t('Career mentor')} · $currentRoleName'
                        : '${text.t('Current role')} · $currentRoleName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppTextSize.s13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Row(
                    key: ValueKey(selectedRole.systemKey),
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: selectedRole.colour,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          selectedRole.icon,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text.t(selectedRole.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppTextSize.s26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              text.t(selectedRole.headline),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: AppTextSize.s14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    text.t(selectedRole.description),
                    key: ValueKey('${selectedRole.systemKey}-description'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: AppTextSize.s15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
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

class _CareerPathEntry extends StatelessWidget {
  final _CareerRole role;
  final int sourceIndex;
  final int displayIndex;
  final int totalEntries;
  final int selectedRoleIndex;
  final int currentRoleIndex;
  final bool isOwner;
  final ValueChanged<int> onTap;

  const _CareerPathEntry({
    required this.role,
    required this.sourceIndex,
    required this.displayIndex,
    required this.totalEntries,
    required this.selectedRoleIndex,
    required this.currentRoleIndex,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final selected = sourceIndex == selectedRoleIndex;
    final current = !isOwner && sourceIndex == currentRoleIndex;
    final achieved = isOwner ||
        (currentRoleIndex >= 0 && sourceIndex <= currentRoleIndex);
    final next = !isOwner && sourceIndex == currentRoleIndex + 1;
    final status = current
        ? 'Current'
        : next
            ? 'Next climb'
            : achieved
                ? 'Unlocked'
                : sourceIndex == totalEntries - 1
                    ? 'Summit'
                    : 'Ahead';
    final statusIcon = current
        ? Icons.hiking_rounded
        : achieved
            ? Icons.check_rounded
            : next
                ? Icons.arrow_upward_rounded
                : Icons.lock_outline_rounded;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 280 + displayIndex * 70),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - progress)),
        child: Opacity(opacity: progress, child: child),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 3,
                      color: displayIndex == 0
                          ? Colors.transparent
                          : achieved
                              ? role.colour.withValues(alpha: 0.55)
                              : AppColours.border,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: selected ? 34 : 28,
                    height: selected ? 34 : 28,
                    decoration: BoxDecoration(
                      color: selected || achieved
                          ? role.colour
                          : AppColours.mutedBox,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? role.colour.withValues(alpha: 0.28)
                            : Colors.white,
                        width: selected ? 5 : 3,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        selected ? Icons.hiking_rounded : statusIcon,
                        key: ValueKey('$selected-$status'),
                        size: selected ? 18 : 14,
                        color: selected || achieved
                            ? Colors.white
                            : AppColours.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 3,
                      color: displayIndex == totalEntries - 1
                          ? Colors.transparent
                          : achieved
                              ? role.colour.withValues(alpha: 0.55)
                              : AppColours.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(sourceIndex),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 230),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? role.colour.withValues(alpha: 0.09)
                            : AppColours.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? role.colour.withValues(alpha: 0.55)
                              : AppColours.border,
                          width: selected ? 1.5 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: role.colour.withValues(alpha: 0.14),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.12 : 1,
                            duration: const Duration(milliseconds: 220),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: role.colour,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                role.icon,
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.t(role.name),
                                  style: const TextStyle(
                                    color: AppColours.textMain,
                                    fontSize: AppTextSize.s17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  text.t(role.headline),
                                  maxLines: selected ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColours.textMuted,
                                    fontSize: AppTextSize.s12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected || achieved
                                  ? role.colour.withValues(alpha: 0.12)
                                  : AppColours.mutedBox,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              text.t(status),
                              style: TextStyle(
                                color: selected || achieved
                                    ? role.colour
                                    : AppColours.textMuted,
                                fontSize: AppTextSize.s10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerRole {
  final String systemKey;
  final String name;
  final String headline;
  final String description;
  final IconData icon;
  final Color colour;

  const _CareerRole({
    required this.systemKey,
    required this.name,
    required this.headline,
    required this.description,
    required this.icon,
    required this.colour,
  });
}
