import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/app_version_models.dart';
import '../theme/app_theme.dart';

class AppUpdateScreen extends StatelessWidget {
  final AppVersionPolicy policy;
  final Future<void> Function()? onUpdate;

  const AppUpdateScreen({
    super.key,
    required this.policy,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Scaffold(
      backgroundColor: AppColours.blue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 420,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.system_update_alt_rounded,
                    size: 48,
                    color: AppColours.blue,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    text.t('Flow update required'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppTextSize.s24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    text.t(
                      'This version is no longer supported. Update Flow to continue.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${text.t('Installed')}: ${policy.currentDisplayVersion}\n'
                    '${text.t('Latest')}: ${policy.latestDisplayVersion}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColours.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onUpdate,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(text.t('Update Flow')),
                    ),
                  ),
                  if (onUpdate == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      text.t('Open the app store and update Flow.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
