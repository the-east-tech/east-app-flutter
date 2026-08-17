class EastAppGooglePlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const EastAppGooglePlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  factory EastAppGooglePlacePrediction.fromJson(Map<String, dynamic> json) {
    return EastAppGooglePlacePrediction(
      placeId: json['placeId'] as String,
      mainText: json['mainText'] as String? ?? '',
      secondaryText: json['secondaryText'] as String? ?? '',
      fullText: json['fullText'] as String? ?? '',
    );
  }
}

class EastAppGooglePlaceDetails {
  final String placeId;
  final String displayName;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? googleMapsUri;
  final double? rating;
  final int? userRatingCount;

  const EastAppGooglePlaceDetails({
    required this.placeId,
    required this.displayName,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.googleMapsUri,
    this.rating,
    this.userRatingCount,
  });

  factory EastAppGooglePlaceDetails.fromJson(Map<String, dynamic> json) {
    return EastAppGooglePlaceDetails(
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

class EastAppGoogleRating {
  final String businessName;
  final String placeId;
  final String placeName;
  final String formattedAddress;
  final String? googleMapsUri;
  final double? rating;
  final int? userRatingCount;
  final String attribution;

  const EastAppGoogleRating({
    required this.businessName,
    required this.placeId,
    required this.placeName,
    required this.formattedAddress,
    required this.googleMapsUri,
    required this.rating,
    required this.userRatingCount,
    required this.attribution,
  });

  factory EastAppGoogleRating.fromJson(Map<String, dynamic> json) {
    return EastAppGoogleRating(
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
