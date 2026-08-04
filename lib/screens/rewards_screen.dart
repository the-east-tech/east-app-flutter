import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class RewardsScreen extends StatelessWidget {
  final List<StaffTask> tasks;

  const RewardsScreen({
    super.key,
    required this.tasks,
  });

  int get approvedCount {
    return tasks.where((task) => task.status == RewardTaskStatus.approved).length;
  }

  int get averageScore {
    final approvedTasks = tasks
        .where((task) => task.status == RewardTaskStatus.approved)
        .where((task) => task.awardedScore != null)
        .toList();

    if (approvedTasks.isEmpty) return totalScore;

    final total = approvedTasks.fold<int>(
      0,
      (sum, task) => sum + (task.awardedScore ?? 0),
    );

    return (total / approvedTasks.length).round().clamp(0, 10).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
      children: [
        PageTitle(
          title: text.t('Rewards'),
          subtitle: text.t('Track your points and achievements'),
        ),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF009B43),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.t('Total Points Balance'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTextSize.s21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '$totalScore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTextSize.s48,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          text.t('Available for redemption'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTextSize.s21,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 58,
                    backgroundColor: Color(0x33FFFFFF),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      color: Colors.white,
                      size: 70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Container(
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: Color(0xFF009B43)),
                      const SizedBox(width: 14),
                      Text(
                        text.t('Redeem Points'),
                        style: TextStyle(
                          color: Color(0xFF009B43),
                          fontSize: AppTextSize.s20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _RewardStatCard(
                title: text.t('This Month'),
                value: '$thisMonthScore',
                subtitle: text.t('Points earned'),
                icon: Icons.trending_up_rounded,
                colour: AppColours.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _RewardStatCard(
                title: text.t('Completed'),
                value: '$approvedCount',
                subtitle: text.t('Reports done'),
                icon: Icons.check_circle_outline_rounded,
                colour: AppColours.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _RewardStatCard(
                title: text.t('Average'),
                value: '$averageScore',
                subtitle: text.t('Points/task'),
                icon: Icons.stars_rounded,
                colour: AppColours.purple,
              ),
            ),
            const Expanded(
              child: SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        WhiteCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.t('Recent Rewards'),
                style: TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              ...rewardHistory.map(
                (reward) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reward.title,
                              style: const TextStyle(
                                fontSize: AppTextSize.s22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children: [
                                SmallStatusPill(
                                  text: reward.category,
                                  textColour: AppColours.textMain,
                                  backgroundColour: Colors.white,
                                ),
                                Text(
                                  reward.approvedBy,
                                  style: const TextStyle(
                                    fontSize: AppTextSize.s17,
                                    color: AppColours.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reward.date,
                              style: const TextStyle(
                                fontSize: AppTextSize.s18,
                                color: AppColours.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '+${reward.score}',
                            style: const TextStyle(
                              color: AppColours.green,
                              fontSize: AppTextSize.s24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColours.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        WhiteCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.t('Points by Category'),
                style: TextStyle(fontSize: AppTextSize.s24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 30),
              ...categoryPoints.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category,
                              style: const TextStyle(
                                fontSize: AppTextSize.s22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.taskCount} tasks',
                              style: const TextStyle(
                                fontSize: AppTextSize.s18,
                                color: AppColours.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item.score} ${text.t('points')}',
                        style: const TextStyle(
                          color: AppColours.blue,
                          fontSize: AppTextSize.s22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color colour;

  const _RewardStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colour),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colour,
                  fontSize: AppTextSize.s17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: AppTextSize.s30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: AppTextSize.s18, color: AppColours.textMuted),
          ),
        ],
      ),
    );
  }
}
