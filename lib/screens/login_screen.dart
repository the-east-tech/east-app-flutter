import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_text.dart';
import '../models/auth_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';
import '../widgets/phone_number_field.dart';

class LoginScreen extends StatefulWidget {
  final EastAppApi api;
  final Future<void> Function(EastAppSession session) onSignedIn;
  final AppLanguage initialLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;

  const LoginScreen({
    super.key,
    required this.api,
    required this.onSignedIn,
    required this.initialLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final companyCodeController = TextEditingController(text: 'EAST');
  final employeeIdController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  late AppLanguage language;
  bool signingIn = false;
  bool obscurePassword = true;
  PhoneCountry phoneCountry = defaultPhoneCountry;

  AppText get text => AppText(language);

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
  }

  @override
  void dispose() {
    companyCodeController.dispose();
    employeeIdController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    FocusScope.of(context).unfocus();
    final companyCode = companyCodeController.text.trim();
    final employeeId = employeeIdController.text.trim();
    final phone = buildE164(phoneCountry, phoneController.text);
    final password = passwordController.text;

    if (companyCode.isEmpty ||
        employeeId.isEmpty ||
        phoneController.text.trim().isEmpty ||
        password.isEmpty) {
      showErrorSnackBar(context, text.t('Complete all fields.'));
      return;
    }
    if (!isValidE164(phone)) {
      showErrorSnackBar(context, text.t('Enter a valid phone number.'));
      return;
    }

    setState(() => signingIn = true);
    try {
      final session = await widget.api.login(
        companyCode: companyCode,
        employeeId: employeeId,
        phoneE164: phone,
        password: password,
      );
      await widget.onSignedIn(session);
      AppFeedback.loginSuccess();
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = text;

    return Scaffold(
      backgroundColor: AppColours.blue,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 430,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _LanguageSwitch(
                    language: language,
                    onChanged: (value) {
                      setState(() => language = value);
                      widget.onLanguageChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.t("Nic's Kitchen"),
                  style: const TextStyle(
                    fontSize: AppTextSize.s34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _LoginField(
                  label: t.t('Company ID'),
                  controller: companyCodeController,
                  hint: 'EAST',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _LoginField(
                  label: t.t('Employee ID'),
                  controller: employeeIdController,
                  hint: 'E0001',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                PhoneNumberField(
                  label: t.t('Phone Number'),
                  controller: phoneController,
                  country: phoneCountry,
                  onCountryChanged: (value) {
                    setState(() => phoneCountry = value);
                  },
                  hint: '165076207',
                ),
                const SizedBox(height: 12),
                _LoginField(
                  label: t.t('Password'),
                  controller: passwordController,
                  hint: t.t('Enter your password'),
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => signIn(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColours.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: signingIn ? null : signIn,
                    child: signingIn
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            t.t('Sign In'),
                            style: const TextStyle(
                              fontSize: AppTextSize.s20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.api.baseUrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppTextSize.s10,
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
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  const _LanguageSwitch({
    required this.language,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      initialValue: language,
      onSelected: onChanged,
      itemBuilder: (context) => AppLanguage.values
          .map(
            (item) => PopupMenuItem<AppLanguage>(
              value: item,
              child: Text(item.displayName),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColours.mutedBox,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18),
            const SizedBox(width: 6),
            Text(
              language.shortLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _LoginField({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: AppTextStyles.formValue,
          decoration: AppInputStyle.decoration(
            hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ).copyWith(suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}
