part of 'stock_screen.dart';

class _StockHomePage extends StatelessWidget {
  final UserRole role;
  final bool isOwner;
  final StockReviewSummary? reviewSummary;
  final Future<void> Function() onRefresh;
  final void Function(StockPage page) onOpenPage;

  const _StockHomePage({
    required this.role,
    required this.isOwner,
    required this.reviewSummary,
    required this.onRefresh,
    required this.onOpenPage,
  });

  bool get isHead => role == UserRole.head;
  bool get isManager => role == UserRole.manager;
  bool get isStaff => role == UserRole.staff;
  bool get canReceiveStock => isManager || isHead;
  bool get canPurchaseStock => isManager || isHead;
  bool get canManageSetup => isOwner || isHead;
  bool get canReview => isOwner || isHead;

  Widget? countBadge(int count) {
    if (count <= 0) return null;
    return Badge.count(
      count: count,
      backgroundColor: AppColours.red,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        DashboardSectionTitle(
          text.t('Operation'),
          icon: Icons.inventory_2_outlined,
        ),
        DashboardMenuGrid(
          children: [
            DashboardMenuCard(
              title: text.t('Count'),
              subtitle: text.t('Stock Balance'),
              icon: Icons.fact_check_outlined,
              badge: countBadge(
                canReview ? (reviewSummary?.dailyCountPending ?? 0) : 0,
              ),
              onTap: () => onOpenPage(StockPage.dailyCount),
            ),
            if (canReceiveStock)
              DashboardMenuCard(
                title: text.t('Receiving'),
                subtitle: text.t('Invoice & goods check'),
                icon: Icons.assignment_turned_in_outlined,
                badge: countBadge(
                  (reviewSummary?.readyToReceive ?? 0) +
                      (canReview
                          ? (reviewSummary?.receivingPending ?? 0)
                          : 0),
                ),
                onTap: () => onOpenPage(StockPage.receiving),
              ),
            if (canPurchaseStock)
              DashboardMenuCard(
                title: text.t('Purchase'),
                subtitle: text.t('Restock'),
                icon: Icons.shopping_bag_outlined,
                onTap: () => onOpenPage(StockPage.restockMessage),
              ),
          ],
        ),
        if (canManageSetup) ...[
          const SizedBox(height: 16),
          DashboardSectionTitle(
            text.t('Setup'),
            icon: Icons.tune_rounded,
          ),
          DashboardMenuGrid(
            children: [
              DashboardMenuCard(
                title: text.t('SKU'),
                subtitle: text.t('Create/list SKU'),
                icon: Icons.widgets_outlined,
                badge: isOwner
                    ? countBadge(reviewSummary?.skuChangePending ?? 0)
                    : null,
                onTap: () => onOpenPage(StockPage.skuSetup),
              ),
              DashboardMenuCard(
                title: text.t('Supplier'),
                subtitle: text.t('Create/list Supplier'),
                icon: Icons.storefront_outlined,
                onTap: () => onOpenPage(StockPage.supplierSetup),
              ),
              DashboardMenuCard(
                title: text.t('Tag'),
                subtitle: text.t('Custom Category'),
                icon: Icons.sell_outlined,
                onTap: () => onOpenPage(StockPage.tagSetup),
              ),
              DashboardMenuCard(
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

    return RefreshIndicator(onRefresh: onRefresh, child: content);
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
