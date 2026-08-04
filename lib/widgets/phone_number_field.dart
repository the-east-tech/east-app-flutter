import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class PhoneCountry {
  final String isoCode;
  final String name;
  final String dialCode;
  final String flag;

  const PhoneCountry({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

const List<PhoneCountry> phoneCountries = [
  PhoneCountry(isoCode: 'MY', name: 'Malaysia', dialCode: '+60', flag: '🇲🇾'),
  PhoneCountry(isoCode: 'SG', name: 'Singapore', dialCode: '+65', flag: '🇸🇬'),
  PhoneCountry(isoCode: 'ID', name: 'Indonesia', dialCode: '+62', flag: '🇮🇩'),
  PhoneCountry(isoCode: 'TH', name: 'Thailand', dialCode: '+66', flag: '🇹🇭'),
  PhoneCountry(isoCode: 'PH', name: 'Philippines', dialCode: '+63', flag: '🇵🇭'),
  PhoneCountry(isoCode: 'VN', name: 'Vietnam', dialCode: '+84', flag: '🇻🇳'),
  PhoneCountry(isoCode: 'BN', name: 'Brunei', dialCode: '+673', flag: '🇧🇳'),
  PhoneCountry(isoCode: 'CN', name: 'China', dialCode: '+86', flag: '🇨🇳'),
  PhoneCountry(isoCode: 'HK', name: 'Hong Kong', dialCode: '+852', flag: '🇭🇰'),
  PhoneCountry(isoCode: 'TW', name: 'Taiwan', dialCode: '+886', flag: '🇹🇼'),
  PhoneCountry(isoCode: 'JP', name: 'Japan', dialCode: '+81', flag: '🇯🇵'),
  PhoneCountry(isoCode: 'KR', name: 'South Korea', dialCode: '+82', flag: '🇰🇷'),
  PhoneCountry(isoCode: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
  PhoneCountry(isoCode: 'AU', name: 'Australia', dialCode: '+61', flag: '🇦🇺'),
  PhoneCountry(isoCode: 'GB', name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧'),
  PhoneCountry(isoCode: 'US', name: 'United States / Canada', dialCode: '+1', flag: '🇺🇸'),
];

PhoneCountry get defaultPhoneCountry => phoneCountries.first;

PhoneCountry countryFromE164(String? value) {
  final phone = value?.trim() ?? '';
  final sorted = [...phoneCountries]
    ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  for (final country in sorted) {
    if (phone.startsWith(country.dialCode)) return country;
  }
  return defaultPhoneCountry;
}

String localDigitsFromE164(String? value, PhoneCountry country) {
  var phone = value?.trim() ?? '';
  if (phone.startsWith(country.dialCode)) {
    phone = phone.substring(country.dialCode.length);
  }
  return phone.replaceAll(RegExp(r'\D'), '');
}

String buildE164(PhoneCountry country, String localDigits) {
  var digits = localDigits.replaceAll(RegExp(r'\D'), '');
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  return '${country.dialCode}$digits';
}

bool isValidE164(String value) {
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value);
}

class PhoneNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String hint;
  final String? errorText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const PhoneNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.hint = 'Phone number',
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 126,
              height: 48,
              child: Material(
                color: enabled ? AppColours.mutedBox : AppColours.border,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: enabled
                      ? () async {
                          final selected = await showPhoneCountryPicker(
                            context,
                            selected: country,
                          );
                          if (selected != null) onCountryChanged(selected);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(country.flag, style: const TextStyle(fontSize: 19)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            country.dialCode,
                            style: AppTextStyles.formValue,
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColours.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textInputAction: textInputAction,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                autocorrect: false,
                enableSuggestions: false,
                style: AppTextStyles.formValue,
                decoration: AppInputStyle.decoration(
                  hint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<PhoneCountry?> showPhoneCountryPicker(
  BuildContext context, {
  required PhoneCountry selected,
}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _PhoneCountryPicker(selected: selected),
  );
}

class _PhoneCountryPicker extends StatefulWidget {
  final PhoneCountry selected;

  const _PhoneCountryPicker({required this.selected});

  @override
  State<_PhoneCountryPicker> createState() => _PhoneCountryPickerState();
}

class _PhoneCountryPickerState extends State<_PhoneCountryPicker> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = phoneCountries.where((country) {
      final target = '${country.name} ${country.isoCode} ${country.dialCode}'.toLowerCase();
      return target.contains(query.toLowerCase().trim());
    }).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColours.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Country Code',
                style: TextStyle(
                  fontSize: AppTextSize.s24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: AppInputStyle.decoration('Search country or code').copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final country = filtered[index];
                  final isSelected = country.isoCode == widget.selected.isoCode;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      country.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(country.isoCode),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country.dialCode,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded, color: AppColours.blue),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
