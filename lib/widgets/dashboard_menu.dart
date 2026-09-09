import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_components.dart';

class DashboardSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const DashboardSectionTitle(this.title, {super.key, required this.icon});

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

class DashboardMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const DashboardMenuGrid({super.key, required this.children});

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
                  height: 108,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class DashboardMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;

  const DashboardMenuCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
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
          child: Padding(
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
                    ?badge,
                    if (badge != null) const SizedBox(width: 6),
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
        ),
      ),
    );
  }
}
