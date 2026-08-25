class EastAppSetupStatus {
  final bool setupRequired;
  final String? setupCode;
  final DateTime? setupCodeExpiresAt;

  const EastAppSetupStatus({
    required this.setupRequired,
    required this.setupCode,
    required this.setupCodeExpiresAt,
  });

  factory EastAppSetupStatus.fromJson(Map<String, dynamic> json) {
    return EastAppSetupStatus(
      setupRequired: json['setupRequired'] as bool? ?? false,
      setupCode: json['setupCode'] as String?,
      setupCodeExpiresAt: json['setupCodeExpiresAt'] == null
          ? null
          : DateTime.parse(json['setupCodeExpiresAt'] as String),
    );
  }
}

class EastAppInitialSetupResult {
  final String companyCode;
  final String businessName;
  final String employeeId;

  const EastAppInitialSetupResult({
    required this.companyCode,
    required this.businessName,
    required this.employeeId,
  });

  factory EastAppInitialSetupResult.fromJson(Map<String, dynamic> json) {
    return EastAppInitialSetupResult(
      companyCode: json['companyCode'] as String,
      businessName: json['businessName'] as String,
      employeeId: json['employeeId'] as String,
    );
  }
}
