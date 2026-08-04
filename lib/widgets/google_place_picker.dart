import 'dart:async';

import 'package:flutter/material.dart';

import '../models/google_place_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

Future<EastAppGooglePlaceDetails?> showGooglePlacePicker({
  required BuildContext context,
  required EastAppApi api,
  required bool setupMode,
  String initialQuery = '',
}) {
  return showModalBottomSheet<EastAppGooglePlaceDetails>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _GooglePlacePickerSheet(
      api: api,
      setupMode: setupMode,
      initialQuery: initialQuery,
    ),
  );
}

class GooglePlaceSelectionCard extends StatelessWidget {
  final EastAppGooglePlaceDetails? place;
  final VoidCallback onSelect;
  final String? errorText;
  final bool enabled;

  const GooglePlaceSelectionCard({
    super.key,
    required this.place,
    required this.onSelect,
    this.errorText,
    this.enabled = true,
  });


  String _googlePlacesErrorMessage(EastAppApiException apiError) {
    if (apiError.code == 'GOOGLE_PLACES_NOT_CONFIGURED') {
      return 'Google Business Location is required. Replace HARDCODED_API_KEY in GooglePlacesProperties.java, restart the backend, then search again.';
    }
    return apiError.message;
  }

  @override
  Widget build(BuildContext context) {
    final selected = place;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Google Business Location', style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onSelect : null,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enabled ? Colors.white : AppColours.mutedBox,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: errorText == null
                      ? AppColours.border
                      : const Color(0xFFC73500),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColours.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: selected == null
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Search and select the exact Google Maps listing',
                              style: TextStyle(
                                fontSize: AppTextSize.s14,
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.displayName,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selected.formattedAddress,
                                style: const TextStyle(
                                  fontSize: AppTextSize.s12,
                                  color: AppColours.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: AppTextSize.s12,
                                  color: AppColours.blue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected == null
                        ? Icons.search_rounded
                        : Icons.edit_location_alt_outlined,
                    color: AppColours.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: AppTextSize.s12,
              color: Color(0xFFC73500),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _GooglePlacePickerSheet extends StatefulWidget {
  final EastAppApi api;
  final bool setupMode;
  final String initialQuery;

  const _GooglePlacePickerSheet({
    required this.api,
    required this.setupMode,
    required this.initialQuery,
  });

  @override
  State<_GooglePlacePickerSheet> createState() =>
      _GooglePlacePickerSheetState();
}

class _GooglePlacePickerSheetState extends State<_GooglePlacePickerSheet> {
  final searchController = TextEditingController();
  Timer? debounce;
  List<EastAppGooglePlacePrediction> predictions = const [];
  bool searching = false;
  String? error;
  String? loadingPlaceId;

  @override
  void initState() {
    super.initState();
    searchController.text = widget.initialQuery.trim();
    if (searchController.text.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => search());
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void scheduleSearch(String value) {
    debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        predictions = const [];
        searching = false;
        error = null;
      });
      return;
    }
    debounce = Timer(const Duration(milliseconds: 350), search);
  }

  Future<void> search() async {
    final query = searchController.text.trim();
    if (query.length < 2) return;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final result = await widget.api.searchGooglePlaces(
        query: query,
        setupMode: widget.setupMode,
      );
      if (!mounted || searchController.text.trim() != query) return;
      setState(() {
        predictions = result;
        searching = false;
      });
    } on EastAppApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        error = _googlePlacesErrorMessage(apiError);
        predictions = const [];
        searching = false;
      });
    }
  }

  Future<void> select(EastAppGooglePlacePrediction prediction) async {
    setState(() {
      loadingPlaceId = prediction.placeId;
      error = null;
    });
    try {
      final details = await widget.api.googlePlaceDetails(
        placeId: prediction.placeId,
        setupMode: widget.setupMode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(details);
    } on EastAppApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        error = _googlePlacesErrorMessage(apiError);
        loadingPlaceId = null;
      });
    }
  }


  String _googlePlacesErrorMessage(EastAppApiException apiError) {
    if (apiError.code == 'GOOGLE_PLACES_NOT_CONFIGURED') {
      return 'Google Business Location is required. Replace HARDCODED_API_KEY in GooglePlacesProperties.java, restart the backend, then search again.';
    }
    return apiError.message;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
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
                const Expanded(
                  child: Text(
                    'Select Business Location',
                    style: TextStyle(
                      fontSize: AppTextSize.s24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              autofocus: widget.initialQuery.trim().isEmpty,
              textInputAction: TextInputAction.search,
              onChanged: scheduleSearch,
              onSubmitted: (_) => search(),
              decoration: AppInputStyle.decoration(
                'Search business name or address',
              ).copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFC73500),
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: predictions.isEmpty
                  ? Center(
                      child: Text(
                        searching
                            ? 'Searching Google Maps…'
                            : searchController.text.trim().length < 2
                                ? 'Type at least 2 characters.'
                                : 'No matching location found.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColours.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: predictions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = predictions[index];
                        final loading = loadingPlaceId == item.placeId;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          leading: const Icon(
                            Icons.place_outlined,
                            color: AppColours.blue,
                          ),
                          title: Text(
                            item.mainText.isEmpty
                                ? item.fullText
                                : item.mainText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: item.secondaryText.isEmpty
                              ? null
                              : Text(item.secondaryText),
                          trailing: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: loadingPlaceId == null
                              ? () => select(item)
                              : null,
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Center(
              child: Image.network(
                'https://maps.gstatic.com/mapfiles/api-3/images/powered-by-google-on-white3.png',
                height: 18,
                errorBuilder: (_, __, ___) => const Text(
                  'Google Maps',
                  style: TextStyle(
                    color: AppColours.textMuted,
                    fontSize: AppTextSize.s12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
