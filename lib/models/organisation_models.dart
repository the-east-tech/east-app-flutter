class EastAppTenant {
  final String id;
  final String companyCode;
  final String businessName;
  final String employeeIdPrefix;
  final bool active;
  final String googlePlaceId;
  final String googlePlaceName;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? googleMapsUri;

  const EastAppTenant({
    required this.id,
    required this.companyCode,
    required this.businessName,
    required this.employeeIdPrefix,
    this.active = true,
    this.googlePlaceId = '',
    this.googlePlaceName = '',
    this.formattedAddress = '',
    this.latitude = 0,
    this.longitude = 0,
    this.googleMapsUri,
  });

  bool get hasGoogleLocation => googlePlaceId.trim().isNotEmpty;

  String get workLocationName => googlePlaceName.trim().isEmpty
      ? businessName
      : googlePlaceName.trim();

  factory EastAppTenant.fromJson(Map<String, dynamic> json) {
    return EastAppTenant(
      id: json['id'] as String,
      companyCode: json['companyCode'] as String,
      businessName: (json['businessName'] ?? json['name']) as String,
      employeeIdPrefix: json['employeeIdPrefix'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      googlePlaceId: json['googlePlaceId'] as String? ?? '',
      googlePlaceName: json['googlePlaceName'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      googleMapsUri: json['googleMapsUri'] as String?,
    );
  }
}
