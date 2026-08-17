import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  final String businessName;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback? onIdentityTap;
  final int totalPoints;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  const AppHeader({
    super.key,
    required this.businessName,
    required this.language,
    required this.onLanguageChanged,
    required this.onIdentityTap,
    required this.totalPoints,
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
                PopupMenuButton<AppLanguage>(
                  initialValue: language,
                  onSelected: onLanguageChanged,
                  itemBuilder: (context) => AppLanguage.values
                      .map(
                        (item) => PopupMenuItem<AppLanguage>(
                          value: item,
                          child: Text(item.displayName),
                        ),
                      )
                      .toList(),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          language.shortLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppTextSize.s13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 30,
                  height: 32,
                  child: IconButton(
                    tooltip: 'Help',
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
                    tooltip: 'Logout',
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
