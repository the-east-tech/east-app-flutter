import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/points_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';

class PeoplePointsScreen extends StatefulWidget {
  final EastAppApi api;
  final EastAppLeaderboard? initialLeaderboard;
  final VoidCallback onBack;
  final ValueChanged<EastAppLeaderboard> onLeaderboardChanged;

  const PeoplePointsScreen({
    super.key,
    required this.api,
    required this.initialLeaderboard,
    required this.onBack,
    required this.onLeaderboardChanged,
  });

  @override
  State<PeoplePointsScreen> createState() => _PeoplePointsScreenState();
}

class _PeoplePointsScreenState extends State<PeoplePointsScreen> {
  final TextEditingController reasonController = TextEditingController();
  EastAppLeaderboard? leaderboard;
  String? selectedUserId;
  String? validationMessage;
  int pointsDelta = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    leaderboard = widget.initialLeaderboard;
    _selectFirstUser();
    if (leaderboard == null) _loadLeaderboard();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _selectFirstUser() {
    final members = leaderboard?.members ?? const <EastAppLeaderboardMember>[];
    if (members.isEmpty) {
      selectedUserId = null;
      return;
    }
    if (selectedUserId == null ||
        !members.any((member) => member.userId == selectedUserId)) {
      selectedUserId = members.first.userId;
    }
  }

  Future<void> _loadLeaderboard() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final value = await widget.api.pointsLeaderboard();
      if (!mounted) return;
      setState(() {
        leaderboard = value;
        loading = false;
        _selectFirstUser();
      });
      widget.onLeaderboardChanged(value);
    } on EastAppApiException {
      if (mounted) setState(() => loading = false);
    }
  }

  EastAppLeaderboardMember? get selectedUser {
    final userId = selectedUserId;
    if (userId == null) return null;
    for (final member
        in leaderboard?.members ?? const <EastAppLeaderboardMember>[]) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  void _decrease() {
    if (pointsDelta <= -10) return;
    AppFeedback.select();
    setState(() {
      pointsDelta -= 1;
      validationMessage = null;
    });
  }

  void _increase() {
    if (pointsDelta >= 10) return;
    AppFeedback.select();
    setState(() {
      pointsDelta += 1;
      validationMessage = null;
    });
  }

  Future<void> _apply() async {
    final text = AppTextScope.of(context);
    final user = selectedUser;
    final reason = reasonController.text.trim();
    if (user == null) {
      setState(() => validationMessage = 'Select an active user.');
      return;
    }
    if (pointsDelta == 0) {
      setState(() => validationMessage = 'Choose at least +1 or -1 point.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => validationMessage = 'Reason is compulsory.');
      return;
    }

    final sign = pointsDelta > 0 ? '+' : '';
    final confirmed = await confirmDataChange(
      context,
      action: 'Confirm point adjustment',
      details:
          '$sign$pointsDelta point${pointsDelta.abs() == 1 ? '' : 's'} for ${user.fullName}.\n\nReason: $reason',
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.api.adjustUserPoints(
        userId: user.userId,
        pointsDelta: pointsDelta,
        reason: reason,
      );
      final updated = await widget.api.pointsLeaderboard();
      if (!mounted) return;
      setState(() {
        leaderboard = updated;
        pointsDelta = 0;
        reasonController.clear();
        validationMessage = null;
        _selectFirstUser();
      });
      widget.onLeaderboardChanged(updated);
      showSuccessSnackBar(context, text.t('Points updated'));
    } on EastAppApiException {
      // Global API error handling already shows the technical error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final data = leaderboard;
    final members = data?.members ?? const <EastAppLeaderboardMember>[];
    final deltaColour = pointsDelta < 0
        ? AppColours.red
        : pointsDelta > 0
            ? AppColours.green
            : AppColours.textMuted;
    final deltaText = pointsDelta > 0 ? '+$pointsDelta' : '$pointsDelta';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: text.t('Back'),
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t('Points'),
                    style: const TextStyle(
                      fontSize: AppTextSize.s30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    text.t('Assign or deduct accumulated points'),
                    style: const TextStyle(
                      color: AppColours.textMuted,
                      fontSize: AppTextSize.s15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.t('Point Adjustment'),
                style: const TextStyle(
                  fontSize: AppTextSize.s17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedUserId,
                decoration: InputDecoration(
                  labelText: text.t('Active User'),
                  border: const OutlineInputBorder(),
                ),
                items: members
                    .map(
                      (member) => DropdownMenuItem<String>(
                        value: member.userId,
                        child: Text(
                          '${member.fullName} · ${member.employeeId} · ${member.totalPoints} ${text.t('points')}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: members.isEmpty
                    ? null
                    : (value) => setState(() {
                          selectedUserId = value;
                          validationMessage = null;
                        }),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: text.t('Decrease 1 point'),
                    onPressed: pointsDelta <= -10 ? null : _decrease,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        Text(
                          deltaText,
                          style: TextStyle(
                            color: deltaColour,
                            fontSize: AppTextSize.s30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          text.t('Pending'),
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  IconButton.filled(
                    tooltip: text.t('Add 1 point'),
                    onPressed: pointsDelta >= 10 ? null : _increase,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLength: 300,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: text.t('Reason *'),
                  hintText: text.t('Compulsory reason for this adjustment'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (validationMessage != null) {
                    setState(() => validationMessage = null);
                  }
                },
              ),
              if (validationMessage != null) ...[
                Text(
                  text.t(validationMessage!),
                  style: const TextStyle(
                    color: AppColours.red,
                    fontSize: AppTextSize.s13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: members.isEmpty ? null : _apply,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(text.t('Apply Adjustment')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                text.t('Current Business Ranking'),
                style: const TextStyle(
                  fontSize: AppTextSize.s17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: text.t('Refresh'),
              onPressed: loading ? null : _loadLeaderboard,
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (members.isEmpty && !loading)
          WhiteCard(
            child: Text(text.t('No active users found.')),
          )
        else
          ...members.map(
            (member) => WhiteCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: member.currentUser
                        ? AppColours.blueSoft
                        : AppColours.background,
                    child: Text(
                      '#${member.rank}',
                      style: const TextStyle(
                        color: AppColours.blue,
                        fontWeight: FontWeight.w800,
                      ),
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
                            fontSize: AppTextSize.s15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${member.employeeId} · ${text.t(member.roleName)}',
                          style: const TextStyle(
                            color: AppColours.textMuted,
                            fontSize: AppTextSize.s12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${member.totalPoints}',
                    style: const TextStyle(
                      color: AppColours.blue,
                      fontSize: AppTextSize.s18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
