import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/google_place_models.dart';
import '../models/setup_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/east_logo.dart';
import '../widgets/google_place_picker.dart';
import '../widgets/phone_number_field.dart';

class InitialSetupScreen extends StatefulWidget {
  final EastAppApi api;
  final VoidCallback onCompleted;

  const InitialSetupScreen({
    super.key,
    required this.api,
    required this.onCompleted,
  });

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final setupCodeController = TextEditingController();
  final businessNameController = TextEditingController();
  final companyCodeController = TextEditingController();
  final employeePrefixController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  PhoneCountry phoneCountry = defaultPhoneCountry;
  bool submitting = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  EastAppGooglePlaceDetails? selectedPlace;

  @override
  void dispose() {
    setupCodeController.dispose();
    businessNameController.dispose();
    companyCodeController.dispose();
    employeePrefixController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> selectBusinessLocation() async {
    final result = await showGooglePlacePicker(
      context: context,
      api: widget.api,
      setupMode: true,
      initialQuery: businessNameController.text.trim(),
    );
    if (result == null || !mounted) return;
    setState(() => selectedPlace = result);
  }

  Future<void> completeSetup() async {
    final text = AppTextScope.of(context);
    FocusScope.of(context).unfocus();
    final setupCode = setupCodeController.text.trim().toUpperCase();
    final businessName = businessNameController.text.trim();
    final companyCode = companyCodeController.text.trim().toUpperCase();
    final employeePrefix = employeePrefixController.text.trim().toUpperCase();
    final fullName = fullNameController.text.trim();
    final phoneE164 = buildE164(phoneCountry, phoneController.text);
    final password = passwordController.text;
    final confirmation = confirmPasswordController.text;

    if ([
      setupCode,
      businessName,
      companyCode,
      employeePrefix,
      fullName,
      phoneController.text.trim(),
      password,
      confirmation,
    ].any((value) => value.isEmpty)) {
      showErrorSnackBar(context, text.t('Complete all fields.'));
      return;
    }
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{10}$').hasMatch(setupCode)) {
      showErrorSnackBar(
        context,
        text.t('Enter the 10-character setup code from the backend log.'),
      );
      return;
    }
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,31}$').hasMatch(companyCode)) {
      showErrorSnackBar(
        context,
        text.t('Company Code must contain 2–32 letters, numbers, _ or -.'),
      );
      return;
    }
    if (!RegExp(r'^[A-Z]{1,3}$').hasMatch(employeePrefix)) {
      showErrorSnackBar(
        context,
        text.t('Employee ID Prefix must contain 1–3 letters.'),
      );
      return;
    }
    if (selectedPlace == null) {
      showErrorSnackBar(
        context,
        text.t('Select the Google business location.'),
      );
      return;
    }
    if (!isValidE164(phoneE164)) {
      showErrorSnackBar(context, text.t('Enter a valid phone number.'));
      return;
    }
    if (password.length < 4) {
      showErrorSnackBar(
        context,
        text.t('Password must contain at least 4 characters.'),
      );
      return;
    }
    if (password != confirmation) {
      showErrorSnackBar(context, text.t('Passwords do not match.'));
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: 'Complete Initial Setup?',
      details:
          'This will create the first business and Owner account. The selected Google location will be used as the office reference for attendance distance.',
    );
    if (!confirmed || !mounted) return;

    setState(() => submitting = true);
    try {
      final result = await widget.api.completeInitialSetup(
        setupCode: setupCode,
        businessName: businessName,
        companyCode: companyCode,
        employeeIdPrefix: employeePrefix,
        fullName: fullName,
        phoneE164: phoneE164,
        password: password,
        googlePlaceId: selectedPlace!.placeId,
      );
      if (!mounted) return;
      await _showCreatedAccount(result);
      if (!mounted) return;
      widget.onCompleted();
    } on EastAppApiException catch (_) {
      // The global API error dialog contains the backend details.
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _showCreatedAccount(EastAppInitialSetupResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final text = AppTextScope.of(dialogContext);
        return AlertDialog(
          title: Text(text.t('Owner Account Created')),
          content: Text(
            '${result.businessName}\n'
            '${text.t('Company Code')}: ${result.companyCode}\n'
            '${text.t('Employee ID')}: ${result.employeeId}\n\n'
            '${text.t('Use the Company Code, Employee ID and password to sign in.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(text.t('Continue to Login')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
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
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColours.border),
                  ),
                  child: const EastLogo(
                    size: 64,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  text.t('Initial Setup'),
                  style: const TextStyle(
                    fontSize: AppTextSize.s30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.t(
                    'Create the first business and Owner account. Employee ID is generated automatically.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTextSize.s14,
                    color: AppColours.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                _SetupField(
                  label: 'Setup Code',
                  controller: setupCodeController,
                  hint: '10-character code',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Business Name',
                  controller: businessNameController,
                  hint: 'Example: The East',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Company Code',
                  controller: companyCodeController,
                  hint: 'Example: EAST',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Employee ID Prefix',
                  controller: employeePrefixController,
                  hint: 'Example: E',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                GooglePlaceSelectionCard(
                  place: selectedPlace,
                  onSelect: selectBusinessLocation,
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Full Name',
                  controller: fullNameController,
                  hint: 'Full name',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                PhoneNumberField(
                  label: 'Phone Number',
                  controller: phoneController,
                  country: phoneCountry,
                  onCountryChanged: (value) {
                    setState(() => phoneCountry = value);
                  },
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Password',
                  controller: passwordController,
                  hint: 'Create a password',
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SetupField(
                  label: 'Confirm Password',
                  controller: confirmPasswordController,
                  hint: 'Enter the password again',
                  obscureText: obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => completeSetup(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => obscureConfirmation = !obscureConfirmation,
                    ),
                    icon: Icon(
                      obscureConfirmation
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
                    onPressed: submitting ? null : completeSetup,
                    child: submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            text.t('Create Business & Owner'),
                            style: const TextStyle(
                              fontSize: AppTextSize.s18,
                              fontWeight: FontWeight.w700,
                            ),
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

class _SetupField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _SetupField({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.t(label), style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: AppTextStyles.formValue,
          decoration: AppInputStyle.decoration(
            text.t(hint),
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
