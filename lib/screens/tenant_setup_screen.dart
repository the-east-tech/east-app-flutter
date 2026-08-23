import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/auth_models.dart';
import '../models/google_place_models.dart';
import '../models/organisation_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';
import '../widgets/google_place_picker.dart';

class TenantSetupScreen extends StatefulWidget {
  final EastAppApi api;
  final bool isOwner;
  final EastAppTenant currentTenant;
  final Future<void> Function(EastAppSession context) onSwitchBusiness;
  final Future<void> Function(EastAppTenant tenant) onBusinessCreated;
  final VoidCallback onBack;

  const TenantSetupScreen({
    super.key,
    required this.api,
    required this.isOwner,
    required this.currentTenant,
    required this.onSwitchBusiness,
    required this.onBusinessCreated,
    required this.onBack,
  });

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  final searchController = TextEditingController();
  EastAppTenant? currentBusiness;
  List<EastAppSession> ownerContexts = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadBusinesses();
  }

  @override
  void didUpdateWidget(covariant TenantSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTenant.id != widget.currentTenant.id) {
      loadBusinesses();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadBusinesses() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        widget.api.listTenants(),
        widget.isOwner
            ? widget.api.availableContexts()
            : Future<List<EastAppSession>>.value(const <EastAppSession>[]),
      ]);
      final current = results[0] as List<EastAppTenant>;
      final contexts = results[1] as List<EastAppSession>;
      if (!mounted) return;
      setState(() {
        currentBusiness = current.isEmpty ? widget.currentTenant : current.first;
        ownerContexts = contexts;
        loading = false;
      });
    } on EastAppApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        error = apiError.message;
        loading = false;
      });
    }
  }

  List<EastAppSession> get filteredContexts {
    final query = searchController.text.trim().toLowerCase();
    final contexts = ownerContexts
        .where((item) => item.tenant.id != widget.currentTenant.id)
        .toList(growable: false);
    if (query.isEmpty) return contexts;
    return contexts.where((item) {
      final tenant = item.tenant;
      return tenant.businessName.toLowerCase().contains(query) ||
          tenant.companyCode.toLowerCase().contains(query) ||
          tenant.employeeIdPrefix.toLowerCase().contains(query) ||
          item.user.employeeId.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> openCreateBusiness() async {
    final created = await _showBusinessSheet();
    if (created == null || !mounted) return;
    await widget.onBusinessCreated(created);
  }

  Future<void> openEditCurrentBusiness() async {
    final tenant = currentBusiness ?? widget.currentTenant;
    final updated = await _showBusinessSheet(tenant: tenant);
    if (updated != null && mounted) {
      await loadBusinesses();
    }
  }

  Future<EastAppTenant?> _showBusinessSheet({EastAppTenant? tenant}) {
    return showModalBottomSheet<EastAppTenant>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _BusinessFormSheet(
        tenant: tenant,
        api: widget.api,
      ),
    );
  }


  String? employeeIdFor(String tenantId) {
    for (final item in ownerContexts) {
      if (item.tenant.id == tenantId) return item.user.employeeId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final current = currentBusiness ?? widget.currentTenant;
    final otherContexts = filteredContexts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: PageTitle(
                title: text.t('Business'),
                subtitle: text.t(
                  widget.isOwner
                      ? 'Edit this business, create a business or switch context'
                      : 'View and edit this business',
                ),
              ),
            ),
            if (widget.isOwner)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  onPressed: openCreateBusiness,
                  icon: const Icon(Icons.add_business_outlined),
                  label: Text(text.t('Create')),
                ),
              ),
          ],
        ),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          WhiteCard(
            child: Column(
              children: [
                Text(text.t(error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: text.t('Retry'),
                  icon: Icons.refresh_rounded,
                  onPressed: loadBusinesses,
                ),
              ],
            ),
          )
        else ...[
          Text(
            text.t('Business'),
            style: const TextStyle(
              fontSize: AppTextSize.s14,
              fontWeight: FontWeight.w800,
              color: AppColours.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _BusinessCard(
            tenant: current,
            employeeId: widget.isOwner ? employeeIdFor(current.id) : null,
            current: true,
            onTap: openEditCurrentBusiness,
          ),
          if (widget.isOwner) ...[
            const SizedBox(height: 18),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: AppInputStyle.decoration(
                text.t('Search other businesses'),
              ).copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text.t('Other Businesses'),
              style: const TextStyle(
                fontSize: AppTextSize.s14,
                fontWeight: FontWeight.w800,
                color: AppColours.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            if (otherContexts.isEmpty)
              WhiteCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    text.t('No other business context is assigned.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColours.textMuted),
                  ),
                ),
              )
            else
              ...otherContexts.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BusinessCard(
                    tenant: item.tenant,
                    employeeId: item.user.employeeId,
                    onTap: () => widget.onSwitchBusiness(item),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final EastAppTenant tenant;
  final String? employeeId;
  final bool current;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.tenant,
    required this.onTap,
    this.employeeId,
    this.current = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: current ? AppColours.greenSoft : AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  current ? Icons.check_circle_outline : Icons.business_outlined,
                  color: current ? AppColours.green : AppColours.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.businessName,
                      style: const TextStyle(
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        tenant.companyCode,
                        '${text.t('Prefix')} ${tenant.employeeIdPrefix}',
                        ?employeeId,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        fontWeight: FontWeight.w600,
                        color: AppColours.textMuted,
                      ),
                    ),
                    if (tenant.formattedAddress.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        tenant.formattedAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.s12,
                          color: AppColours.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                current ? Icons.edit_outlined : Icons.swap_horiz_rounded,
                color: AppColours.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessFormSheet extends StatefulWidget {
  final EastAppTenant? tenant;
  final EastAppApi api;

  const _BusinessFormSheet({
    required this.tenant,
    required this.api,
  });

  @override
  State<_BusinessFormSheet> createState() => _BusinessFormSheetState();
}

class _BusinessFormSheetState extends State<_BusinessFormSheet> {
  final businessNameController = TextEditingController();
  final companyCodeController = TextEditingController();
  final prefixController = TextEditingController();
  EastAppGooglePlaceDetails? selectedPlace;
  bool active = true;
  bool saving = false;
  bool showErrors = false;

  bool get isEditing => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    final tenant = widget.tenant;
    if (tenant == null) return;
    businessNameController.text = tenant.businessName;
    companyCodeController.text = tenant.companyCode;
    prefixController.text = tenant.employeeIdPrefix;
    active = tenant.active;
    selectedPlace = EastAppGooglePlaceDetails(
      placeId: tenant.googlePlaceId,
      displayName: tenant.googlePlaceName,
      formattedAddress: tenant.formattedAddress,
      latitude: tenant.latitude,
      longitude: tenant.longitude,
      googleMapsUri: tenant.googleMapsUri,
    );
  }

  @override
  void dispose() {
    businessNameController.dispose();
    companyCodeController.dispose();
    prefixController.dispose();
    super.dispose();
  }

  String? get businessNameError =>
      showErrors && businessNameController.text.trim().isEmpty
          ? 'Business Name required'
          : null;

  String? get companyCodeError {
    if (!showErrors || isEditing) return null;
    final value = companyCodeController.text.trim();
    if (value.isEmpty) return 'Company Code required';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{1,31}$').hasMatch(value)) {
      return 'Use 2–32 letters, numbers, _ or -';
    }
    return null;
  }

  String? get prefixError {
    if (!showErrors || isEditing) return null;
    final value = prefixController.text.trim();
    if (value.isEmpty) return 'Employee ID Prefix required';
    if (!RegExp(r'^[A-Za-z]{1,3}$').hasMatch(value)) {
      return 'Use 1–3 letters';
    }
    return null;
  }

  String? get locationError =>
      showErrors && selectedPlace == null ? 'Google business location required' : null;

  Future<void> selectBusinessLocation() async {
    final result = await showGooglePlacePicker(
      context: context,
      api: widget.api,
      setupMode: false,
      initialQuery: businessNameController.text.trim(),
    );
    if (result == null || !mounted) return;
    setState(() => selectedPlace = result);
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    setState(() => showErrors = true);
    if (businessNameError != null ||
        companyCodeError != null ||
        prefixError != null ||
        locationError != null) {
      AppFeedback.warning();
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: isEditing ? 'Update Business?' : 'Create Business?',
      details: isEditing
          ? 'This updates only this business.'
          : 'This creates a new isolated business, default roles and a separate Owner employee ID for every existing Owner.',
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      final EastAppTenant saved;
      if (isEditing) {
        saved = await widget.api.updateTenant(
          tenantId: widget.tenant!.id,
          businessName: businessNameController.text.trim(),
          active: active,
          googlePlaceId: selectedPlace!.placeId,
        );
      } else {
        saved = await widget.api.createTenant(
          businessName: businessNameController.text.trim(),
          companyCode: companyCodeController.text.trim().toUpperCase(),
          employeeIdPrefix: prefixController.text.trim().toUpperCase(),
          googlePlaceId: selectedPlace!.placeId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on EastAppApiException catch (_) {
      // Global API error dialog contains the backend detail.
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColours.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    text.t(isEditing ? 'Edit Business' : 'Create Business'),
                    style: const TextStyle(
                      fontSize: AppTextSize.s26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BusinessInput(
              label: 'Business Name',
              controller: businessNameController,
              hint: 'Example: June Coffee',
              errorText: businessNameError,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (showErrors) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            _BusinessInput(
              label: 'Company Code',
              controller: companyCodeController,
              hint: 'Example: JUNE',
              enabled: !isEditing,
              errorText: companyCodeError,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (showErrors) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            _BusinessInput(
              label: 'Employee ID Prefix',
              controller: prefixController,
              hint: 'Example: J',
              enabled: !isEditing,
              errorText: prefixError,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (showErrors) setState(() {});
              },
            ),
            const SizedBox(height: 6),
            Text(
              text.t(
                'Company Code and Employee ID Prefix cannot change after creation.',
              ),
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GooglePlaceSelectionCard(
              place: selectedPlace,
              onSelect: selectBusinessLocation,
              errorText: locationError,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              text: text.t(
                saving
                    ? 'Saving...'
                    : isEditing
                        ? 'Save Changes'
                        : 'Create Business',
              ),
              icon: Icons.save_outlined,
              onPressed: saving ? null : save,
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final String? errorText;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const _BusinessInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.errorText,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
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
          enabled: enabled,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          decoration: AppInputStyle.decoration(text.t(hint)).copyWith(
            errorText: errorText == null ? null : text.t(errorText!),
          ),
        ),
      ],
    );
  }
}
