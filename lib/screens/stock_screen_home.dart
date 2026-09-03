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
  bool get canReviewStock => isManager || isHead;
  bool get canManageSetup => isOwner || isHead;
  bool get canAccessAuditTrail => isOwner || isHead;

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final todaySubtitle = isStaff
        ? text.t('Update daily physical stock balance')
        : text.t('Count stock / receive goods / prepare restock');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PageTitle(title: text.t('Stock Dashboard'), subtitle: todaySubtitle),
        const SizedBox(height: 8),
        _SectionTitle(text.t('Operation')),
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
            if (canReviewStock)
              _StockMenuCard(
                title: text.t('Purchase'),
                subtitle: text.t('Restock'),
                icon: Icons.content_copy_rounded,
                onTap: () => onOpenPage(StockPage.restockMessage),
              ),
            if (canReviewStock)
              _StockMenuCard(
                title: text.t('Review'),
                subtitle: text.t('Audit Inbound'),
                icon: Icons.manage_search_rounded,
                onTap: () => onOpenPage(StockPage.review),
              ),
          ],
        ),
        if (canManageSetup) ...[
          const SizedBox(height: 12),
          _SectionTitle(text.t('Setup - Owner & Head')),
          _StockMenuGrid(
            children: [
              _StockMenuCard(
                title: text.t('SKU'),
                subtitle: text.t('Create/list SKU'),
                icon: Icons.add_box_outlined,
                onTap: () => onOpenPage(StockPage.skuSetup),
              ),
              _StockMenuCard(
                title: text.t('Supplier'),
                subtitle: text.t('Create/list Supplier'),
                icon: Icons.add_business_outlined,
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
                icon: Icons.assignment_ind_outlined,
                onTap: () => onOpenPage(StockPage.assigneeSetup),
              ),
              if (canAccessAuditTrail)
                _StockMenuCard(
                  title: text.t('Audit Trail'),
                  subtitle: text.t('Change log'),
                  icon: Icons.manage_history_rounded,
                  onTap: () => onOpenPage(StockPage.auditTrail),
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

  const _SectionTitle(this.title);

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
              .map((child) => SizedBox(width: cardWidth, height: 100, child: child))
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
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: InkWell(
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
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
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
        ...children,
      ],
    );
  }
}
