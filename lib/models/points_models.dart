class EastAppLeaderboardMember {
  final String userId;
  final String employeeId;
  final String fullName;
  final String roleName;
  final int totalPoints;
  final int rank;
  final bool currentUser;

  const EastAppLeaderboardMember({
    required this.userId,
    required this.employeeId,
    required this.fullName,
    required this.roleName,
    required this.totalPoints,
    required this.rank,
    required this.currentUser,
  });

  factory EastAppLeaderboardMember.fromJson(Map<String, dynamic> json) {
    return EastAppLeaderboardMember(
      userId: json['userId'] as String,
      employeeId: json['employeeId'] as String,
      fullName: json['fullName'] as String,
      roleName: json['roleName'] as String,
      totalPoints: (json['totalPoints'] as num).toInt(),
      rank: (json['rank'] as num).toInt(),
      currentUser: json['currentUser'] as bool,
    );
  }
}

class EastAppLeaderboard {
  final int currentUserTotalPoints;
  final int? currentUserRank;
  final List<EastAppLeaderboardMember> members;

  const EastAppLeaderboard({
    required this.currentUserTotalPoints,
    required this.currentUserRank,
    required this.members,
  });

  factory EastAppLeaderboard.fromJson(Map<String, dynamic> json) {
    return EastAppLeaderboard(
      currentUserTotalPoints:
          (json['currentUserTotalPoints'] as num).toInt(),
      currentUserRank: (json['currentUserRank'] as num?)?.toInt(),
      members: (json['members'] as List<dynamic>)
          .map(
            (item) => EastAppLeaderboardMember.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class EastAppPointAdjustment {
  final String id;
  final String userId;
  final String employeeId;
  final String fullName;
  final int pointsDelta;
  final int totalPoints;
  final String reason;
  final String adjustedByUserId;
  final String adjustedByName;
  final DateTime createdAt;

  const EastAppPointAdjustment({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.fullName,
    required this.pointsDelta,
    required this.totalPoints,
    required this.reason,
    required this.adjustedByUserId,
    required this.adjustedByName,
    required this.createdAt,
  });

  factory EastAppPointAdjustment.fromJson(Map<String, dynamic> json) {
    return EastAppPointAdjustment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      employeeId: json['employeeId'] as String,
      fullName: json['fullName'] as String,
      pointsDelta: (json['pointsDelta'] as num).toInt(),
      totalPoints: (json['totalPoints'] as num).toInt(),
      reason: json['reason'] as String,
      adjustedByUserId: json['adjustedByUserId'] as String,
      adjustedByName: json['adjustedByName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
