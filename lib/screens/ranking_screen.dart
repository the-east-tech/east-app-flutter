import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/points_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class RankingScreen extends StatelessWidget {
  final EastAppLeaderboard leaderboard;

  const RankingScreen({
    super.key,
    required this.leaderboard,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PageTitle(
          title: text.t('Leaderboard'),
          subtitle: text.t('Current business · All time'),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColours.blue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t('Your Current Rank'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.s15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      leaderboard.currentUserRank == null
                          ? '-'
                          : '#${leaderboard.currentUserRank}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.s30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${leaderboard.currentUserTotalPoints} ${text.t('points')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.s15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0x33FFFFFF),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (leaderboard.members.isEmpty)
          WhiteCard(
            child: Text(text.t('No active users found.')),
          )
        else
          ...leaderboard.members.map(
            (member) => _LeaderboardRow(member: member),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final EastAppLeaderboardMember member;

  const _LeaderboardRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final rankColour = member.rank == 1
        ? AppColours.gold
        : member.rank == 2
            ? const Color(0xFF9CA3AF)
            : member.rank == 3
                ? const Color(0xFFC45A00)
                : AppColours.blue;

    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: rankColour.withValues(alpha: 0.14),
            child: Text(
              '#${member.rank}',
              style: TextStyle(
                color: rankColour,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 22,
            backgroundColor: member.currentUser
                ? AppColours.blueSoft
                : const Color(0xFFE5E7EB),
            child: Icon(
              member.currentUser
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              color: AppColours.textMain,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: const TextStyle(
                    fontSize: AppTextSize.s16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${member.employeeId} · ${text.t(member.roleName)}',
                  style: const TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${member.totalPoints} ${text.t('points')}',
            style: const TextStyle(
              fontSize: AppTextSize.s16,
              color: AppColours.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
