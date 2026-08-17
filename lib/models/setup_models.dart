class EastAppSetupStatus {
  final bool setupRequired;

  const EastAppSetupStatus({required this.setupRequired});

  factory EastAppSetupStatus.fromJson(Map<String, dynamic> json) {
    return EastAppSetupStatus(
      setupRequired: json['setupRequired'] as bool? ?? false,
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
