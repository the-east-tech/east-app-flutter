import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';
import 'east_brand_gradient.dart';

class AppHeader extends StatelessWidget {
  final String businessName;
  final VoidCallback? onIdentityTap;
  final int totalPoints;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  const AppHeader({
    super.key,
    required this.businessName,
    required this.onIdentityTap,
    required this.totalPoints,
    required this.notificationCount,
    required this.onNotifications,
    required this.onSettings,
    required this.onHelp,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return EastAnimatedGradientSurface(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 6),
          child: SizedBox(
            height: 42,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onIdentityTap,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppTextSize.s22,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (onIdentityTap != null) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.expand_more_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 82,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        text.t('Total Points'),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: AppTextSize.s10,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalPoints',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _NotificationButton(
                  count: notificationCount,
                  tooltip: text.t('Notifications'),
                  onPressed: onNotifications,
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: text.t('Settings'),
                  child: Container(
                    width: 36,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: onSettings,
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 30,
                  height: 32,
                  child: IconButton(
                    tooltip: text.t('Help'),
                    padding: EdgeInsets.zero,
                    onPressed: onHelp,
                    icon: const Icon(
                      Icons.bug_report_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  height: 32,
                  child: IconButton(
                    tooltip: text.t('Logout'),
                    padding: EdgeInsets.zero,
                    onPressed: onLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
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

class _NotificationButton extends StatelessWidget {
  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  const _NotificationButton({
    required this.count,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 34,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onPressed,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
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
