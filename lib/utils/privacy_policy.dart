import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_language.dart';
import '../localization/app_text.dart';

final Uri flowPrivacyPolicyUrl =
    Uri.parse('https://sequosal.com/flow/privacy/');

Future<void> openFlowPrivacyPolicy(
  BuildContext context,
  AppLanguage language,
) async {
  try {
    if (await launchUrl(
      flowPrivacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Show the same user-visible error as a failed launch result.
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppText(language).t(
          'Unable to open the privacy policy. Please try again.',
        ),
      ),
    ),
  );
}
