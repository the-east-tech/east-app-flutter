class AdvertisementFeed {
  final List<Advertisement> advertisements;
  final DateTime serverTime;
  final DateTime? nextChangeAt;

  const AdvertisementFeed({
    required this.advertisements,
    required this.serverTime,
    required this.nextChangeAt,
  });

  factory AdvertisementFeed.fromJson(Map<String, dynamic> json) {
    return AdvertisementFeed(
      advertisements: (json['advertisements'] as List<dynamic>? ?? const [])
          .map(
            (item) => Advertisement.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      serverTime: DateTime.parse(json['serverTime'] as String).toLocal(),
      nextChangeAt: json['nextChangeAt'] == null
          ? null
          : DateTime.parse(json['nextChangeAt'] as String).toLocal(),
    );
  }

  Duration? get timeUntilNextChange {
    final next = nextChangeAt;
    if (next == null) return null;
    return next.difference(serverTime);
  }
}

class Advertisement {
  final String id;
  final String imageStorageKey;
  final DateTime startsAt;
  final DateTime endsAt;
  final int displayOrder;
  final bool active;

  const Advertisement({
    required this.id,
    required this.imageStorageKey,
    required this.startsAt,
    required this.endsAt,
    required this.displayOrder,
    required this.active,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: json['id'] as String,
      imageStorageKey: json['imageStorageKey'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      displayOrder: (json['displayOrder'] as num).toInt(),
      active: json['active'] as bool,
    );
  }

  AdvertisementPublicationStatus publicationStatus(DateTime now) {
    if (!active) return AdvertisementPublicationStatus.inactive;
    if (now.isBefore(startsAt)) return AdvertisementPublicationStatus.scheduled;
    if (!now.isBefore(endsAt)) return AdvertisementPublicationStatus.expired;
    return AdvertisementPublicationStatus.published;
  }
}

enum AdvertisementPublicationStatus {
  published,
  scheduled,
  expired,
  inactive,
}
