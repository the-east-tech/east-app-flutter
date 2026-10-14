class FlowSetupStatus {
  final bool setupRequired;
  final String? setupCode;
  final DateTime? setupCodeExpiresAt;

  const FlowSetupStatus({
    required this.setupRequired,
    required this.setupCode,
    required this.setupCodeExpiresAt,
  });

  factory FlowSetupStatus.fromJson(Map<String, dynamic> json) {
    return FlowSetupStatus(
      setupRequired: json['setupRequired'] as bool? ?? false,
      setupCode: json['setupCode'] as String?,
      setupCodeExpiresAt: json['setupCodeExpiresAt'] == null
          ? null
          : DateTime.parse(json['setupCodeExpiresAt'] as String),
    );
  }
}

class FlowInitialSetupResult {
  final String companyCode;
  final String businessName;
  final String employeeId;

  const FlowInitialSetupResult({
    required this.companyCode,
    required this.businessName,
    required this.employeeId,
  });

  factory FlowInitialSetupResult.fromJson(Map<String, dynamic> json) {
    return FlowInitialSetupResult(
      companyCode: json['companyCode'] as String,
      businessName: json['businessName'] as String,
      employeeId: json['employeeId'] as String,
    );
  }
}
