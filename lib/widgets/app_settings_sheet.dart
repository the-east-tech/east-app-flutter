import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_text.dart';
import '../models/translation_models.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';
import 'app_feedback.dart';

class AppSettingsSheet extends StatefulWidget {
  final AppLanguage language;
  final TranslationDirection? translationDirection;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final Future<TranslationPreview> Function(TranslationDirection direction)
      onTranslationPreview;
  final Future<void> Function(TranslationDirection? direction)
      onTranslationChanged;

  const AppSettingsSheet({
    super.key,
    required this.language,
    required this.translationDirection,
    required this.onLanguageChanged,
    required this.onTranslationPreview,
    required this.onTranslationChanged,
  });

  @override
  State<AppSettingsSheet> createState() => _AppSettingsSheetState();
}

class _AppSettingsSheetState extends State<AppSettingsSheet> {
  late AppLanguage language;
  late TranslationDirection? translationDirection;
  bool saving = false;
  String savingMessage = 'Saving settings...';

  @override
  void initState() {
    super.initState();
    language = widget.language;
    translationDirection = widget.translationDirection;
  }

  void changeTranslation(String? value) {
    if (value == null || saving) return;
    final selected = value == 'ORIGINAL'
        ? null
        : TranslationDirection.values.firstWhere(
            (item) => item.name == value,
          );
    if (selected == translationDirection) return;
    setState(() => translationDirection = selected);
  }

  Future<void> saveSettings() async {
    if (saving) return;
    setState(() {
      saving = true;
      savingMessage = translationDirection == null
          ? 'Saving settings...'
          : 'Checking the translation cache...';
    });
    try {
      final selected = translationDirection;
      if (selected != null) {
        final preview = await widget.onTranslationPreview(selected);
        if (!mounted) return;
        final confirmed = await showTranslationConfirmation(
          preview,
          selected,
        );
        if (!confirmed || !mounted) return;
        setState(() => savingMessage = 'Applying translation...');
      }

      await widget.onTranslationChanged(selected);
      if (!mounted) return;
      widget.onLanguageChanged(language);
      Navigator.of(context).pop();
    } catch (_) {
      // The shared API error dialog explains why the settings were not saved.
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> showTranslationConfirmation(
    TranslationPreview preview,
    TranslationDirection direction,
  ) async {
    await AppFeedback.warning();
    if (!mounted) return false;

    final text = AppText(language);
    final companion = ContentLanguage.values.firstWhere(
      (item) => item != direction.source && item != direction.target,
    );
    var confirmationSubmitted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final hasProviderCalls = preview.providerRequestsIfConfirmed > 0;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                hasProviderCalls
                    ? Icons.warning_amber_rounded
                    : Icons.cloud_done_outlined,
                color: hasProviderCalls
                    ? AppColours.orange
                    : AppColours.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.t('Translation cost confirmation'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t(
                      'The cache check is complete. Cloudflare has not been called.',
                    ),
                    style: const TextStyle(
                      fontSize: AppTextSize.s14,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TranslationMetric(
                    label: text.t('Content found this session'),
                    value: preview.uniqueTextCount,
                  ),
                  _TranslationMetric(
                    label: text.t('Stored translations'),
                    value: preview.storedTranslations,
                  ),
                  _TranslationMetric(
                    label: text.t('Selected-language cache misses'),
                    value: preview.selectedCacheMisses,
                  ),
                  _TranslationMetric(
                    label:
                        '${text.t('Companion-language cache misses')} (${text.t(companion.label)})',
                    value: preview.companionCacheMisses,
                  ),
                  _TranslationMetric(
                    label: text.t('New Cloudflare requests'),
                    value: preview.providerRequestsIfConfirmed,
                    emphasise: hasProviderCalls,
                  ),
                  const SizedBox(height: 12),
                  if (!preview.providerAvailable &&
                      preview.selectedCacheMisses > 0)
                    _TranslationNotice(
                      icon: Icons.cloud_off_outlined,
                      colour: AppColours.red,
                      message: text.t(
                        'Cloudflare is unavailable. Missing selected-language translations cannot be completed.',
                      ),
                    )
                  else if (!preview.providerAvailable)
                    _TranslationNotice(
                      icon: Icons.cloud_off_outlined,
                      colour: AppColours.orange,
                      message: text.t(
                        'Cloudflare is unavailable, but the selected language is fully cached and can be used without a provider call.',
                      ),
                    )
                  else if (hasProviderCalls)
                    _TranslationNotice(
                      icon: Icons.paid_outlined,
                      colour: AppColours.orange,
                      message: text.t(
                        'Cloudflare Workers AI may create billable usage for these new requests. Use carefully.',
                      ),
                    )
                  else
                    _TranslationNotice(
                      icon: Icons.savings_outlined,
                      colour: AppColours.green,
                      message: text.t(
                        'Everything required is cached. Confirming will not call Cloudflare.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    text.t('Exact behaviour'),
                    style: const TextStyle(
                      color: AppColours.textMain,
                      fontSize: AppTextSize.s14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    'Changing a dropdown does nothing until Save.',
                    'Back or forward navigation never calls Cloudflare.',
                    'Save checks PostgreSQL first; cache hits do not call Cloudflare.',
                    'Only missing translations call Cloudflare after confirmation.',
                    'One uncached source can create up to two Cloudflare requests because both other languages are stored.',
                    'Save includes matching content discovered on visited pages in the current sign-in session, not only the visible page.',
                    'Newly loaded content stays original until the next Save.',
                    'Double-clicking Save or Confirm does not send another request.',
                    'Localisation changes fixed labels only and never calls Cloudflare.',
                    'Saving Original content (off) never calls Cloudflare.',
                    'Cloudflare may record billable usage even if a submitted provider request later fails.',
                  ].map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: AppColours.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text.t(item),
                              style: AppTextStyles.formHint.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasProviderCalls) ...[
                    const SizedBox(height: 6),
                    Text(
                      text.t(
                        'This estimate uses the current database cache. Another completed translation can only reduce the actual request count.',
                      ),
                      style: AppTextStyles.formHint.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (confirmationSubmitted) return;
                confirmationSubmitted = true;
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                text.t(preview.canApply ? 'Cancel' : 'Close'),
              ),
            ),
            if (preview.canApply)
              FilledButton(
                onPressed: () {
                  if (confirmationSubmitted) return;
                  confirmationSubmitted = true;
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(
                  text.t(
                    hasProviderCalls
                        ? 'Confirm & translate'
                        : 'Use cache & save',
                  ),
                ),
              ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText(language);
    final translationValue = translationDirection?.name ?? 'ORIGINAL';

    return PopScope(
      canPop: !saving,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColours.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: AppColours.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text.t('Settings'),
                      style: const TextStyle(
                        color: AppColours.textMain,
                        fontSize: AppTextSize.s22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: text.t('Close'),
                    onPressed: saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t('Localisation'),
                      style: const TextStyle(
                        color: AppColours.textMain,
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text.t('Choose the language for fixed app labels.'),
                      style: AppTextStyles.formHint,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AppLanguage>(
                      key: ValueKey('localisation:${language.name}'),
                      initialValue: language,
                      isExpanded: true,
                      decoration: AppInputStyle.decoration(
                        text.t('Localisation'),
                      ),
                      items: AppLanguage.values
                          .map(
                            (item) => DropdownMenuItem<AppLanguage>(
                              value: item,
                              child: Text(item.displayName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null || value == language) return;
                              setState(() => language = value);
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t('Translate'),
                      style: const TextStyle(
                        color: AppColours.textMain,
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text.t(
                        'Translate user-entered content. The original and both translations are stored for reuse.',
                      ),
                      style: AppTextStyles.formHint,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('translation:$translationValue'),
                      initialValue: translationValue,
                      isExpanded: true,
                      decoration: AppInputStyle.decoration(
                        text.t('Translate'),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'ORIGINAL',
                          child: Text(text.t('Original content (off)')),
                        ),
                        ...TranslationDirection.values.map(
                          (direction) => DropdownMenuItem<String>(
                            value: direction.name,
                            child: Text(
                              '${text.t(direction.source.label)} → ${text.t(direction.target.label)}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: saving ? null : changeTranslation,
                    ),
                    if (saving) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 6),
                      Text(
                        text.t(savingMessage),
                        style: AppTextStyles.formHint,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          saving ? null : () => Navigator.of(context).pop(),
                      child: Text(text.t('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : saveSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(text.t('Save settings')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslationMetric extends StatelessWidget {
  const _TranslationMetric({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final int value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColours.textMuted,
                fontSize: AppTextSize.s13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$value',
            style: TextStyle(
              color: emphasise ? AppColours.orange : AppColours.textMain,
              fontSize: AppTextSize.s15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationNotice extends StatelessWidget {
  const _TranslationNotice({
    required this.icon,
    required this.colour,
    required this.message,
  });

  final IconData icon;
  final Color colour;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colour,
                fontSize: AppTextSize.s13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
