class FlowGooglePlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const FlowGooglePlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  factory FlowGooglePlacePrediction.fromJson(Map<String, dynamic> json) {
    return FlowGooglePlacePrediction(
      placeId: json['placeId'] as String,
      mainText: json['mainText'] as String? ?? '',
      secondaryText: json['secondaryText'] as String? ?? '',
      fullText: json['fullText'] as String? ?? '',
    );
  }
}

class FlowGooglePlaceDetails {
  final String placeId;
  final String displayName;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? googleMapsUri;
  final double? rating;
  final int? userRatingCount;

  const FlowGooglePlaceDetails({
    required this.placeId,
    required this.displayName,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.googleMapsUri,
    this.rating,
    this.userRatingCount,
  });

  factory FlowGooglePlaceDetails.fromJson(Map<String, dynamic> json) {
    return FlowGooglePlaceDetails(
      placeId: json['placeId'] as String,
      displayName: json['displayName'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      googleMapsUri: json['googleMapsUri'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
    );
  }
}

class FlowGoogleRating {
  final String businessName;
  final String placeId;
  final String placeName;
  final String formattedAddress;
  final String? googleMapsUri;
  final double? rating;
  final int? userRatingCount;
  final String attribution;

  const FlowGoogleRating({
    required this.businessName,
    required this.placeId,
    required this.placeName,
    required this.formattedAddress,
    required this.googleMapsUri,
    required this.rating,
    required this.userRatingCount,
    required this.attribution,
  });

  factory FlowGoogleRating.fromJson(Map<String, dynamic> json) {
    return FlowGoogleRating(
      businessName: json['businessName'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      placeName: json['placeName'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      googleMapsUri: json['googleMapsUri'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
      attribution: json['attribution'] as String? ?? 'Google Maps',
    );
  }
}
