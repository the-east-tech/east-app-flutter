import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../models/attendance_models.dart';
import '../models/google_place_models.dart';
import '../models/knowledge_api_models.dart';
import '../models/api_models.dart';
import '../models/advertisement_models.dart';
import '../models/auth_models.dart';
import '../models/organisation_models.dart';
import '../models/people_models.dart';
import '../models/points_models.dart';
import '../models/report_models.dart';
import '../models/setup_models.dart';
import '../models/stock_api_models.dart';
import '../models/app_models.dart';
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
  final Map<String, Future<Object?>> _featureReadRequests =
      <String, Future<Object?>>{};
  final _availableContextsCache = _AsyncMemoryCache<List<EastAppSession>>(
    ttl: const Duration(minutes: 5),
  );
  final _tenantsCache = _AsyncMemoryCache<List<EastAppTenant>>(
    ttl: const Duration(minutes: 5),
  );

  static const Duration _requestTimeout = Duration(seconds: 15);

  EastAppApi({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfiguration.baseUrl;

  String? get token => _token;

  static String reportDashboardCacheKey(String tenantId, int days) =>
      'tenant:$tenantId:report:dashboard:v2:$days';
  static String salesHistoryCacheKey(
    String tenantId,
    DateTime from,
    DateTime to,
  ) =>
      'tenant:$tenantId:report:sales-history:${formatApiDate(from)}:${formatApiDate(to)}';
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

  DateTime? featureCacheUpdatedAt(String cacheKey) =>
      FeatureDataCache.instance.updatedAt(cacheKey);

  Future<void> invalidateFeatureCache(String keyPrefix) =>
      FeatureDataCache.instance.removeByPrefix(keyPrefix);

  Future<void> clearFeatureCaches() => FeatureDataCache.instance.clearAll();

  void useToken(String? token) {
    if (_token != token) {
      invalidateAvailableContextsCache();
      invalidateTenantsCache();
    }
    _token = token;
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
    required String phoneE164,
    required String password,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/auth/login',
      authenticated: false,
      body: {
        'companyCode': companyCode,
        'employeeId': employeeId,
        'phoneE164': phoneE164,
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
    invalidateAvailableContextsCache();
    invalidateTenantsCache();
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

  Future<AdvertisementFeed> advertisementFeed() async {
    final body = await _requestJson(
      'GET',
      '/api/v1/advertisements/active',
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
  }) async {
    final query = Uri(queryParameters: {
      'from': formatApiDate(from),
      'to': formatApiDate(to),
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/reports/waste?$query',
    ) as List<dynamic>;
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
      if (userId != null) 'userId': userId,
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
  }) async {
    final query = Uri(queryParameters: {
      'from': formatApiDate(from),
      'to': formatApiDate(to),
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/reports/complaints?$query',
    ) as List<dynamic>;
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
    int page = 0,
    int size = 20,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      'search': search.trim(),
      if (active != null) 'active': active.toString(),
      'page': '$page',
      'size': '$size',
    }).query;
    final path = '/api/v1/users?$query';
    final cacheKey = tenantId == null
        ? null
        : '${usersCachePrefix(tenantId)}$query';
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
    bool forceRefresh = false,
  }) async {
    const path = '/api/v1/roles';
    final cacheKey = tenantId == null ? null : '${rolesCachePrefix(tenantId)}all';
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

  Future<EastAppRole> createRole({required String name}) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/roles',
      body: {'name': name},
    ) as Map<String, dynamic>;
    return EastAppRole.fromJson(body);
  }

  Future<EastAppRole> updateRole({
    required String roleId,
    required String name,
    required bool active,
  }) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/roles/$roleId',
      body: {
        'name': name,
        'active': active,
      },
    ) as Map<String, dynamic>;
    return EastAppRole.fromJson(body);
  }

  Future<void> deleteRole(String roleId) async {
    await _requestJson(
      'DELETE',
      '/api/v1/roles/$roleId',
      expectBody: false,
    );
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
    required String eventType,
    required DateTime deviceCapturedAt,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool cameraCaptureValid,
    required bool faceValid,
    required int faceCount,
    required int faceAttemptCount,
    required bool faceVerificationBypassed,
    double? faceBoxWidth,
    double? faceBoxHeight,
    double? faceYaw,
    double? faceRoll,
    double? facePitch,
    required bool qrCheckpointValid,
    required String devicePlatform,
    String? deviceOsVersion,
    required String appVersion,
    required String validationMethod,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/attendance/events',
      body: {
        'clientEventId': clientEventId,
        'eventType': eventType,
        'deviceCapturedAt': deviceCapturedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'cameraCaptureValid': cameraCaptureValid,
        'faceValid': faceValid,
        'faceCount': faceCount,
        'faceAttemptCount': faceAttemptCount,
        'faceVerificationBypassed': faceVerificationBypassed,
        'faceBoxWidth': faceBoxWidth,
        'faceBoxHeight': faceBoxHeight,
        'faceYaw': faceYaw,
        'faceRoll': faceRoll,
        'facePitch': facePitch,
        'qrCheckpointValid': qrCheckpointValid,
        'devicePlatform': devicePlatform,
        'deviceOsVersion': deviceOsVersion,
        'appVersion': appVersion,
        'validationMethod': validationMethod,
      },
    ) as Map<String, dynamic>;
    return EastAppAttendanceEvent.fromJson(body);
  }

  Future<EastAppAttendanceFaceAttempt> createAttendanceFaceAttempt({
    required String clientAttemptId,
    required String intendedEventType,
    required DateTime deviceAttemptedAt,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String failureReason,
    required int faceCount,
    required int faceAttemptNumber,
    double? faceBoxWidth,
    double? faceBoxHeight,
    double? faceYaw,
    double? faceRoll,
    double? facePitch,
    required String devicePlatform,
    String? deviceOsVersion,
    required String appVersion,
    required String validationMethod,
    Uint8List? photoBytes,
  }) async {
    _beginProcessingRequest();
    final stopwatch = Stopwatch()..start();
    try {
      const method = 'POST';
      const path = '/api/v1/attendance/face-attempts';
      final token = _token;
      if (token == null || token.isEmpty) {
        throw EastAppApiException(
          statusCode: 401,
          code: 'MISSING_SESSION',
          message: 'Login required.',
          method: method,
          path: path,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token'
        ..fields.addAll({
          'clientAttemptId': clientAttemptId,
          'intendedEventType': intendedEventType,
          'deviceAttemptedAt': deviceAttemptedAt.toUtc().toIso8601String(),
          'latitude': '$latitude',
          'longitude': '$longitude',
          'accuracyMeters': '$accuracyMeters',
          'failureReason': failureReason,
          'faceCount': '$faceCount',
          'faceAttemptNumber': '$faceAttemptNumber',
          if (faceBoxWidth != null) 'faceBoxWidth': '$faceBoxWidth',
          if (faceBoxHeight != null) 'faceBoxHeight': '$faceBoxHeight',
          if (faceYaw != null) 'faceYaw': '$faceYaw',
          if (faceRoll != null) 'faceRoll': '$faceRoll',
          if (facePitch != null) 'facePitch': '$facePitch',
          'devicePlatform': devicePlatform,
          if (deviceOsVersion != null && deviceOsVersion.trim().isNotEmpty)
            'deviceOsVersion': deviceOsVersion.trim(),
          'appVersion': appVersion,
          'validationMethod': validationMethod,
        });
      if (photoBytes != null && photoBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: 'failed-face-attempt.jpg',
        ));
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
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return EastAppAttendanceFaceAttempt.fromJson(body);
    } finally {
      _endProcessingRequest();
    }
  }

  Future<EastAppPage<EastAppAttendanceFaceAttempt>> attendanceFaceAttempts({
    required String userId,
    required AttendanceAuditPeriod period,
    required DateTime anchor,
    int page = 0,
    int size = 100,
  }) async {
    final query = Uri(queryParameters: {
      'period': period.apiValue,
      'anchor': formatIsoDate(anchor),
      'page': '$page',
      'size': '$size',
    }).query;
    final body = await _requestJson(
      'GET',
      '/api/v1/attendance/users/$userId/face-attempts?$query',
    ) as Map<String, dynamic>;
    return EastAppPage.fromJson(body, EastAppAttendanceFaceAttempt.fromJson);
  }

  Future<Uint8List> attendanceFaceAttemptPhotoBytes(String attemptId) async {
    final stopwatch = Stopwatch()..start();
    const method = 'GET';
    final path = '/api/v1/attendance/face-attempts/${Uri.encodeComponent(attemptId)}/photo';
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
      body: knowledgeItemToJson(item),
    ) as Map<String, dynamic>;
    return knowledgeItemFromJson(body);
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
    int page = 0,
    int size = 50,
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    final query = Uri(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (active != null) 'active': '$active',
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

  Future<StockTag> createStockTag(String tag) async {
    final body = await _requestJson(
      'POST',
      '/api/v1/stock/tags',
      body: {'tag': tag},
    ) as Map<String, dynamic>;
    return stockTagFromJson(body);
  }

  Future<StockTag> updateStockTag(StockTag tag) async {
    final body = await _requestJson(
      'PATCH',
      '/api/v1/stock/tags/${tag.id}',
      body: {'tag': tag.tag},
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

  Future<Uint8List> reportImageBytes(String storageKey) async {
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

  Future<Uint8List> stockSkuThumbnailBytes(String storageKey) async {
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

  Future<Uint8List> stockReceivingPhotoBytes(String storageKey) async {
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

  Future<Object?> _requestCachedJson(
    String path, {
    required String cacheKey,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await FeatureDataCache.instance.read(cacheKey);
      if (cached != null) {
        AppDiagnostics.instance.log('Cache hit · $cacheKey');
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

    final request = (() async {
      final value = await _requestJson('GET', path);
      await FeatureDataCache.instance.write(cacheKey, value);
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
  }) async {
    final shouldBlock = method != 'GET' ||
        path.startsWith('/api/v1/reports') &&
            !path.startsWith('/api/v1/reports/media/');
    if (shouldBlock) _beginProcessingRequest();
    try {
      return await _requestJsonInternal(
        method,
        path,
        body: body,
        authenticated: authenticated,
        expectBody: expectBody,
        notifyOnUnauthorised: notifyOnUnauthorised,
        reportError: reportError,
      );
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
      response = await request.timeout(_requestTimeout);
    } on TimeoutException {
      final error = EastAppApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The application server did not respond within 15 seconds.',
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

