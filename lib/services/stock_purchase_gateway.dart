import 'east_app_api.dart';

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
}

class StockPurchaseGateway {
  final EastAppApi api;
  final String tenantId;

  const StockPurchaseGateway(
    this.api, {
    required this.tenantId,
  });

  Future<List<StockPurchaseSupplierState>> suppliers({
    bool forceRefresh = false,
  }) async {
    final body = await api.loadStockPurchaseSupplierStates(
      tenantId: tenantId,
      forceRefresh: forceRefresh,
    );
    final parsed = _tryParseSuppliers(body);
    if (parsed != null) return parsed;
    await invalidateCache();
    if (forceRefresh) {
      return _parseSuppliers(body);
    }
    return _parseSuppliers(
      await api.loadStockPurchaseSupplierStates(
        tenantId: tenantId,
        forceRefresh: true,
      ),
    );
  }

  Future<void> invalidateCache() =>
      api.invalidateStockPurchaseSupplierStates(tenantId);

  Future<StockPurchaseSupplierState> saveTemplate(
    String supplierId,
    String messageTemplate,
  ) async {
    final body = await api.saveStockPurchaseTemplate(
      supplierId: supplierId,
      messageTemplate: messageTemplate,
    );
    final saved = _parseSupplier(
      body,
      method: 'PATCH',
      path: '/api/v1/stock/purchases/suppliers/$supplierId/template',
    );
    await _invalidateCacheSafely();
    return saved;
  }

  Future<StockPurchaseSupplierState> markOrdered(
    String supplierId,
    String message,
  ) async {
    final body = await api.markStockPurchaseSupplierOrdered(
      supplierId: supplierId,
      message: message,
    );
    final saved = _parseSupplier(
      body,
      method: 'POST',
      path: '/api/v1/stock/purchases/suppliers/$supplierId/ordered',
    );
    await _invalidateCacheSafely();
    return saved;
  }

  Future<void> _invalidateCacheSafely() async {
    try {
      await invalidateCache();
    } on Object {
      // The server mutation succeeded; cache cleanup must not invite a retry.
    }
  }

  StockPurchaseSupplierState _parseSupplier(
    Object? body, {
    required String method,
    required String path,
  }) {
    try {
      return StockPurchaseSupplierState.fromJson(
        Map<String, dynamic>.from(body as Map),
      );
    } on Object {
      throw _invalidResponse(method: method, path: path);
    }
  }

  List<StockPurchaseSupplierState>? _tryParseSuppliers(Object? body) {
    try {
      return _decodeSuppliers(body);
    } on Object {
      return null;
    }
  }

  List<StockPurchaseSupplierState> _parseSuppliers(Object? body) {
    try {
      return _decodeSuppliers(body);
    } on Object {
      throw _invalidResponse(
        method: 'GET',
        path: '/api/v1/stock/purchases/suppliers',
      );
    }
  }

  List<StockPurchaseSupplierState> _decodeSuppliers(Object? body) {
    if (body is! List<dynamic>) throw const FormatException();
    return body
        .map(
          (item) => StockPurchaseSupplierState.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  EastAppApiException _invalidResponse({
    required String method,
    required String path,
  }) {
    final error = EastAppApiException(
      statusCode: null,
      code: 'INVALID_API_RESPONSE',
      message: 'The application server returned invalid purchase data.',
      method: method,
      path: path,
    );
    api.onApiError?.call(error);
    return error;
  }
}
