part of 'stock_screen.dart';

class _StockHomePage extends StatelessWidget {
  final UserRole role;
  final bool isOwner;
  final void Function(StockPage page) onOpenPage;

  const _StockHomePage({
    required this.role,
    required this.isOwner,
    required this.onOpenPage,
  });

  bool get isHead => role == UserRole.head;
  bool get isManager => role == UserRole.manager;
  bool get isStaff => role == UserRole.staff;
  bool get canReceiveStock => isManager || isHead;
  bool get canPurchaseStock => isManager || isHead;
  bool get canManageSetup => isOwner || isHead;

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _SectionTitle(
          text.t('Operation'),
          icon: Icons.inventory_2_outlined,
        ),
        _StockMenuGrid(
          children: [
            _StockMenuCard(
              title: text.t('Count'),
              subtitle: text.t('Stock Balance'),
              icon: Icons.fact_check_outlined,
              onTap: () => onOpenPage(StockPage.dailyCount),
            ),
            if (canReceiveStock)
              _StockMenuCard(
                title: text.t('Receiving'),
                subtitle: text.t('Invoice & goods check'),
                icon: Icons.assignment_turned_in_outlined,
                onTap: () => onOpenPage(StockPage.receiving),
              ),
            if (canPurchaseStock)
              _StockMenuCard(
                title: text.t('Purchase'),
                subtitle: text.t('Restock'),
                icon: Icons.shopping_bag_outlined,
                onTap: () => onOpenPage(StockPage.restockMessage),
              ),
          ],
        ),
        if (canManageSetup) ...[
          const SizedBox(height: 16),
          _SectionTitle(
            text.t('Setup'),
            icon: Icons.tune_rounded,
          ),
          _StockMenuGrid(
            children: [
              _StockMenuCard(
                title: text.t('SKU'),
                subtitle: text.t('Create/list SKU'),
                icon: Icons.widgets_outlined,
                onTap: () => onOpenPage(StockPage.skuSetup),
              ),
              _StockMenuCard(
                title: text.t('Supplier'),
                subtitle: text.t('Create/list Supplier'),
                icon: Icons.storefront_outlined,
                onTap: () => onOpenPage(StockPage.supplierSetup),
              ),
              _StockMenuCard(
                title: text.t('Tag'),
                subtitle: text.t('Custom Category'),
                icon: Icons.sell_outlined,
                onTap: () => onOpenPage(StockPage.tagSetup),
              ),
              _StockMenuCard(
                title: text.t('Assignee'),
                subtitle: text.t('Assign SKU to user'),
                icon: Icons.person_pin_circle_outlined,
                onTap: () => onOpenPage(StockPage.assigneeSetup),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: danger ? AppColours.red : AppColours.blue, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTextSize.s16,
              fontWeight: FontWeight.w700,
              color: danger ? AppColours.red : AppColours.textMain,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text.t(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle(this.title, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, 7 * (1 - progress)),
        child: Opacity(opacity: progress, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColours.blueSoft.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: AppColours.blue),
            ),
            const SizedBox(width: 9),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: AppTextSize.s14,
                fontWeight: FontWeight.w900,
                color: AppColours.textMain,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColours.blue.withValues(alpha: 0.28),
                      AppColours.border.withValues(alpha: 0.15),
                    ],
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

class _StockMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const _StockMenuGrid({required this.children});

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
              .map((child) => SizedBox(width: cardWidth, height: 108, child: child))
              .toList(),
        );
      },
    );
  }
}

class _StockMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _StockMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - progress)),
        child: Opacity(opacity: progress, child: child),
      ),
      child: WhiteCard(
        padding: EdgeInsets.zero,
        child: Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned(
                right: -20,
                top: -22,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColours.blueSoft.withValues(alpha: 0.48),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1557F2), Color(0xFF6B4EFF)],
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: AppColours.blue.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 21),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColours.textMuted,
                          size: 22,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w900,
                        color: AppColours.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? trailing;

  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final contextualApproval = _StockApprovalScope.maybeSectionOf(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(child: PageTitle(title: title, subtitle: subtitle)),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: trailing!,
              ),
          ],
        ),
        if (contextualApproval != null) ...[
          contextualApproval,
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    );
  }
}
