import 'dart:convert';

import 'package:http/http.dart' as http;

import 'east_app_api.dart';
import 'feature_data_cache.dart';

class StockPurchaseSupplierState {
  final String supplierId;
  final String messageTemplate;
  final String orderState;
  final bool receivingEnabled;
  final String? currentOrderReference;
  final DateTime? orderedAt;
  final String orderedBy;
  final String orderedMessage;

  const StockPurchaseSupplierState({
    required this.supplierId,
    required this.messageTemplate,
    required this.orderState,
    required this.receivingEnabled,
    required this.currentOrderReference,
    required this.orderedAt,
    required this.orderedBy,
    required this.orderedMessage,
  });

  bool get hasActiveOrder => orderState != 'NONE';
  bool get awaitingReview => orderState == 'SUBMITTED';
  bool get correctionRequired => orderState == 'CORRECTION_REQUIRED';

  factory StockPurchaseSupplierState.fromJson(Map<String, dynamic> json) {
    final orderedAtValue = json['orderedAt'] as String?;
    return StockPurchaseSupplierState(
      supplierId: json['supplierId'] as String,
      messageTemplate: (json['messageTemplate'] as String? ?? '').trim(),
      orderState: (json['orderState'] as String? ?? 'NONE').trim(),
      receivingEnabled: json['receivingEnabled'] as bool? ?? false,
      currentOrderReference: json['currentOrderReference'] as String?,
      orderedAt: orderedAtValue == null ? null : DateTime.tryParse(orderedAtValue),
      orderedBy: (json['orderedBy'] as String? ?? '').trim(),
      orderedMessage: (json['orderedMessage'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'supplierId': supplierId,
        'messageTemplate': messageTemplate,
        'orderState': orderState,
        'receivingEnabled': receivingEnabled,
        'currentOrderReference': currentOrderReference,
        'orderedAt': orderedAt?.toIso8601String(),
        'orderedBy': orderedBy,
        'orderedMessage': orderedMessage,
      };
}

class StockPurchaseGateway {
  static final Map<String, Future<List<StockPurchaseSupplierState>>>
      _supplierRequests = <String, Future<List<StockPurchaseSupplierState>>>{};
  static final Map<String, int> _cacheRevisions = <String, int>{};

  final EastAppApi api;
  final String tenantId;

  const StockPurchaseGateway(
    this.api, {
    required this.tenantId,
  });

  String get _cacheKey =>
      'tenant:${tenantId.trim()}:stock:purchase-suppliers:v1';

  Future<List<StockPurchaseSupplierState>> suppliers({
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey;
    if (forceRefresh) {
      await invalidateCache();
    } else {
      final cached = await FeatureDataCache.instance.read(cacheKey);
      if (cached != null) {
        final parsed = _tryParseSuppliers(cached.data);
        if (parsed != null) return parsed;
        await FeatureDataCache.instance.remove(cacheKey);
      }
    }

    final existing = _supplierRequests[cacheKey];
    if (existing != null) return existing;

    final revision = _cacheRevisions[cacheKey] ?? 0;
    late final Future<List<StockPurchaseSupplierState>> request;
    request = (() async {
      final body = await _request('GET', '/api/v1/stock/purchases/suppliers');
      final values = _parseSuppliers(body);
      if (revision == (_cacheRevisions[cacheKey] ?? 0)) {
        await FeatureDataCache.instance.write(
          cacheKey,
          values.map((value) => value.toJson()).toList(growable: false),
        );
      }
      return values;
    })();
    _supplierRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_supplierRequests[cacheKey], request)) {
        _supplierRequests.remove(cacheKey);
      }
    }
  }

  Future<void> invalidateCache() async {
    final cacheKey = _cacheKey;
    _cacheRevisions[cacheKey] = (_cacheRevisions[cacheKey] ?? 0) + 1;
    _supplierRequests.remove(cacheKey);
    await FeatureDataCache.instance.remove(cacheKey);
  }

  Future<StockPurchaseSupplierState> saveTemplate(
    String supplierId,
    String messageTemplate,
  ) async {
    final body = await _request(
      'PATCH',
      '/api/v1/stock/purchases/suppliers/$supplierId/template',
      body: {'messageTemplate': messageTemplate},
    );
    final saved = StockPurchaseSupplierState.fromJson(
      body as Map<String, dynamic>,
    );
    await _replaceCachedSupplier(saved);
    return saved;
  }

  Future<StockPurchaseSupplierState> markOrdered(
    String supplierId,
    String message,
  ) async {
    final body = await _request(
      'POST',
      '/api/v1/stock/purchases/suppliers/$supplierId/ordered',
      body: {'message': message},
    );
    final saved = StockPurchaseSupplierState.fromJson(
      body as Map<String, dynamic>,
    );
    await _replaceCachedSupplier(saved);
    return saved;
  }

  Future<void> _replaceCachedSupplier(
    StockPurchaseSupplierState supplier,
  ) async {
    final cacheKey = _cacheKey;
    _cacheRevisions[cacheKey] = (_cacheRevisions[cacheKey] ?? 0) + 1;
    _supplierRequests.remove(cacheKey);

    final cached = await FeatureDataCache.instance.read(cacheKey);
    final values = cached == null ? null : _tryParseSuppliers(cached.data);
    if (values == null) return;

    var replaced = false;
    final updated = values.map((value) {
      if (value.supplierId != supplier.supplierId) return value;
      replaced = true;
      return supplier;
    }).toList(growable: true);
    if (!replaced) updated.add(supplier);
    await FeatureDataCache.instance.write(
      cacheKey,
      updated.map((value) => value.toJson()).toList(growable: false),
    );
  }

  List<StockPurchaseSupplierState>? _tryParseSuppliers(Object? body) {
    try {
      return _parseSuppliers(body);
    } on Object {
      return null;
    }
  }

  List<StockPurchaseSupplierState> _parseSuppliers(Object? body) {
    if (body is! List<dynamic>) {
      throw const FormatException('Invalid purchase supplier response.');
    }
    return body
        .map(
          (item) => StockPurchaseSupplierState.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = api.token;
    final base = api.baseUrl.endsWith('/')
        ? api.baseUrl.substring(0, api.baseUrl.length - 1)
        : api.baseUrl;
    final uri = Uri.parse('$base$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    api.onProcessingChanged?.call(true);
    try {
      final encoded = body == null ? null : jsonEncode(body);
      final http.Response response = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'PATCH' => await http.patch(uri, headers: headers, body: encoded),
        'POST' => await http.post(uri, headers: headers, body: encoded),
        _ => throw ArgumentError('Unsupported HTTP method: $method'),
      };

      Object? decoded;
      if (response.body.trim().isNotEmpty) {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final errorBody = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final fieldErrors = <String, String>{};
      final rawFieldErrors = errorBody['fieldErrors'];
      if (rawFieldErrors is Map<String, dynamic>) {
        for (final entry in rawFieldErrors.entries) {
          fieldErrors[entry.key] = entry.value?.toString() ?? '';
        }
      }
      final error = EastAppApiException(
        statusCode: response.statusCode,
        code: errorBody['code']?.toString() ?? 'REQUEST_FAILED',
        message: errorBody['message']?.toString() ?? 'Request failed.',
        fieldErrors: fieldErrors,
        method: method,
        path: path,
        responseExcerpt: response.body,
      );
      api.onApiError?.call(error);
      throw error;
    } on EastAppApiException {
      rethrow;
    } catch (error) {
      final apiError = EastAppApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: error.toString(),
        method: method,
        path: path,
      );
      api.onApiError?.call(apiError);
      throw apiError;
    } finally {
      api.onProcessingChanged?.call(false);
    }
  }
}
