import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../models/attendance_models.dart';
import '../models/google_place_models.dart';
import '../models/knowledge_api_models.dart';
import '../models/api_models.dart';
import '../models/advertisement_models.dart';
import '../models/auth_models.dart';
import '../models/daily_task_models.dart';
import '../models/organisation_models.dart';
import '../models/people_models.dart';
import '../models/points_models.dart';
import '../models/report_models.dart';
import '../models/setup_models.dart';
import '../models/stock_api_models.dart';
import '../models/app_models.dart';
import '../models/translation_models.dart';
import 'api_configuration.dart';
import 'feature_data_cache.dart';
import '../utils/app_diagnostics.dart';

class EastAppApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;
  final String? method;
  final String? path;
  final int? durationMs;
  final String? responseExcerpt;

  const EastAppApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
    this.method,
    this.path,
    this.durationMs,
    this.responseExcerpt,
  });

  bool get isUnauthorised => statusCode == 401;

  bool get invalidatesSession => isUnauthorised && const {
        'INVALID_SESSION',
        'UNAUTHENTICATED',
        'MISSING_SESSION',
        'SESSION_EXPIRED',
        'SESSION_REVOKED',
      }.contains(code);

  String get technicalDetails {
    final lines = <String>[
      if (method != null || path != null)
        'Request: ${method ?? '-'} ${path ?? '-'}',
      if (durationMs != null) 'Duration: ${durationMs}ms',
      'Status: ${statusCode?.toString() ?? 'No HTTP response'}',
      'Code: $code',
      'Message: $message',
      if (fieldErrors.isNotEmpty) ...[
        'Field errors:',
        ...fieldErrors.entries.map((entry) => '- ${entry.key}: ${entry.value}'),
      ],
      if (responseExcerpt != null && responseExcerpt!.trim().isNotEmpty)
        'Response: ${responseExcerpt!.trim()}',
    ];
    final value = lines.join('\n').trim();
    const maxLength = 1800;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength - 3)}...';
  }

  @override
  String toString() => message;
}

class EastAppApi {
  final http.Client _client;
  final String baseUrl;
  String? _token;
  Future<void> Function()? onSessionInvalidated;
  void Function(EastAppApiException error)? onApiError;
  void Function(bool isProcessing)? onProcessingChanged;

  int _processingRequestCount = 0;
  TranslationDirection? _translationDirection;
  Future<TranslationPreview>? _translationPreviewRequest;
  Future<void>? _contentTranslationRequest;
  final Map<String, String> _contentTranslations = <String, String>{};
  final Set<String> _knownContent = <String>{};
  final Map<String, Future<Object?>> _featureReadRequests =
      <String, Future<Object?>>{};
  final Map<String, int> _featureCacheRevisions = <String, int>{};
  int _featureCacheEpoch = 0;
  final LinkedHashMap<String, Uint8List> _mediaBytesCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> _mediaBytesRequests =
      <String, Future<Uint8List>>{};
  int _mediaBytesCacheSize = 0;
  int _mediaBytesCacheGeneration = 0;
  final _availableContextsCache = _AsyncMemoryCache<List<EastAppSession>>(
    ttl: const Duration(minutes: 5),
  );
  final _tenantsCache = _AsyncMemoryCache<List<EastAppTenant>>(
    ttl: const Duration(minutes: 5),
  );
  final Map<String, _DailyTaskMemoryValue<DailyTaskList>>
      _dailyTaskRecordCache = <String, _DailyTaskMemoryValue<DailyTaskList>>{};
  final Map<String, Future<DailyTaskList>> _dailyTaskRecordRequests =
      <String, Future<DailyTaskList>>{};
  final Map<String, List<DailyTaskTemplate>> _dailyTaskTemplateCache =
      <String, List<DailyTaskTemplate>>{};
  final Map<String, Future<List<DailyTaskTemplate>>>
      _dailyTaskTemplateRequests =
      <String, Future<List<DailyTaskTemplate>>>{};
  int _dailyTaskRecordCacheGeneration = 0;
  int _dailyTaskTemplateCacheGeneration = 0;

  static const Duration _requestTimeout = Duration(seconds: 15);

  EastAppApi({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfiguration.baseUrl;

  String? get token => _token;

  TranslationDirection? get translationDirection => _translationDirection;

  Map<String, String> get contentTranslations =>
      UnmodifiableMapView<String, String>(_contentTranslations);

  static String reportDashboardCacheKey(String tenantId, int days) =>
      'tenant:$tenantId:report:dashboard:v2:$days';
  static String salesHistoryCacheKey(
    String tenantId,
    DateTime from,
    DateTime to,
  ) =>
      'tenant:$tenantId:report:sales-history:${formatApiDate(from)}:${formatApiDate(to)}';
  static String wasteHistoryCacheKey(
    String tenantId,
    DateTime from,
    DateTime to,
  ) =>
      'tenant:$tenantId:report:waste-history:${formatApiDate(from)}:${formatApiDate(to)}';
  static String complaintHistoryCacheKey(
    String tenantId,
    DateTime from,
    DateTime to,
  ) =>
      'tenant:$tenantId:report:complaint-history:${formatApiDate(from)}:${formatApiDate(to)}';
  static String stockTagsCachePrefix(String tenantId) =>
      'tenant:$tenantId:setup:stock-tags:';
  static String stockSuppliersCachePrefix(String tenantId) =>
      'tenant:$tenantId:setup:stock-suppliers:';
  static String stockSkusCachePrefix(String tenantId) =>
      'tenant:$tenantId:setup:stock-skus:';
  static String usersCachePrefix(String tenantId) =>
      'tenant:$tenantId:setup:users:';
  static String rolesCachePrefix(String tenantId) =>
      'tenant:$tenantId:setup:roles:';
  static String advertisementFeedCacheKey(String tenantId) =>
      'tenant:$tenantId:home:advertisements:active:v1';
  static String dailyTaskRecordsCachePrefix(String tenantId) =>
      'tenant:$tenantId:daily-tasks:records:';
  static String dailyTaskTemplatesCacheKey(String tenantId) =>
      'tenant:$tenantId:daily-tasks:templates';

  DateTime? featureCacheUpdatedAt(String cacheKey) =>
      FeatureDataCache.instance.updatedAt(cacheKey);

  Future<void> invalidateFeatureCache(String keyPrefix) async {
    _featureCacheEpoch += 1;
    final matchingKeys = <String>{
      ..._featureCacheRevisions.keys.where((key) => key.startsWith(keyPrefix)),
      ..._featureReadRequests.keys.where((key) => key.startsWith(keyPrefix)),
    };
    for (final key in matchingKeys) {
      _featureCacheRevisions[key] = (_featureCacheRevisions[key] ?? 0) + 1;
    }
    _featureReadRequests.removeWhere((key, _) => key.startsWith(keyPrefix));
    await FeatureDataCache.instance.removeByPrefix(keyPrefix);
  }

  Future<void> clearFeatureCaches() async {
    _featureCacheEpoch += 1;
    _featureCacheRevisions.clear();
    _featureReadRequests.clear();
    _clearMediaBytesCache();
    await FeatureDataCache.instance.clearAll();
  }

  void invalidateDailyTaskRecords(String tenantId) {
    final prefix = dailyTaskRecordsCachePrefix(tenantId);
    _dailyTaskRecordCacheGeneration += 1;
    _dailyTaskRecordCache.removeWhere((key, _) => key.startsWith(prefix));
    _dailyTaskRecordRequests.removeWhere((key, _) => key.startsWith(prefix));
  }

  void invalidateDailyTaskTemplates(String tenantId) {
    final key = dailyTaskTemplatesCacheKey(tenantId);
    _dailyTaskTemplateCacheGeneration += 1;
    _dailyTaskTemplateCache.remove(key);
    _dailyTaskTemplateRequests.remove(key);
  }

  void _clearDailyTaskMemoryCaches() {
    _dailyTaskRecordCacheGeneration += 1;
    _dailyTaskTemplateCacheGeneration += 1;
    _dailyTaskRecordCache.clear();
    _dailyTaskRecordRequests.clear();
    _dailyTaskTemplateCache.clear();
    _dailyTaskTemplateRequests.clear();
  }

  void _clearMediaBytesCache() {
    _mediaBytesCacheGeneration += 1;
    _mediaBytesCache.clear();
    _mediaBytesRequests.clear();
    _mediaBytesCacheSize = 0;
  }

  void useToken(String? token) {
    if (_token != token) {
      _featureCacheEpoch += 1;
      _featureReadRequests.clear();
      invalidateAvailableContextsCache();
      invalidateTenantsCache();
      _clearContentTranslation();
      _clearDailyTaskMemoryCaches();
      _clearMediaBytesCache();
    }
    _token = token;
  }

  Future<TranslationPreview> previewContentTranslation(
    TranslationDirection direction,
  ) {
    final existing = _translationPreviewRequest;
    if (existing != null) return existing;

    late final Future<TranslationPreview> request;
    request = _previewContentTranslation(direction).whenComplete(() {
      if (identical(_translationPreviewRequest, request)) {
        _translationPreviewRequest = null;
      }
    });
    _translationPreviewRequest = request;
    return request;
  }

  Future<TranslationPreview> _previewContentTranslation(
    TranslationDirection direction,
  ) async {
    final pending = _contentForDirection(direction);
    if (pending.isEmpty) return TranslationPreview.empty;

    TranslationPreview? combined;
    const batchSize = 100;
    for (var offset = 0; offset < pending.length; offset += batchSize) {
      final end = offset + batchSize < pending.length
          ? offset + batchSize
          : pending.length;
      final body = await _requestJson(
        'POST',
        '/api/v1/translations/preview',
        body: {
          'sourceLanguage': direction.source.apiValue,
          'targetLanguage': direction.target.apiValue,
          'texts': pending.sublist(offset, end),
        },
        observeContent: false,
      ) as Map<String, dynamic>;
      final preview = TranslationPreview.fromJson(body);
      combined = combined == null ? preview : combined.merge(preview);
    }
    return combined ?? TranslationPreview.empty;
  }

  Future<void> setContentTranslation(
    TranslationDirection? direction,
  ) {
    final existing = _contentTranslationRequest;
    if (existing != null) return existing;

    late final Future<void> request;
    request = _setContentTranslation(direction).whenComplete(() {
      if (identical(_contentTranslationRequest, request)) {
        _contentTranslationRequest = null;
      }
    });
    _contentTranslationRequest = request;
    return request;
  }

  Future<void> _setContentTranslation(
    TranslationDirection? direction,
  ) async {
    if (direction == null) {
      _translationDirection = null;
      _contentTranslations.clear();
      return;
    }

    final previousDirection = _translationDirection;
    final previousTranslations = Map<String, String>.of(_contentTranslations);
    _translationDirection = direction;
    _contentTranslations.clear();
    try {
      final translated = await _translateTexts(
        _knownContent.where(direction.source.matches).toList(growable: false),
        direction,
      );
      _contentTranslations.addAll(translated);
    } catch (_) {
      _translationDirection = previousDirection;
      _contentTranslations
        ..clear()
        ..addAll(previousTranslations);
      rethrow;
    }
  }

  void _clearContentTranslation() {
    _translationDirection = null;
    _contentTranslations.clear();
    _knownContent.clear();
  }

  void invalidateAvailableContextsCache() {
    _availableContextsCache.invalidate();
  }

  void invalidateTenantsCache() {
    _tenantsCache.invalidate();
  }

  Future<EastAppSetupStatus> setupStatus() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/setup/status',
      authenticated: false,
    ) as Map<String, dynamic>;
    return EastAppSetupStatus.fromJson(body);
  }

  Future<EastAppInitialSetupResult> completeInitialSetup({
    required String setupCode,
    required String businessName,
    required String companyCode,
    required String employeeIdPrefix,
    required String fullName,
    required String phoneE164,
    required String password,
    required String googlePlaceId,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/setup/owner',
      authenticated: false,
      body: {
        'setupCode': setupCode,
        'businessName': businessName,
        'companyCode': companyCode,
        'employeeIdPrefix': employeeIdPrefix,
        'fullName': fullName,
        'phoneE164': phoneE164,
        'password': password,
        'googlePlaceId': googlePlaceId,
      },
    ) as Map<String, dynamic>;
    return EastAppInitialSetupResult.fromJson(body);
  }

  Future<EastAppSession> login({
    required String companyCode,
    required String employeeId,
    required String password,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/auth/login',
      authenticated: false,
      body: {
        'companyCode': companyCode,
        'employeeId': employeeId,
        'password': password,
      },
    ) as Map<String, dynamic>;

    final token = body['token'] as String;
    final currentUser = body['currentUser'] as Map<String, dynamic>;
    useToken(token);
    return EastAppSession(
      token: token,
      tenant: EastAppTenant.fromJson(
        currentUser['tenant'] as Map<String, dynamic>,
      ),
      user: EastAppUser.fromJson(
        currentUser['user'] as Map<String, dynamic>,
      ),
    );
  }

  Future<EastAppSession> currentSession(String token) async {
    useToken(token);
    final body = await _requestJson(
      'GET',
      '/api/v1/auth/me',
      notifyOnUnauthorised: false,
    ) as Map<String, dynamic>;
    return EastAppSession(
      token: token,
      tenant: EastAppTenant.fromJson(body['tenant'] as Map<String, dynamic>),
      user: EastAppUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    await _requestJson('POST', '/api/v1/auth/logout', expectBody: false);
    useToken(null);
  }

  Future<List<EastAppSession>> availableContexts({
    bool forceRefresh = false,
  }) {
    return _availableContextsCache.getOrLoad(
      _loadAvailableContexts,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<EastAppSession>> _loadAvailableContexts() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/auth/contexts',
    ) as List<dynamic>;
    return body.map((item) {
      final context = item as Map<String, dynamic>;
      return EastAppSession(
        token: _token ?? '',
        tenant: EastAppTenant.fromJson(
          context['tenant'] as Map<String, dynamic>,
        ),
        user: EastAppUser.fromJson(
          context['user'] as Map<String, dynamic>,
        ),
      );
    }).toList(growable: false);
  }

  Future<EastAppSession> switchContext(String userId) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/auth/context',
      body: {'userId': userId},
    ) as Map<String, dynamic>;
    await clearFeatureCaches();
    invalidateAvailableContextsCache();
    invalidateTenantsCache();
    _clearContentTranslation();
    _clearDailyTaskMemoryCaches();
    return EastAppSession(
      token: _token ?? '',
      tenant: EastAppTenant.fromJson(body['tenant'] as Map<String, dynamic>),
      user: EastAppUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<List<EastAppTenant>> listTenants({
    bool forceRefresh = false,
  }) {
    return _tenantsCache.getOrLoad(
      _loadTenants,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<EastAppTenant>> _loadTenants() async {
    final body = await _requestJson('GET', '/api/v1/tenants') as List<dynamic>;
    return body
        .map((item) => EastAppTenant.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<EastAppTenant> createTenant({
    required String businessName,
    required String companyCode,
    required String employeeIdPrefix,
    required String googlePlaceId,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/tenants',
      body: {
        'businessName': businessName,
        'companyCode': companyCode,
        'employeeIdPrefix': employeeIdPrefix,
        'googlePlaceId': googlePlaceId,
      },
    ) as Map<String, dynamic>;
    invalidateAvailableContextsCache();
    invalidateTenantsCache();
    return EastAppTenant.fromJson(body);
  }

  Future<EastAppTenant> updateTenant({
    required String tenantId,
    required String businessName,
    required bool active,
    required String googlePlaceId,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/tenants/$tenantId',
      body: {
        'businessName': businessName,
        'active': active,
        'googlePlaceId': googlePlaceId,
      },
    ) as Map<String, dynamic>;
    invalidateAvailableContextsCache();
    invalidateTenantsCache();
    return EastAppTenant.fromJson(body);
  }

  Future<List<EastAppGooglePlacePrediction>> searchGooglePlaces({
    required String query,
    required bool setupMode,
  }) async {
    final queryString = Uri(queryParameters: {'query': query.trim()}).query;
    final path = setupMode
        ? '/api/v1/setup/google-places/autocomplete?$queryString'
        : '/api/v1/google-places/autocomplete?$queryString';
    final body = await _requestJson(
      'GET',
      path,
      authenticated: !setupMode,
      reportError: false,
    ) as List<dynamic>;
    return body
        .map((item) => EastAppGooglePlacePrediction.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  Future<EastAppGooglePlaceDetails> googlePlaceDetails({
    required String placeId,
    required bool setupMode,
  }) async {
    final encoded = Uri.encodeComponent(placeId);
    final path = setupMode
        ? '/api/v1/setup/google-places/$encoded'
        : '/api/v1/google-places/details/$encoded';
    final body = await _requestJson(
      'GET',
      path,
      authenticated: !setupMode,
      reportError: false,
    ) as Map<String, dynamic>;
    return EastAppGooglePlaceDetails.fromJson(body);
  }

  Future<EastAppGoogleRating> currentGoogleRating() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/google-places/current-rating',
      reportError: false,
    ) as Map<String, dynamic>;
    return EastAppGoogleRating.fromJson(body);
  }

  Future<EastAppLeaderboard> pointsLeaderboard() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/points/leaderboard',
    ) as Map<String, dynamic>;
    return EastAppLeaderboard.fromJson(body);
  }

  Future<EastAppPointAdjustment> adjustUserPoints({
    required String userId,
    required int pointsDelta,
    required String reason,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/points/adjustments',
      body: {
        'userId': userId,
        'pointsDelta': pointsDelta,
        'reason': reason.trim(),
      },
    ) as Map<String, dynamic>;
    return EastAppPointAdjustment.fromJson(body);
  }


  String reportMediaUrl(String storageKey) {
    final encodedKey = Uri.encodeComponent(storageKey);
    return '$baseUrl/api/v1/reports/media/$encodedKey';
  }

  Map<String, String> get authenticatedImageHeaders {
    final token = _token;
    return token == null || token.isEmpty
        ? const {}
        : {'Authorization': 'Bearer $token'};
  }

  Future<AdvertisementFeed> advertisementFeed({
    required String tenantId,
    bool forceRefresh = false,
  }) async {
    const path = '/api/v1/advertisements/active';
    final body = await _requestCachedJson(
      path,
      cacheKey: advertisementFeedCacheKey(tenantId),
      forceRefresh: forceRefresh,
    ) as Map<String, dynamic>;
    return AdvertisementFeed.fromJson(body);
  }

  Future<List<Advertisement>> advertisements() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/advertisements',
    ) as List<dynamic>;
    return body
        .map(
          (item) => Advertisement.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<Advertisement> createAdvertisement({
    required String imageStorageKey,
    required DateTime startsAt,
    required DateTime endsAt,
    required int displayOrder,
    required bool active,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/advertisements',
      body: {
        'imageStorageKey': imageStorageKey,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'displayOrder': displayOrder,
        'active': active,
      },
    ) as Map<String, dynamic>;
    return Advertisement.fromJson(body);
  }

  Future<Advertisement> updateAdvertisement({
    required String id,
    required String imageStorageKey,
    required DateTime startsAt,
    required DateTime endsAt,
    required int displayOrder,
    required bool active,
  }) async {
    final body = await _requestJson(
      'PUT',
      '/api/v1/advertisements/$id',
      body: {
        'imageStorageKey': imageStorageKey,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'displayOrder': displayOrder,
        'active': active,
      },
    ) as Map<String, dynamic>;
    return Advertisement.fromJson(body);
  }

  Future<void> deleteAdvertisement(String id) async {
    await _requestJson(
      'DELETE',
      '/api/v1/advertisements/$id',
      expectBody: false,
    );
  }

  Future<ReportDashboard> reportDashboard({
    int days = 7,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {'days': '$days'}).query;
    final path = '/api/v1/reports/dashboard?$query';
    final body = tenantId == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: reportDashboardCacheKey(tenantId, days),
            forceRefresh: forceRefresh,
          );
    return ReportDashboard.fromJson(body as Map<String, dynamic>);
  }

  Future<ReportDashboard?> cachedReportDashboard({
    int days = 7,
    required String tenantId,
  }) async {
    final cacheKey = reportDashboardCacheKey(tenantId, days);
    final cached = await FeatureDataCache.instance.read(cacheKey);
    final data = cached?.data;
    if (data == null) {
      AppDiagnostics.instance.log('Cache-only miss · $cacheKey');
      return null;
    }
    if (data is! Map<String, dynamic>) {
      await FeatureDataCache.instance.remove(cacheKey);
      AppDiagnostics.instance.log('Cache-only invalid · $cacheKey');
      return null;
    }
    AppDiagnostics.instance.log('Cache-only hit · $cacheKey');
    return ReportDashboard.fromJson(data);
  }

  Future<List<SalesReport>> salesHistory({
    required DateTime from,
    required DateTime to,
    required String tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(
      queryParameters: {
        'from': formatApiDate(from),
        'to': formatApiDate(to),
      },
    ).query;
    final path = '/api/v1/reports/sales/history?$query';
    final body = await _requestCachedJson(
      path,
      cacheKey: salesHistoryCacheKey(tenantId, from, to),
      forceRefresh: forceRefresh,
    ) as List<dynamic>;
    return body
        .map((item) => SalesReport.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SalesReport> salesReport(DateTime date) async {
    final query = Uri(queryParameters: {'date': formatApiDate(date)}).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/reports/sales?$query',
    ) as Map<String, dynamic>;
    return SalesReport.fromJson(body);
  }

  Future<SalesReport> upsertSalesReport({
    required DateTime reportDate,
    required double cashTotalRm,
    required String cashReceivedBy,
    required double foodDeliverySalesRm,
    required double ewalletTotalRm,
    required int staffOnDuty,
  }) async {
    final body = await _requestJson(
      'PUT',
      '/api/v1/reports/sales',
      body: {
        'reportDate': formatApiDate(reportDate),
        'cashTotalRm': cashTotalRm,
        'cashReceivedBy': cashReceivedBy.trim(),
        'foodDeliverySalesRm': foodDeliverySalesRm,
        'ewalletTotalRm': ewalletTotalRm,
        'staffOnDuty': staffOnDuty,
      },
    ) as Map<String, dynamic>;
    return SalesReport.fromJson(body);
  }

  Future<VoidBill> addSalesVoidBill({
    required DateTime reportDate,
    required String billNumber,
    required String reason,
    required double amountRm,
    required String photoStorageKey,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/sales/void-bills',
      body: {
        'reportDate': formatApiDate(reportDate),
        'billNumber': billNumber.trim(),
        'reason': reason.trim(),
        'amountRm': amountRm,
        'photoStorageKey': photoStorageKey,
      },
    ) as Map<String, dynamic>;
    return VoidBill.fromJson(body);
  }

  Future<SalesReport> submitSalesReportDirect({
    required DateTime reportDate,
    required double cashTotalRm,
    required String cashReceivedBy,
    required double foodDeliverySalesRm,
    required double ewalletTotalRm,
    required int staffOnDuty,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/sales/submit',
      body: {
        'reportDate': formatApiDate(reportDate),
        'cashTotalRm': cashTotalRm,
        'cashReceivedBy': cashReceivedBy.trim(),
        'foodDeliverySalesRm': foodDeliverySalesRm,
        'ewalletTotalRm': ewalletTotalRm,
        'staffOnDuty': staffOnDuty,
      },
    ) as Map<String, dynamic>;
    return SalesReport.fromJson(body);
  }

  Future<SalesReport> submitSalesReport(String reportId) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/sales/$reportId/submit',
    ) as Map<String, dynamic>;
    return SalesReport.fromJson(body);
  }

  Future<WasteReport> createWasteReport({
    required DateTime reportDate,
    String? skuId,
    required String itemName,
    required double quantity,
    required String unit,
    required double estimatedUnitCostRm,
    required String reason,
    required String photoStorageKey,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/waste',
      body: {
        'reportDate': formatApiDate(reportDate),
        'skuId': skuId,
        'itemName': itemName.trim(),
        'quantity': quantity,
        'unit': unit.trim(),
        'estimatedUnitCostRm': estimatedUnitCostRm,
        'reason': reason.trim(),
        'photoStorageKey': photoStorageKey,
      },
    ) as Map<String, dynamic>;
    return WasteReport.fromJson(body);
  }

  Future<List<WasteReport>> wasteReports({
    required DateTime from,
    required DateTime to,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      'from': formatApiDate(from),
      'to': formatApiDate(to),
    }).query;
    final path = '/api/v1/reports/waste?$query';
    final body = (tenantId == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: wasteHistoryCacheKey(tenantId, from, to),
            forceRefresh: forceRefresh,
          )) as List<dynamic>;
    return body
        .map((item) => WasteReport.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<DailyPhotoReport> dailyPhotoReport({
    required DateTime date,
    String? userId,
  }) async {
    final query = Uri(queryParameters: {
      'date': formatApiDate(date),
      'userId': ?userId,
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/reports/daily-photos?$query',
    ) as Map<String, dynamic>;
    return DailyPhotoReport.fromJson(body);
  }

  Future<DailyPhotoReport> addDailyPhoto({
    required DateTime reportDate,
    required String photoStorageKey,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/daily-photos',
      body: {
        'reportDate': formatApiDate(reportDate),
        'photoStorageKey': photoStorageKey,
      },
    ) as Map<String, dynamic>;
    return DailyPhotoReport.fromJson(body);
  }

  Future<DailyPhotoReport> submitDailyPhotoReport(String reportId) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/daily-photos/$reportId/submit',
    ) as Map<String, dynamic>;
    return DailyPhotoReport.fromJson(body);
  }

  Future<List<DailyTaskTemplate>> dailyTaskTemplates({
    required String tenantId,
    bool forceRefresh = false,
  }) {
    final cacheKey = dailyTaskTemplatesCacheKey(tenantId);
    if (forceRefresh) {
      _dailyTaskTemplateCacheGeneration += 1;
      _dailyTaskTemplateCache.remove(cacheKey);
    } else {
      final cached = _dailyTaskTemplateCache[cacheKey];
      if (cached != null) return Future.value(cached);
      final existing = _dailyTaskTemplateRequests[cacheKey];
      if (existing != null) return existing;
    }

    final generation = _dailyTaskTemplateCacheGeneration;
    late final Future<List<DailyTaskTemplate>> request;
    request = (() async {
      final body = await _requestJson(
        'GET',
        '/api/v1/daily-tasks/templates',
      ) as List<dynamic>;
      final loaded = body
          .map(
            (item) =>
                DailyTaskTemplate.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
      if (generation == _dailyTaskTemplateCacheGeneration) {
        _dailyTaskTemplateCache[cacheKey] = loaded;
      }
      return loaded;
    })();
    _dailyTaskTemplateRequests[cacheKey] = request;
    return request.whenComplete(() {
      if (identical(_dailyTaskTemplateRequests[cacheKey], request)) {
        _dailyTaskTemplateRequests.remove(cacheKey);
      }
    });
  }

  Future<DailyTaskTemplate> createDailyTaskTemplate({
    required String tenantId,
    required String title,
    required String instruction,
    required String tagId,
    required int requiredPhotoCount,
    required List<String> checklistItems,
    required bool active,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/daily-tasks/templates',
      body: {
        'title': title.trim(),
        'instruction': instruction.trim(),
        'tagId': tagId,
        'requiredPhotoCount': requiredPhotoCount,
        'checklistItems': checklistItems
            .map((item) => item.trim())
            .toList(growable: false),
        'active': active,
      },
    ) as Map<String, dynamic>;
    final created = DailyTaskTemplate.fromJson(body);
    invalidateDailyTaskTemplates(tenantId);
    invalidateDailyTaskRecords(tenantId);
    return created;
  }

  Future<DailyTaskTemplate> updateDailyTaskTemplate({
    required String tenantId,
    required String templateId,
    required String title,
    required String instruction,
    required String tagId,
    required int requiredPhotoCount,
    required List<String> checklistItems,
    required bool active,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/daily-tasks/templates/$templateId',
      body: {
        'title': title.trim(),
        'instruction': instruction.trim(),
        'tagId': tagId,
        'requiredPhotoCount': requiredPhotoCount,
        'checklistItems': checklistItems
            .map((item) => item.trim())
            .toList(growable: false),
        'active': active,
      },
    ) as Map<String, dynamic>;
    final updated = DailyTaskTemplate.fromJson(body);
    invalidateDailyTaskTemplates(tenantId);
    invalidateDailyTaskRecords(tenantId);
    return updated;
  }

  Future<DailyTaskList> dailyTaskRecords({
    required String tenantId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? tagId,
    DailyTaskStatus? status,
    bool submittedByMe = false,
    bool forceRefresh = false,
  }) {
    final query = Uri(
      queryParameters: {
        'dateFrom': formatApiDate(dateFrom),
        'dateTo': formatApiDate(dateTo),
        if (tagId != null && tagId.isNotEmpty) 'tagId': tagId,
        if (status != null) 'status': status.apiValue,
        'submittedByMe': submittedByMe.toString(),
      },
    ).query;
    final cacheKey = '${dailyTaskRecordsCachePrefix(tenantId)}$query';
    final dayKey = _localDayKey();
    if (forceRefresh) {
      _dailyTaskRecordCacheGeneration += 1;
      _dailyTaskRecordCache.remove(cacheKey);
    } else {
      final cached = _dailyTaskRecordCache[cacheKey];
      if (cached != null && cached.dayKey == dayKey) {
        return Future.value(cached.value);
      }
      if (cached != null) _dailyTaskRecordCache.remove(cacheKey);
      final existing = _dailyTaskRecordRequests[cacheKey];
      if (existing != null) return existing;
    }

    final generation = _dailyTaskRecordCacheGeneration;
    late final Future<DailyTaskList> request;
    request = (() async {
      final body = await _requestJson(
        'GET',
        '/api/v1/daily-tasks/records?$query',
      ) as Map<String, dynamic>;
      final loaded = DailyTaskList.fromJson(body);
      if (generation == _dailyTaskRecordCacheGeneration) {
        _dailyTaskRecordCache[cacheKey] = _DailyTaskMemoryValue(
          value: loaded,
          dayKey: _localDayKey(),
        );
      }
      return loaded;
    })();
    _dailyTaskRecordRequests[cacheKey] = request;
    return request.whenComplete(() {
      if (identical(_dailyTaskRecordRequests[cacheKey], request)) {
        _dailyTaskRecordRequests.remove(cacheKey);
      }
    });
  }

  Future<DailyTaskRecord> dailyTaskRecord(String recordId) async {
    final body = await _requestJson(
      'GET',
      '/api/v1/daily-tasks/records/$recordId',
    ) as Map<String, dynamic>;
    return DailyTaskRecord.fromJson(body);
  }

  Future<DailyTaskRecord> submitDailyTask({
    required String recordId,
    required List<String> completedChecklistItemIds,
    required List<String> photoPaths,
  }) async {
    _beginProcessingRequest();
    final stopwatch = Stopwatch()..start();
    const method = 'POST';
    final path = '/api/v1/daily-tasks/records/$recordId/submit';
    try {
      final token = _token;
      if (token == null || token.isEmpty) {
        final error = EastAppApiException(
          statusCode: 401,
          code: 'MISSING_SESSION',
          message: 'Login required.',
          method: method,
          path: path,
        );
        _reportApiError(error);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
        throw error;
      }

      final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['completedChecklistItemIds'] =
            completedChecklistItemIds.join(',');
      try {
        for (final photoPath in photoPaths) {
          request.files.add(
            await http.MultipartFile.fromPath('photos', photoPath),
          );
        }
      } on Exception catch (exception) {
        final error = EastAppApiException(
          statusCode: null,
          code: 'DAILY_TASK_PHOTO_READ_FAILED',
          message: 'Unable to read a selected Daily Task photo: $exception',
          method: method,
          path: path,
        );
        _reportApiError(error);
        throw error;
      }

      late http.Response response;
      try {
        final streamed = await _client
            .send(request)
            .timeout(const Duration(minutes: 3));
        response = await http.Response.fromStream(streamed);
      } on TimeoutException {
        final error = EastAppApiException(
          statusCode: null,
          code: 'REQUEST_TIMEOUT',
          message: 'The Daily Task submission did not finish within 3 minutes.',
          method: method,
          path: path,
        );
        _reportApiError(error);
        throw error;
      } on http.ClientException catch (clientError) {
        final error = EastAppApiException(
          statusCode: null,
          code: 'NETWORK_ERROR',
          message: clientError.message,
          method: method,
          path: path,
        );
        _reportApiError(error);
        throw error;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        if (error.code != 'DAILY_TASK_ALREADY_SUBMITTED') {
          _reportApiError(error);
        }
        if (error.invalidatesSession) {
          useToken(null);
          final callback = onSessionInvalidated;
          if (callback != null) unawaited(callback());
        }
        throw error;
      }

      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) {
          await _observeUserContent(path, body);
          return DailyTaskRecord.fromJson(body);
        }
      } on FormatException {
        // Report the standard invalid response error below.
      }
      final error = EastAppApiException(
        statusCode: response.statusCode,
        code: 'INVALID_API_RESPONSE',
        message: 'The backend returned an invalid Daily Task response.',
        method: method,
        path: path,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      _reportApiError(error);
      throw error;
    } finally {
      _endProcessingRequest();
    }
  }

  Future<DailyTaskRecord> rateDailyTask({
    required String recordId,
    required int rating,
    required String comment,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/daily-tasks/records/$recordId/rate',
      body: {'rating': rating, 'comment': comment.trim()},
    ) as Map<String, dynamic>;
    return DailyTaskRecord.fromJson(body);
  }

  Future<ComplaintReport> createComplaintReport({
    required DateTime reportDate,
    required String photoStorageKey,
    required String customerGender,
    required int estimatedAge,
    required String complaintInfo,
    String? phoneE164,
    required String actionTaken,
    double? compensationAmountRm,
    required String status,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/complaints',
      body: {
        'reportDate': formatApiDate(reportDate),
        'photoStorageKey': photoStorageKey,
        'customerGender': customerGender,
        'estimatedAge': estimatedAge,
        'complaintInfo': complaintInfo.trim(),
        'phoneE164': phoneE164?.trim(),
        'actionTaken': actionTaken.trim(),
        'compensationAmountRm': compensationAmountRm,
        'status': status,
      },
    ) as Map<String, dynamic>;
    return ComplaintReport.fromJson(body);
  }

  Future<List<ComplaintReport>> complaintReports({
    required DateTime from,
    required DateTime to,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      'from': formatApiDate(from),
      'to': formatApiDate(to),
    }).query;
    final path = '/api/v1/reports/complaints?$query';
    final body = (tenantId == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: complaintHistoryCacheKey(tenantId, from, to),
            forceRefresh: forceRefresh,
          )) as List<dynamic>;
    return body
        .map((item) => ComplaintReport.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ComplaintReport> updateComplaintReport({
    required String reportId,
    required String status,
    required String actionTaken,
    double? compensationAmountRm,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/reports/complaints/$reportId',
      body: {
        'status': status,
        'actionTaken': actionTaken.trim(),
        'compensationAmountRm': compensationAmountRm,
      },
    ) as Map<String, dynamic>;
    return ComplaintReport.fromJson(body);
  }

  Future<List<ReportApproval>> reportApprovals() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/reports/approvals',
    ) as List<dynamic>;
    return body
        .map((item) => ReportApproval.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ReportApproval> reviewReport({
    required String reportId,
    required String status,
    String? note,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/reports/$reportId/review',
      body: {
        'status': status,
        'note': note?.trim(),
      },
    ) as Map<String, dynamic>;
    return ReportApproval.fromJson(body);
  }

  Future<EastAppPage<EastAppUser>> listUsers({
    String search = '',
    bool? active,
    String? role,
    String? viewerRole,
    int page = 0,
    int size = 20,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      'search': search.trim(),
      if (active != null) 'active': active.toString(),
      if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
      'page': '$page',
      'size': '$size',
    }).query;
    final path = '/api/v1/users?$query';
    final cacheKey = tenantId == null
        ? null
        : '${usersCachePrefix(tenantId)}${viewerRole ?? 'AUTH'}:$query';
    final body = cacheKey == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: cacheKey,
            forceRefresh: forceRefresh,
          );
    return EastAppPage.fromJson(
      body as Map<String, dynamic>,
      EastAppUser.fromJson,
    );
  }

  Future<EastAppUser> createUser({
    String? password,
    required String fullName,
    required String phoneE164,
    required String roleId,
    String? profilePhotoKey,
    DateTime? birthDate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/users',
      body: {
        'password': password,
        'fullName': fullName,
        'phoneE164': phoneE164,
        'roleId': roleId,
        'profilePhotoKey': profilePhotoKey,
        'birthDate': formatApiDate(birthDate),
        'startDate': formatApiDate(startDate),
        'endDate': formatApiDate(endDate),
      },
    ) as Map<String, dynamic>;
    invalidateAvailableContextsCache();
    return EastAppUser.fromJson(body);
  }

  Future<EastAppUser> updateUser({
    required String userId,
    required String fullName,
    required String phoneE164,
    required String roleId,
    required bool active,
    String? profilePhotoKey,
    DateTime? birthDate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/users/$userId',
      body: {
        'fullName': fullName,
        'phoneE164': phoneE164,
        'roleId': roleId,
        'active': active,
        'profilePhotoKey': profilePhotoKey,
        'birthDate': formatApiDate(birthDate),
        'startDate': formatApiDate(startDate),
        'endDate': formatApiDate(endDate),
      },
    ) as Map<String, dynamic>;
    invalidateAvailableContextsCache();
    return EastAppUser.fromJson(body);
  }

  Future<void> resetUserPassword({
    required String userId,
    required String password,
  }) async {
    await _requestJson(
      'PUT',
      '/api/v1/users/$userId/password',
      body: {'password': password},
      expectBody: false,
    );
  }

  Future<List<EastAppRole>> listRoles({
    String? tenantId,
    String? viewerRole,
    bool forceRefresh = false,
  }) async {
    const path = '/api/v1/roles';
    final cacheKey = tenantId == null
        ? null
        : '${rolesCachePrefix(tenantId)}visible:${viewerRole ?? 'AUTH'}';
    final body = cacheKey == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: cacheKey,
            forceRefresh: forceRefresh,
          );
    return (body as List<dynamic>)
        .map((item) => EastAppRole.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<EastAppRole>> listAssignableRoles() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/roles/assignable',
    ) as List<dynamic>;
    return body
        .map((item) => EastAppRole.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<EastAppAttendanceToday> attendanceToday() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/attendance/today',
    ) as Map<String, dynamic>;
    return EastAppAttendanceToday.fromJson(body);
  }

  Future<EastAppAttendanceEvent> createAttendanceEvent({
    required String clientEventId,
    required DateTime deviceCapturedAt,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String qrPayload,
    required String devicePlatform,
    String? deviceOsVersion,
    required String appVersion,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/attendance/events',
      body: {
        'clientEventId': clientEventId,
        'deviceCapturedAt': deviceCapturedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'qrPayload': qrPayload,
        'devicePlatform': devicePlatform,
        'deviceOsVersion': deviceOsVersion,
        'appVersion': appVersion,
      },
    ) as Map<String, dynamic>;
    return EastAppAttendanceEvent.fromJson(body);
  }

  Future<EastAppAttendanceQrCode> generateAttendanceQrCode({
    required String eventType,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/attendance/qr-codes',
      body: {'eventType': eventType},
    ) as Map<String, dynamic>;
    return EastAppAttendanceQrCode.fromJson(body);
  }

  Future<EastAppAttendanceAudit> attendanceAudit({
    required AttendanceAuditPeriod period,
    required DateTime anchor,
  }) async {
    final query = Uri(queryParameters: {
      'period': period.apiValue,
      'anchor': formatIsoDate(anchor),
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/attendance/audit?$query',
    ) as Map<String, dynamic>;
    return EastAppAttendanceAudit.fromJson(body);
  }


  Future<EastAppAttendanceUserDetail> attendanceUserAudit({
    required String userId,
    required AttendanceAuditPeriod period,
    required DateTime anchor,
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(queryParameters: {
      'period': period.apiValue,
      'anchor': formatIsoDate(anchor),
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/attendance/users/$userId?$query',
    ) as Map<String, dynamic>;
    return EastAppAttendanceUserDetail.fromJson(body);
  }

  Future<EastAppPage<KnowledgeItem>> knowledgeSops({
    String search = '',
    String? tagId,
    int page = 0,
    int size = 100,
  }) async {
    final query = Uri(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (tagId != null && tagId.trim().isNotEmpty) 'tagId': tagId.trim(),
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/knowledge/sops?$query',
    ) as Map<String, dynamic>;
    return knowledgeItemPageFromJson(body);
  }

  Future<KnowledgeItem> createKnowledgeSop(KnowledgeItem item) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/knowledge/sops',
      body: knowledgeItemToJson(item, includeLinkedSop: true),
    ) as Map<String, dynamic>;
    return knowledgeItemFromJson(body);
  }

  Future<KnowledgeItem> updateKnowledgeSop(KnowledgeItem item) async {
    if (item.id.trim().isEmpty) {
      throw ArgumentError.value(item.id, 'item.id', 'SOP ID is required');
    }
    final body = await _requestJson(
      'PUT',
      '/api/v1/knowledge/sops/${Uri.encodeComponent(item.id)}',
      body: knowledgeItemToJson(item),
    ) as Map<String, dynamic>;
    return knowledgeItemFromJson(body);
  }

  Future<void> deleteKnowledgeSops(Set<String> sopIds) async {
    final ids = sopIds.where((id) => id.trim().isNotEmpty).toList()..sort();
    if (ids.isEmpty) {
      throw ArgumentError.value(
        sopIds,
        'sopIds',
        'At least one SOP ID is required',
      );
    }
    await _requestJson(
      'POST',
      '/api/v1/knowledge/sops/bulk-delete',
      body: {'sopIds': ids},
      expectBody: false,
    );
  }

  Future<EastAppStockSnapshot> stockSnapshot() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/stock/snapshot',
    ) as Map<String, dynamic>;
    return EastAppStockSnapshot.fromJson(body);
  }

  Future<EastAppPage<StockTag>> stockTags({
    String search = '',
    int page = 0,
    int size = 50,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': '$page',
      'size': '$size',
    }).query;
    final path = '/api/v1/stock/tags?$query';
    final cacheKey = tenantId == null
        ? null
        : '${stockTagsCachePrefix(tenantId)}$query';
    final body = cacheKey == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: cacheKey,
            forceRefresh: forceRefresh,
          );
    return stockTagPageFromJson(body as Map<String, dynamic>);
  }

  Future<List<StockTag>> allStockTags({
    required String tenantId,
    bool forceRefresh = false,
  }) async {
    final result = <StockTag>[];
    var pageIndex = 0;
    while (true) {
      final page = await stockTags(
        page: pageIndex,
        size: 100,
        tenantId: tenantId,
        forceRefresh: forceRefresh,
      );
      result.addAll(page.content);
      if (page.last || pageIndex + 1 >= page.totalPages) break;
      pageIndex += 1;
    }
    return List.unmodifiable(result);
  }

  Future<EastAppPage<SupplierProfile>> stockSuppliers({
    String search = '',
    int page = 0,
    int size = 50,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': '$page',
      'size': '$size',
    }).query;
    final path = '/api/v1/stock/suppliers?$query';
    final cacheKey = tenantId == null
        ? null
        : '${stockSuppliersCachePrefix(tenantId)}$query';
    final body = cacheKey == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: cacheKey,
            forceRefresh: forceRefresh,
          );
    return stockSupplierPageFromJson(body as Map<String, dynamic>);
  }

  Future<EastAppPage<StockSku>> stockSkus({
    String search = '',
    bool? active,
    bool? assigned,
    int page = 0,
    int size = 50,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (active != null) 'active': '$active',
      if (assigned != null) 'assigned': '$assigned',
      'page': '$page',
      'size': '$size',
    }).query;
    final path = '/api/v1/stock/skus?$query';
    final cacheKey = tenantId == null
        ? null
        : '${stockSkusCachePrefix(tenantId)}$query';
    final body = cacheKey == null
        ? await _requestJson('GET', path)
        : await _requestCachedJson(
            path,
            cacheKey: cacheKey,
            forceRefresh: forceRefresh,
          );
    return stockSkuPageFromJson(body as Map<String, dynamic>);
  }

  Future<EastAppPage<StockSku>> stockCopySourceSkus({
    required String tenantId,
    String search = '',
    bool? active,
    int page = 0,
    int size = 100,
  }) async {
    final query = Uri(queryParameters: {
      'tenantId': tenantId,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (active != null) 'active': '$active',
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/stock/skus/copy-source?$query',
    ) as Map<String, dynamic>;
    return stockSkuPageFromJson(body);
  }

  Future<StockSkuCopyResult> copyStockSkus({
    required String sourceTenantId,
    required List<String> skuIds,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/skus/copy',
      body: {
        'sourceTenantId': sourceTenantId,
        'skuIds': skuIds,
      },
    ) as Map<String, dynamic>;
    return StockSkuCopyResult.fromJson(body);
  }

  Future<StockReviewSummary> todayStockReviewSummary() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/stock/reviews/today-summary',
    ) as Map<String, dynamic>;
    return StockReviewSummary.fromJson(body);
  }

  Future<EastAppPage<StockSubmission>> stockCounts({
    bool mine = false,
    String? reviewStatus,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final query = Uri(queryParameters: {
      'mine': '$mine',
      if (reviewStatus != null && reviewStatus.trim().isNotEmpty)
        'reviewStatus': reviewStatus.trim(),
      if (from != null) 'from': formatApiDate(from),
      if (to != null) 'to': formatApiDate(to),
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/stock/counts?$query',
    ) as Map<String, dynamic>;
    return stockSubmissionPageFromJson(body);
  }

  Future<EastAppPage<StockReceivingRecord>> stockReceivings({
    String? reviewStatus,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final query = Uri(queryParameters: {
      if (reviewStatus != null && reviewStatus.trim().isNotEmpty)
        'reviewStatus': reviewStatus.trim(),
      if (from != null) 'from': formatApiDate(from),
      if (to != null) 'to': formatApiDate(to),
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/stock/receivings?$query',
    ) as Map<String, dynamic>;
    return stockReceivingPageFromJson(body);
  }

  Future<StockTag> createStockTag(
    String tag, {
    List<String> assignedUserIds = const [],
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/tags',
      body: {'tag': tag, 'assignedUserIds': assignedUserIds},
    ) as Map<String, dynamic>;
    return stockTagFromJson(body);
  }

  Future<StockTag> updateStockTag(StockTag tag) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/tags/${tag.id}',
      body: {
        'tag': tag.tag,
        'assignedUserIds': tag.assignedUsers
            .map((user) => user.userId)
            .toList(growable: false),
      },
    ) as Map<String, dynamic>;
    return stockTagFromJson(body);
  }

  Future<void> deleteStockTag(String tagId) async {
    await _requestJson(
      'DELETE',
      '/api/v1/stock/tags/$tagId',
      expectBody: false,
    );
  }

  Future<SupplierProfile> createStockSupplier(
    SupplierProfile supplier,
  ) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/suppliers',
      body: stockSupplierToJson(supplier),
    ) as Map<String, dynamic>;
    return stockSupplierFromJson(body);
  }

  Future<SupplierProfile> updateStockSupplier(
    SupplierProfile supplier,
  ) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/suppliers/${supplier.id}',
      body: stockSupplierToJson(supplier),
    ) as Map<String, dynamic>;
    return stockSupplierFromJson(body);
  }

  Future<void> deleteStockSupplier(String supplierId) async {
    await _requestJson(
      'DELETE',
      '/api/v1/stock/suppliers/$supplierId',
      expectBody: false,
    );
  }

  Future<SupplierProfile> updateStockSupplierBalance({
    required String supplierId,
    required double balance,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/suppliers/$supplierId/balance',
      body: {'balance': balance},
    ) as Map<String, dynamic>;
    return stockSupplierFromJson(body);
  }


  Future<String> uploadReportImage(String filePath) async {
    _beginProcessingRequest();
    final stopwatch = Stopwatch()..start();
    try {
      const method = 'POST';
      const path = '/api/v1/reports/media';
      final token = _token;
      if (token == null || token.isEmpty) {
        final error = const EastAppApiException(
          statusCode: 401,
          code: 'MISSING_SESSION',
          message: 'Login required.',
          method: method,
          path: path,
        );
        _reportApiError(error);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
        throw error;
      }

      final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token';
      try {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      } on Exception catch (exception) {
        final error = EastAppApiException(
          statusCode: null,
          code: 'REPORT_IMAGE_READ_FAILED',
          message: 'Unable to read the captured report photo: $exception',
          method: method,
          path: path,
        );
        _reportApiError(error);
        throw error;
      }

      late http.Response response;
      try {
        final streamed = await _client.send(request).timeout(_requestTimeout);
        response = await http.Response.fromStream(streamed);
      } on TimeoutException {
        final error = const EastAppApiException(
          statusCode: null,
          code: 'REQUEST_TIMEOUT',
          message: 'The application server did not respond within 15 seconds.',
          method: method,
          path: path,
        );
        _reportApiError(error);
        throw error;
      } on http.ClientException catch (clientError) {
        final error = EastAppApiException(
          statusCode: null,
          code: 'NETWORK_ERROR',
          message: clientError.message,
          method: method,
          path: path,
        );
        _reportApiError(error);
        throw error;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        _reportApiError(error);
        if (error.invalidatesSession) {
          useToken(null);
          final callback = onSessionInvalidated;
          if (callback != null) unawaited(callback());
        }
        throw error;
      }

      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) {
          final storageKey = body['storageKey']?.toString().trim() ?? '';
          if (storageKey.isNotEmpty) return storageKey;
        }
      } on FormatException {
        // Report the standard invalid response error below.
      }
      final error = const EastAppApiException(
        statusCode: 201,
        code: 'INVALID_API_RESPONSE',
        message: 'The application server returned an invalid report photo response.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    } finally {
      _endProcessingRequest();
    }
  }

  Future<Uint8List> reportImageBytes(String storageKey) {
    return _loadMediaBytes(
      'report:$storageKey',
      () => _fetchReportImageBytes(storageKey),
    );
  }

  Future<Uint8List> _fetchReportImageBytes(String storageKey) async {
    final stopwatch = Stopwatch()..start();
    const method = 'GET';
    final encodedKey = Uri.encodeComponent(storageKey);
    final path = '/api/v1/reports/media/$encodedKey';
    final token = _token;
    if (token == null || token.isEmpty) {
      final error = EastAppApiException(
        statusCode: 401,
        code: 'MISSING_SESSION',
        message: 'Login required.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      final callback = onSessionInvalidated;
      if (callback != null) unawaited(callback());
      throw error;
    }
    late http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'image/jpeg,image/png',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_requestTimeout);
    } on TimeoutException {
      final error = EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The application server did not respond within 15 seconds.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    } on http.ClientException catch (clientError) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: clientError.message,
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      _reportApiError(error);
      throw error;
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<String> uploadStockSkuThumbnail(String filePath) async {
    _beginProcessingRequest();
    try {
      return await _uploadStockSkuThumbnailInternal(filePath);
    } finally {
      _endProcessingRequest();
    }
  }

  Future<String> _uploadStockSkuThumbnailInternal(String filePath) async {
    final stopwatch = Stopwatch()..start();
    const method = 'POST';
    const path = '/api/v1/stock/media/sku-thumbnails';
    final token = _token;
    if (token == null || token.isEmpty) {
      final error = const EastAppApiException(
        statusCode: 401,
        code: 'MISSING_SESSION',
        message: 'Login required.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      final callback = onSessionInvalidated;
      if (callback != null) unawaited(callback());
      throw error;
    }

    final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    try {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } on Exception catch (exception) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'IMAGE_READ_FAILED',
        message: 'Unable to read the captured SKU thumbnail: $exception',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }

    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      final error = const EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The application server did not respond within 15 seconds.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    } on http.ClientException catch (clientError) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: clientError.message,
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      _reportApiError(error);
      if (error.invalidatesSession) {
        useToken(null);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
      }
      throw error;
    }

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final storageKey = body['storageKey']?.toString().trim() ?? '';
        if (storageKey.isNotEmpty) return storageKey;
      }
    } on FormatException {
      // Report the standard invalid response error below.
    }

    final error = const EastAppApiException(
      statusCode: 201,
      code: 'INVALID_API_RESPONSE',
      message: 'The application server returned an invalid thumbnail response.',
      method: method,
      path: path,
    );
    _reportApiError(error);
    throw error;
  }

  Future<String> uploadStockReceivingPhoto(String filePath) async {
    _beginProcessingRequest();
    try {
      return await _uploadStockReceivingPhotoInternal(filePath);
    } finally {
      _endProcessingRequest();
    }
  }

  Future<String> _uploadStockReceivingPhotoInternal(String filePath) async {
    final stopwatch = Stopwatch()..start();
    const method = 'POST';
    const path = '/api/v1/stock/media/receiving-photos';
    final token = _token;
    if (token == null || token.isEmpty) {
      final error = const EastAppApiException(
        statusCode: 401,
        code: 'MISSING_SESSION',
        message: 'Login required.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      final callback = onSessionInvalidated;
      if (callback != null) unawaited(callback());
      throw error;
    }

    final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    try {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } on Exception catch (exception) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'IMAGE_READ_FAILED',
        message: 'Unable to read the captured receiving photo: $exception',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }

    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      final error = const EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The application server did not respond within 15 seconds.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    } on http.ClientException catch (clientError) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: clientError.message,
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      _reportApiError(error);
      if (error.invalidatesSession) {
        useToken(null);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
      }
      throw error;
    }

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final storageKey = body['storageKey']?.toString().trim() ?? '';
        if (storageKey.isNotEmpty) return storageKey;
      }
    } on FormatException {
      // Report the standard invalid response error below.
    }

    final error = const EastAppApiException(
      statusCode: 201,
      code: 'INVALID_API_RESPONSE',
      message: 'The application server returned an invalid receiving-photo response.',
      method: method,
      path: path,
    );
    _reportApiError(error);
    throw error;
  }

  Future<Uint8List> stockSkuThumbnailBytes(String storageKey) {
    return _loadMediaBytes(
      'stock-sku:$storageKey',
      () => _fetchStockSkuThumbnailBytes(storageKey),
    );
  }

  Future<Uint8List> _fetchStockSkuThumbnailBytes(String storageKey) async {
    final stopwatch = Stopwatch()..start();
    const method = 'GET';
    final encodedKey = Uri.encodeComponent(storageKey);
    final path = '/api/v1/stock/media/sku-thumbnails/$encodedKey';
    final token = _token;
    if (token == null || token.isEmpty) {
      final error = EastAppApiException(
        statusCode: 401,
        code: 'MISSING_SESSION',
        message: 'Login required.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      final callback = onSessionInvalidated;
      if (callback != null) unawaited(callback());
      throw error;
    }

    late http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'image/jpeg,image/png',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_requestTimeout);
    } on TimeoutException {
      final error = EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The application server did not respond within 15 seconds.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    } on http.ClientException catch (clientError) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: clientError.message,
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      _reportApiError(error);
      if (error.invalidatesSession) {
        useToken(null);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
      }
      throw error;
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<Uint8List> stockReceivingPhotoBytes(String storageKey) {
    return _loadMediaBytes(
      'stock-receiving:$storageKey',
      () => _fetchStockReceivingPhotoBytes(storageKey),
    );
  }

  Future<Uint8List> _fetchStockReceivingPhotoBytes(String storageKey) async {
    final stopwatch = Stopwatch()..start();
    const method = 'GET';
    final encodedKey = Uri.encodeComponent(storageKey);
    final path = '/api/v1/stock/media/receiving-photos/$encodedKey';
    final token = _token;
    if (token == null || token.isEmpty) {
      final error = EastAppApiException(
        statusCode: 401,
        code: 'MISSING_SESSION',
        message: 'Login required.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      final callback = onSessionInvalidated;
      if (callback != null) unawaited(callback());
      throw error;
    }

    late http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'image/jpeg,image/png',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_requestTimeout);
    } on TimeoutException {
      final error = EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The application server did not respond within 15 seconds.',
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    } on http.ClientException catch (clientError) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: clientError.message,
        method: method,
        path: path,
      );
      _reportApiError(error);
      throw error;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _apiException(
          response,
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      _reportApiError(error);
      if (error.invalidatesSession) {
        useToken(null);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
      }
      throw error;
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<StockSku> createStockSku(StockSku sku) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/skus',
      body: stockSkuToJson(sku),
    ) as Map<String, dynamic>;
    return stockSkuFromJson(body);
  }

  Future<StockSku> updateStockSku(StockSku sku) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/skus/${sku.id}',
      body: stockSkuToJson(sku),
    ) as Map<String, dynamic>;
    return stockSkuFromJson(body);
  }

  Future<StockSku> updateStockSkuBalance({
    required String skuId,
    required double balance,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/skus/$skuId/balance',
      body: {'balance': balance},
    ) as Map<String, dynamic>;
    return stockSkuFromJson(body);
  }

  Future<StockSubmission> createStockCount(
    StockSubmission submission,
  ) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/counts',
      body: stockCountToJson(submission),
    ) as Map<String, dynamic>;
    return stockSubmissionFromJson(body);
  }

  Future<StockSubmission> reviewStockCount(
    StockSubmission submission,
  ) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/counts/${submission.id}/review',
      body: {
        'status': submission.reviewStatus,
        'note': submission.reviewNote,
      },
    ) as Map<String, dynamic>;
    return stockSubmissionFromJson(body);
  }

  Future<List<StockSubmission>> bulkReviewStockCounts(
    List<StockSubmission> submissions,
  ) async {
    if (submissions.isEmpty) return const [];
    final statuses = submissions.map((item) => item.reviewStatus).toSet();
    if (statuses.length != 1) {
      throw const EastAppApiException(
        statusCode: null,
        code: 'INVALID_BULK_REVIEW',
        message: 'All selected daily count records must use the same review status.',
        method: 'PATCH',
        path: '/api/v1/stock/counts/bulk-review',
      );
    }
    final notes = submissions
        .map((item) => item.reviewNote.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/counts/bulk-review',
      body: {
        'submissionIds': submissions.map((item) => item.id).toList(growable: false),
        'status': statuses.single,
        'note': notes.isEmpty ? null : notes.first,
      },
    ) as Map<String, dynamic>;
    return (body['records'] as List<dynamic>? ?? const [])
        .map((item) => stockSubmissionFromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<StockReceivingRecord> createStockReceiving(
    StockReceivingRecord record,
  ) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/receivings',
      body: stockReceivingToJson(record),
    ) as Map<String, dynamic>;
    return stockReceivingRecordFromJson(body);
  }

  Future<StockReceivingRecord> reviewStockReceiving(
    StockReceivingRecord record,
  ) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/receivings/${record.id}/review',
      body: {
        'status': record.reviewStatus,
        'note': record.reviewNote,
      },
    ) as Map<String, dynamic>;
    return stockReceivingRecordFromJson(body);
  }

  Future<EastAppPage<StockAuditEntry>> stockAudit({
    required DateTime from,
    required DateTime to,
    bool mine = false,
    int page = 0,
    int size = 50,
  }) async {
    final query = Uri(queryParameters: {
      'from': formatApiDate(from),
      'to': formatApiDate(to),
      'mine': '$mine',
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/stock/audit?$query',
    ) as Map<String, dynamic>;
    return stockAuditPageFromJson(body);
  }

  Future<Uint8List> _loadMediaBytes(
    String cacheKey,
    Future<Uint8List> Function() loader,
  ) {
    const maximumEntries = 64;
    const maximumBytes = 24 * 1024 * 1024;

    final cached = _mediaBytesCache.remove(cacheKey);
    if (cached != null) {
      _mediaBytesCache[cacheKey] = cached;
      return Future<Uint8List>.value(cached);
    }
    final existing = _mediaBytesRequests[cacheKey];
    if (existing != null) return existing;

    final generation = _mediaBytesCacheGeneration;
    late final Future<Uint8List> request;
    request = loader().then((bytes) {
      if (generation != _mediaBytesCacheGeneration ||
          bytes.lengthInBytes > maximumBytes) {
        return bytes;
      }
      final replaced = _mediaBytesCache.remove(cacheKey);
      if (replaced != null) {
        _mediaBytesCacheSize -= replaced.lengthInBytes;
      }
      _mediaBytesCache[cacheKey] = bytes;
      _mediaBytesCacheSize += bytes.lengthInBytes;
      while (_mediaBytesCache.length > maximumEntries ||
          _mediaBytesCacheSize > maximumBytes) {
        final oldestKey = _mediaBytesCache.keys.first;
        final removed = _mediaBytesCache.remove(oldestKey);
        if (removed != null) {
          _mediaBytesCacheSize -= removed.lengthInBytes;
        }
      }
      return bytes;
    }).whenComplete(() {
      if (identical(_mediaBytesRequests[cacheKey], request)) {
        _mediaBytesRequests.remove(cacheKey);
      }
    });
    _mediaBytesRequests[cacheKey] = request;
    return request;
  }

  Future<Object?> _requestCachedJson(
    String path, {
    required String cacheKey,
    bool forceRefresh = false,
  }) async {
    final readEpoch = _featureCacheEpoch;
    final readRevision = _featureCacheRevisions[cacheKey] ?? 0;
    if (!forceRefresh) {
      final cached = await FeatureDataCache.instance.read(cacheKey);
      if (cached != null &&
          readEpoch == _featureCacheEpoch &&
          readRevision == (_featureCacheRevisions[cacheKey] ?? 0)) {
        AppDiagnostics.instance.log('Cache hit · $cacheKey');
        await _observeUserContent(path, cached.data);
        return cached.data;
      }
    }
    final existing = _featureReadRequests[cacheKey];
    if (existing != null) {
      AppDiagnostics.instance.log('Cache request joined · $cacheKey');
      return existing;
    }
    AppDiagnostics.instance.log(
      '${forceRefresh ? 'Cache refresh' : 'Cache miss'} · $cacheKey',
    );

    final requestEpoch = _featureCacheEpoch;
    final requestRevision = _featureCacheRevisions[cacheKey] ?? 0;
    final request = (() async {
      final value = await _requestJson('GET', path);
      final stillCurrent = requestEpoch == _featureCacheEpoch &&
          requestRevision == (_featureCacheRevisions[cacheKey] ?? 0);
      if (stillCurrent) {
        await FeatureDataCache.instance.write(cacheKey, value);
        if (requestEpoch != _featureCacheEpoch ||
            requestRevision != (_featureCacheRevisions[cacheKey] ?? 0)) {
          await FeatureDataCache.instance.remove(cacheKey);
        }
      }
      return value;
    })();
    _featureReadRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_featureReadRequests[cacheKey], request)) {
        _featureReadRequests.remove(cacheKey);
      }
    }
  }

  Future<Object?> _requestJson(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    bool expectBody = true,
    bool notifyOnUnauthorised = true,
    bool reportError = true,
    bool observeContent = true,
    Duration? timeout,
  }) async {
    final isTranslationRequest = path.startsWith('/api/v1/translations');
    final shouldBlock = !isTranslationRequest &&
        (method != 'GET' ||
            path.startsWith('/api/v1/reports') &&
                !path.startsWith('/api/v1/reports/media/'));
    if (shouldBlock) _beginProcessingRequest();
    try {
      final value = await _requestJsonInternal(
        method,
        path,
        body: body,
        authenticated: authenticated,
        expectBody: expectBody,
        notifyOnUnauthorised: notifyOnUnauthorised,
        reportError: reportError,
        timeout: timeout,
      );
      if (authenticated && observeContent && value != null) {
        await _observeUserContent(path, value);
      }
      return value;
    } finally {
      if (shouldBlock) _endProcessingRequest();
    }
  }

  Future<Object?> _requestJsonInternal(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    bool expectBody = true,
    bool notifyOnUnauthorised = true,
    bool reportError = true,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = _token;
      if (token == null || token.isEmpty) {
        final error = EastAppApiException(
          statusCode: 401,
          code: 'MISSING_SESSION',
          message: 'Login required.',
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        if (reportError) _reportApiError(error);
        final callback = onSessionInvalidated;
        if (notifyOnUnauthorised && callback != null) unawaited(callback());
        throw error;
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late Future<http.Response> request;
    switch (method) {
      case 'GET':
        request = _client.get(uri, headers: headers);
        break;
      case 'POST':
        request = _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PATCH':
        request = _client.patch(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PUT':
        request = _client.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'DELETE':
        request = _client.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }

    late http.Response response;
    try {
      response = await request.timeout(timeout ?? _requestTimeout);
    } on TimeoutException {
      final error = EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message:
            'The application server did not respond within ${(timeout ?? _requestTimeout).inSeconds} seconds.',
        method: method,
        path: path,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      if (reportError) _reportApiError(error);
      throw error;
    } on http.ClientException catch (clientError) {
      final error = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: clientError.message,
        method: method,
        path: path,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      if (reportError) _reportApiError(error);
      throw error;
    }

    final durationMs = stopwatch.elapsedMilliseconds;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _apiException(
        response,
        method: method,
        path: path,
        durationMs: durationMs,
      );
      if (reportError) _reportApiError(error);
      if (authenticated && notifyOnUnauthorised && error.invalidatesSession) {
        useToken(null);
        final callback = onSessionInvalidated;
        if (callback != null) unawaited(callback());
      }
      throw error;
    }

    if (method != 'GET') {
      AppDiagnostics.instance.log(
        'API success · $method $path · ${durationMs}ms',
      );
    }
    if (!expectBody || response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      final error = EastAppApiException(
        statusCode: response.statusCode,
        code: 'INVALID_API_RESPONSE',
        message: 'The application server returned an invalid response.',
        method: method,
        path: path,
        durationMs: durationMs,
        responseExcerpt: _responseExcerpt(response),
      );
      if (reportError) _reportApiError(error);
      throw error;
    }
  }

  Future<void> _observeUserContent(String path, Object? value) {
    if (_token == null ||
        path.startsWith('/api/v1/translations') ||
        path.startsWith('/api/v1/auth') ||
        path.startsWith('/api/v1/setup')) {
      return Future<void>.value();
    }

    final discovered = <String>{};
    _collectUserContent(value, discovered);
    if (discovered.isEmpty) return Future<void>.value();
    _knownContent.addAll(discovered);
    return Future<void>.value();
  }

  List<String> _contentForDirection(TranslationDirection direction) {
    return <String>{
      for (final value in _knownContent)
        if (direction.source.matches(value) &&
            normaliseContentText(value).isNotEmpty)
          normaliseContentText(value),
    }.toList(growable: false);
  }

  Future<Map<String, String>> _translateTexts(
    List<String> texts,
    TranslationDirection direction,
  ) async {
    final pending = <String>{
      for (final value in texts)
        if (normaliseContentText(value).isNotEmpty)
          normaliseContentText(value),
    }.toList(growable: false);
    if (pending.isEmpty) return <String, String>{};

    final translated = <String, String>{};
    const batchSize = 6;
    for (var offset = 0; offset < pending.length; offset += batchSize) {
      final end = offset + batchSize < pending.length
          ? offset + batchSize
          : pending.length;
      final batch = pending.sublist(offset, end);
      final body = await _requestJson(
        'POST',
        '/api/v1/translations',
        body: {
          'sourceLanguage': direction.source.apiValue,
          'targetLanguage': direction.target.apiValue,
          'texts': batch,
        },
        observeContent: false,
        timeout: const Duration(seconds: 45),
      ) as Map<String, dynamic>;
      final items = body['translations'] as List<dynamic>? ?? const [];
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final source = normaliseContentText(
          raw['sourceText']?.toString() ?? '',
        );
        final target = raw['translatedText']?.toString().trim() ?? '';
        if (source.isNotEmpty && target.isNotEmpty) {
          translated[source] = target;
        }
      }
    }
    return translated;
  }

  static const Set<String> _translatedStringFields = <String>{
    'actionTaken',
    'category',
    'complaintInfo',
    'condition',
    'description',
    'expectedOutcome',
    'insight',
    'itemName',
    'location',
    'newValue',
    'note',
    'notes',
    'oldValue',
    'reason',
    'recommendedPurchaseFrequency',
    'reviewNote',
    'skuCategory',
    'skuLocation',
    'skuName',
    'summary',
    'supplierItem',
    'tag',
    'tagName',
    'title',
    'topWasteItem',
  };

  static const Set<String> _translatedCollectionFields = <String>{
    'receivingChecklist',
    'remarks',
  };

  static void _collectUserContent(
    Object? value,
    Set<String> output, {
    String? field,
    bool translateCollectionValues = false,
    Map<String, dynamic>? parent,
  }) {
    if (value is String) {
      final isSkuName = field == 'name' &&
          parent?.containsKey('minimumBalanceValue') == true &&
          parent?.containsKey('maximumBalanceValue') == true;
      if ((translateCollectionValues ||
              _translatedStringFields.contains(field) ||
              isSkuName) &&
          _isUsefulContent(value)) {
        output.add(normaliseContentText(value));
      }
      return;
    }

    if (value is List<dynamic>) {
      for (final item in value) {
        _collectUserContent(
          item,
          output,
          field: field,
          translateCollectionValues: translateCollectionValues,
          parent: parent,
        );
      }
      return;
    }

    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        final collectionValues = translateCollectionValues ||
            _translatedCollectionFields.contains(entry.key);
        _collectUserContent(
          entry.value,
          output,
          field: entry.key,
          translateCollectionValues: collectionValues,
          parent: value,
        );
      }
    }
  }

  static bool _isUsefulContent(String value) {
    final text = normaliseContentText(value);
    if (text.isEmpty || text.length > 2000) return false;
    if (text.contains('\u0000') ||
        text.contains('://') ||
        RegExp(r'^www\.', caseSensitive: false).hasMatch(text) ||
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text) ||
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(text)) {
      return false;
    }
    return RegExp(
      r'[A-Za-z\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u1000-\u109f\ua9e0-\ua9ff\uaa60-\uaa7f]',
    ).hasMatch(text);
  }

  EastAppApiException _apiException(
    http.Response response, {
    required String method,
    required String path,
    required int durationMs,
  }) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final rawFieldErrors = body['fieldErrors'];
        final fieldErrors = <String, String>{};
        if (rawFieldErrors is Map<String, dynamic>) {
          rawFieldErrors.forEach((key, value) {
            fieldErrors[key] = value.toString();
          });
        }
        return EastAppApiException(
          statusCode: response.statusCode,
          code: body['code']?.toString() ?? 'API_ERROR',
          message: body['message']?.toString() ?? 'Request failed.',
          fieldErrors: fieldErrors,
          method: method,
          path: path,
          durationMs: durationMs,
          responseExcerpt: _responseExcerpt(response),
        );
      }
    } on FormatException {
      // Fall through to the status-based error below.
    }

    return EastAppApiException(
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
      message: 'Request failed with HTTP ${response.statusCode}.',
      method: method,
      path: path,
      durationMs: durationMs,
      responseExcerpt: _responseExcerpt(response),
    );
  }

  String? _responseExcerpt(http.Response response) {
    final value = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (value.isEmpty) return null;
    const maxLength = 1200;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength - 3)}...';
  }

  void _reportApiError(EastAppApiException error) {
    AppDiagnostics.instance.recordApiError(
      method: error.method,
      path: error.path,
      statusCode: error.statusCode,
      code: error.code,
      message: error.message,
      fieldErrors: error.fieldErrors,
      durationMs: error.durationMs,
      responseExcerpt: error.responseExcerpt,
    );
    onApiError?.call(error);
  }

  void _beginProcessingRequest() {
    _processingRequestCount += 1;
    if (_processingRequestCount == 1) {
      onProcessingChanged?.call(true);
    }
  }

  void _endProcessingRequest() {
    if (_processingRequestCount == 0) return;
    _processingRequestCount -= 1;
    if (_processingRequestCount == 0) {
      onProcessingChanged?.call(false);
    }
  }

  void close() {
    onProcessingChanged = null;
    _client.close();
  }
}

String _localDayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

final class _DailyTaskMemoryValue<T> {
  final T value;
  final String dayKey;

  const _DailyTaskMemoryValue({required this.value, required this.dayKey});
}

final class _AsyncMemoryCache<T> {
  _AsyncMemoryCache({required this.ttl});

  final Duration ttl;
  T? _value;
  DateTime? _expiresAt;
  Future<T>? _inFlight;
  int _generation = 0;

  Future<T> getOrLoad(
    Future<T> Function() loader, {
    bool forceRefresh = false,
  }) {
    if (forceRefresh) {
      invalidate();
    }

    final expiresAt = _expiresAt;
    final value = _value;
    if (!forceRefresh &&
        value != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return Future<T>.value(value);
    }

    final currentRequest = _inFlight;
    if (!forceRefresh && currentRequest != null) {
      return currentRequest;
    }

    final generation = _generation;
    final request = loader();
    _inFlight = request;
    return request.then((loaded) {
      if (generation == _generation) {
        _value = loaded;
        _expiresAt = DateTime.now().add(ttl);
      }
      return loaded;
    }).whenComplete(() {
      if (identical(_inFlight, request)) {
        _inFlight = null;
      }
    });
  }

  void invalidate() {
    _generation += 1;
    _value = null;
    _expiresAt = null;
    _inFlight = null;
  }
}
