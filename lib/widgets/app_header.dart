import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  final String businessName;
  final VoidCallback? onIdentityTap;
  final int totalPoints;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  const AppHeader({
    super.key,
    required this.businessName,
    required this.onIdentityTap,
    required this.totalPoints,
    required this.onSettings,
    required this.onHelp,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return Container(
      color: AppColours.blue,
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
