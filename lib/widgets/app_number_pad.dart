import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';
import 'app_feedback.dart';

typedef AppNumberPadPreviewBuilder = Widget Function(
  BuildContext context,
  double value,
);

Future<String?> showAppNumberPad(
  BuildContext context, {
  required String title,
  String initialText = '',
  String prefixText = '',
  String suffixText = '',
  int decimalPlaces = 2,
  int maxIntegerDigits = 12,
  double? minimum,
  double? maximum,
  String? validationMessage,
  String Function(double value)? valueFormatter,
  AppNumberPadPreviewBuilder? previewBuilder,
}) {
  assert(decimalPlaces >= 0);
  assert(maxIntegerDigits > 0);

  final textScope = context.getInheritedWidgetOfExactType<AppTextScope>();
  var enteredText = initialText.trim();
  var firstTap = true;
  String? keypadError;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void addKey(String key) {
            setSheetState(() {
              keypadError = null;
              if (key == 'back') {
                if (enteredText.isNotEmpty) {
                  enteredText = enteredText.substring(
                    0,
                    enteredText.length - 1,
                  );
                }
                firstTap = false;
                return;
              }
              if (key == 'clear') {
                enteredText = '';
                firstTap = false;
                return;
              }
              if (key == '.' &&
                  (decimalPlaces == 0 || enteredText.contains('.'))) {
                return;
              }

              final base = firstTap ? '' : enteredText;
              final next = base == '0' && key != '.' ? key : '$base$key';
              final decimalPattern = decimalPlaces == 0
                  ? ''
                  : r'(?:\.\d{0,' + '$decimalPlaces' + r'})?';
              final pattern = RegExp(
                r'^\d{0,' + '$maxIntegerDigits' + '}$decimalPattern' + r'$',
              );
              if (pattern.hasMatch(next)) {
                enteredText = next;
                firstTap = false;
              }
            });
          }

          void save() {
            final value = double.tryParse(enteredText);
            final invalid = value == null ||
                (minimum != null && value < minimum) ||
                (maximum != null && value > maximum);
            if (invalid) {
              AppFeedback.warning();
              setSheetState(() {
                keypadError = textScope?.text.t(
                      validationMessage ?? 'Valid number required',
                    ) ??
                    validationMessage ??
                    'Valid number required';
              });
              return;
            }
            Navigator.of(sheetContext).pop(
              valueFormatter?.call(value) ??
                  _formatNumberPadValue(value, decimalPlaces),
            );
          }

          final value = double.tryParse(enteredText) ?? 0;
          final displayValue = enteredText.isEmpty ? '0' : enteredText;
          final keys = decimalPlaces == 0
              ? const [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                  '00',
                  '0',
                  'back',
                ]
              : const [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                  '.',
                  '0',
                  'back',
                ];

          return FractionallySizedBox(
            heightFactor: .88,
            child: Material(
              color: AppColours.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColours.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            textScope?.text.t(title) ?? title,
                            style: const TextStyle(
                              fontSize: AppTextSize.s24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: .96, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        '$prefixText$displayValue$suffixText',
                        key: ValueKey(displayValue),
                        style: const TextStyle(
                          fontSize: AppTextSize.s34,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textMain,
                        ),
                      ),
                    ),
                    if (keypadError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        keypadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColours.red,
                          fontSize: AppTextSize.s13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (previewBuilder != null) ...[
                      const SizedBox(height: 8),
                      previewBuilder(context, value),
                    ],
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: keys.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2,
                          ),
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        return _AppNumberPadButton(
                          label: key == 'back' ? '' : key,
                          icon: key == 'back'
                              ? Icons.backspace_outlined
                              : null,
                          onTap: () => addKey(key),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: textScope?.text.t('Clear') ?? 'Clear',
                            icon: Icons.clear_rounded,
                            outlined: true,
                            onPressed: () => addKey('clear'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            text: textScope?.text.t('Save') ?? 'Save',
                            icon: Icons.check_rounded,
                            onPressed: save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class AppNumberPadField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String hintText;
  final String prefixText;
  final String suffixText;
  final IconData? prefixIcon;
  final int decimalPlaces;
  final int maxIntegerDigits;
  final double? minimum;
  final double? maximum;
  final String? validationMessage;
  final ValueChanged<String>? onChanged;

  const AppNumberPadField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.hintText = '0',
    this.prefixText = '',
    this.suffixText = '',
    this.prefixIcon,
    this.decimalPlaces = 2,
    this.maxIntegerDigits = 12,
    this.minimum,
    this.maximum,
    this.validationMessage,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      onTap: enabled
          ? () async {
              FocusScope.of(context).unfocus();
              final value = await showAppNumberPad(
                context,
                title: label,
                initialText: controller.text,
                prefixText: prefixText,
                suffixText: suffixText,
                decimalPlaces: decimalPlaces,
                maxIntegerDigits: maxIntegerDigits,
                minimum: minimum,
                maximum: maximum,
                validationMessage: validationMessage,
              );
              if (value == null || !context.mounted) return;
              controller.text = value;
              controller.selection = TextSelection.collapsed(
                offset: controller.text.length,
              );
              onChanged?.call(value);
            }
          : null,
      decoration: AppInputStyle.decoration(
        text.t(hintText),
        prefixText: prefixText.isEmpty ? null : prefixText,
        suffixText: suffixText.isEmpty ? null : suffixText,
      ).copyWith(
        labelText: text.t(label),
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: enabled ? const Icon(Icons.dialpad_rounded) : null,
      ),
    );
  }
}

class _AppNumberPadButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _AppNumberPadButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColours.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColours.border),
        ),
        child: icon == null
            ? Text(
                label,
                style: const TextStyle(
                  fontSize: AppTextSize.s26,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textMain,
                ),
              )
            : Icon(icon, size: 24, color: AppColours.textMain),
      ),
    );
  }
}

String _formatNumberPadValue(double value, int decimalPlaces) {
  if (decimalPlaces == 0) return value.toInt().toString();
  return value
      .toStringAsFixed(decimalPlaces)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
