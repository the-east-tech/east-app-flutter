import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class TasksScreen extends StatefulWidget {
  final UserRole role;
  final List<StaffTask> tasks;
  final void Function({required StaffTask task, required String remark}) onSubmitTask;
  final void Function({required StaffTask task, required int score}) onApproveTask;
  final void Function({required StaffTask task, required String reason}) onRejectTask;

  const TasksScreen({
    super.key,
    required this.role,
    required this.tasks,
    required this.onSubmitTask,
    required this.onApproveTask,
    required this.onRejectTask,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int selectedTab = 0;

  bool get isManager => widget.role != UserRole.staff;

  List<StaffTask> get filteredTasks {
    if (isManager) {
      switch (selectedTab) {
        case 1:
          return widget.tasks
              .where((task) => task.status == RewardTaskStatus.approved)
              .toList();
        case 2:
          return widget.tasks
              .where((task) => task.status == RewardTaskStatus.rejected)
              .toList();
        default:
          return widget.tasks
              .where((task) => task.status == RewardTaskStatus.submitted)
              .toList();
      }
    }

    switch (selectedTab) {
      case 1:
        return widget.tasks
            .where(
              (task) =>
                  task.status == RewardTaskStatus.pending ||
                  task.status == RewardTaskStatus.inProgress ||
                  task.status == RewardTaskStatus.rejected,
            )
            .toList();
      case 2:
        return widget.tasks
            .where((task) => task.status == RewardTaskStatus.submitted)
            .toList();
      case 3:
        return widget.tasks
            .where((task) => task.status == RewardTaskStatus.approved)
            .toList();
      default:
        return widget.tasks;
    }
  }

  int get approvedCount {
    return widget.tasks
        .where((task) => task.status == RewardTaskStatus.approved)
        .length;
  }

  int get submittedCount {
    return widget.tasks
        .where((task) => task.status == RewardTaskStatus.submitted)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final tabs = isManager
        ? [text.t('Pending Review'), text.t('Approved'), text.t('Rejected')]
        : [text.t('All'), text.t('Pending'), text.t('Submitted'), text.t('Approved')];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
      children: [
        PageTitle(
          title: isManager ? text.t('Task Approvals') : text.t('Daily Tasks'),
          subtitle: isManager
              ? text.t('Review staff submissions and rate out of 10')
              : text.t('Complete tasks to earn points'),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColours.blue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isManager ? text.t('Pending Reviews') : text.t("Today's Progress"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.s21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    isManager
                        ? '$submittedCount'
                        : '$approvedCount/${widget.tasks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppTextSize.s28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: widget.tasks.isEmpty
                      ? 0
                      : approvedCount / widget.tasks.length,
                  minHeight: 12,
                  backgroundColor: AppColours.blueSoft,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF050014),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SegmentedTabs(
          tabs: tabs,
          selectedIndex: selectedTab,
          onChanged: (index) {
            setState(() {
              selectedTab = index;
            });
          },
        ),
        const SizedBox(height: 26),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Column(
            key: ValueKey('${widget.role}-$selectedTab-${filteredTasks.length}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: filteredTasks.map((task) {
              if (isManager) {
                return _ManagerTaskCard(
                  task: task,
                  onReview: task.status == RewardTaskStatus.submitted
                      ? () => showManagerReviewDialog(
                            context,
                            task,
                            onApproved: (score) {
                              widget.onApproveTask(task: task, score: score);
                              showSuccessSnackBar(
                                context,
                                '${text.t('Task approved')} +$score',
                              );
                            },
                            onRejected: (reason) {
                              widget.onRejectTask(task: task, reason: reason);
                              showSuccessSnackBar(context, text.t('Task rejected'));
                            },
                          )
                      : null,
                );
              }

              if (task.status == RewardTaskStatus.approved) {
                return _ApprovedTaskCard(task: task);
              }

              if (task.status == RewardTaskStatus.submitted) {
                return _SubmittedTaskCard(task: task);
              }

              return _TaskCard(
                task: task,
                onViewSop: () => showSopDialog(context, task),
                onSubmit: () => showSubmitTaskDialog(
                  context,
                  task,
                  onSubmitted: (remark) {
                    widget.onSubmitTask(task: task, remark: remark);
                    setState(() {
                      selectedTab = 2;
                    });
                    showSuccessSnackBar(
                      context,
                      text.t('Task submitted for manager approval'),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StaffTask task;
  final VoidCallback onViewSop;
  final VoidCallback onSubmit;

  const _TaskCard({
    required this.task,
    required this.onViewSop,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final inProgress = task.status == RewardTaskStatus.inProgress;
    final rejected = task.status == RewardTaskStatus.rejected;

    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: AppTextSize.s26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SmallStatusPill(
                text: text.t(rejected ? 'rejected' : inProgress ? 'in_progress' : 'pending'),
                icon: Icons.access_time_rounded,
                textColour: rejected
                    ? AppColours.red
                    : inProgress
                        ? const Color(0xFFC73500)
                        : AppColours.textMain,
                backgroundColour: rejected
                    ? AppColours.redSoft
                    : inProgress
                        ? AppColours.orangeSoft
                        : AppColours.mutedBox,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rejected ? (task.rejectedText ?? task.description) : task.description,
            style: const TextStyle(
              fontSize: AppTextSize.s21,
              color: AppColours.textMuted,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          _TaskMetaRow(task: task),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: text.t('View SOP'),
                  icon: Icons.play_arrow_rounded,
                  outlined: true,
                  onPressed: onViewSop,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: text.t('Submit Task'),
                  icon: Icons.upload_rounded,
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmittedTaskCard extends StatelessWidget {
  final StaffTask task;

  const _SubmittedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: AppTextSize.s26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SmallStatusPill(
                text: text.t('submitted'),
                icon: Icons.schedule_send_rounded,
                textColour: AppColours.blue,
                backgroundColour: const Color(0xFFEAF3FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.description,
            style: const TextStyle(
              fontSize: AppTextSize.s21,
              color: AppColours.textMuted,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          _TaskMetaRow(task: task),
          const SizedBox(height: 18),
          Text(
            task.submittedText == 'Submitted just now' ? text.t('Submitted just now') : (task.submittedText ?? text.t('Submitted recently')),
            style: const TextStyle(
              fontSize: AppTextSize.s19,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovedTaskCard extends StatelessWidget {
  final StaffTask task;

  const _ApprovedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColours.greenSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC7F0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: const TextStyle(
              fontSize: AppTextSize.s24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00633A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            task.approvedText ?? '+${task.awardedScore ?? task.maxScore} ${text.t('points earned')}',
            style: const TextStyle(
              fontSize: AppTextSize.s20,
              color: Color(0xFF007A45),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerTaskCard extends StatelessWidget {
  final StaffTask task;
  final VoidCallback? onReview;

  const _ManagerTaskCard({
    required this.task,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final approved = task.status == RewardTaskStatus.approved;
    final rejected = task.status == RewardTaskStatus.rejected;

    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: AppTextSize.s25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SmallStatusPill(
                text: text.t(approved ? 'approved' : rejected ? 'rejected' : 'submitted'),
                textColour: approved
                    ? AppColours.green
                    : rejected
                        ? AppColours.red
                        : AppColours.blue,
                backgroundColour: approved
                    ? AppColours.greenSoft
                    : rejected
                        ? AppColours.redSoft
                        : const Color(0xFFEAF3FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Submitted by ${task.staffName} · ${task.staffId}',
            style: const TextStyle(
              fontSize: AppTextSize.s19,
              color: AppColours.textMuted,
            ),
          ),
          if (task.staffRemark != null) ...[
            const SizedBox(height: 10),
            Text(
              'Remark: ${task.staffRemark}',
              style: const TextStyle(
                fontSize: AppTextSize.s18,
                color: AppColours.textMuted,
              ),
            ),
          ],
          if (task.awardedScore != null) ...[
            const SizedBox(height: 12),
            Text(
              'Score: ${task.awardedScore}/10',
              style: const TextStyle(
                fontSize: AppTextSize.s20,
                color: AppColours.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onReview != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(
              text: text.t('Review Submission'),
              icon: Icons.rate_review_outlined,
              onPressed: onReview,
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskMetaRow extends StatelessWidget {
  final StaffTask task;

  const _TaskMetaRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars_rounded,
              color: AppColours.gold,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              '${task.maxScore} ${text.t('points')}',
              style: const TextStyle(
                fontSize: AppTextSize.s19,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SmallStatusPill(
          text: task.category,
          textColour: AppColours.textMain,
          backgroundColour: AppColours.mutedBox,
        ),
        if (task.photoRequired)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 18,
                color: AppColours.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                text.t('Photo required'),
                style: TextStyle(
                  fontSize: AppTextSize.s17,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

void showSubmitTaskDialog(
  BuildContext context,
  StaffTask task, {
  required void Function(String remark) onSubmitted,
}) {
  final text = AppTextScope.of(context);
  final remarkController = TextEditingController();
  bool photoUploaded = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text.t('Submit Task'),
                            style: TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      style: const TextStyle(fontSize: AppTextSize.s21, color: AppColours.textMuted),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      text.t('Upload Photo Evidence *'),
                      style: TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Pressable(
                      onTap: () => setDialogState(() => photoUploaded = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 210,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColours.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: photoUploaded ? AppColours.blue : AppColours.border,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              photoUploaded
                                  ? Icons.check_circle_rounded
                                  : Icons.camera_alt_outlined,
                              color: photoUploaded ? AppColours.blue : AppColours.textMuted,
                              size: 54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              photoUploaded ? text.t('Photo selected') : text.t('Click to upload photo'),
                              style: const TextStyle(
                                fontSize: AppTextSize.s20,
                                color: AppColours.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      text.t('Remarks (Optional)'),
                      style: TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: text.t('Add any additional notes...'),
                        hintStyle: const TextStyle(fontSize: AppTextSize.s20, color: AppColours.textMuted),
                        filled: true,
                        fillColor: AppColours.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: text.t('Submit for Approval'),
                      onPressed: photoUploaded
                          ? () async {
                              final confirmed = await confirmDataChange(
                                context,
                                action: 'Submit Task?',
                                details:
                                    'This will submit the task and photo evidence for manager review.',
                              );
                              if (!confirmed || !context.mounted) return;
                              Navigator.of(context).pop();
                              onSubmitted(remarkController.text);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).then((_) => remarkController.dispose());
}

void showManagerReviewDialog(
  BuildContext context,
  StaffTask task, {
  required void Function(int score) onApproved,
  required void Function(String reason) onRejected,
}) {
  final text = AppTextScope.of(context);
  final rejectReasonController = TextEditingController();
  int score = task.awardedScore ?? 8;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text.t('Review Submission'),
                            style: TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${task.title}\nSubmitted by ${task.staffName} · ${task.staffId}',
                      style: const TextStyle(fontSize: AppTextSize.s19, color: AppColours.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      text.t('Photo Evidence'),
                      style: TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 190,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColours.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColours.border, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_outlined, size: 54, color: AppColours.blue),
                          const SizedBox(height: 12),
                          Text(
                            task.photoEvidenceName ?? 'submitted_photo.jpg',
                            style: const TextStyle(
                              fontSize: AppTextSize.s18,
                              color: AppColours.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      text.t('Staff Remark'),
                      style: TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.staffRemark ?? text.t('No remark provided.'),
                      style: const TextStyle(fontSize: AppTextSize.s19, color: AppColours.textMuted),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text.t('Manager Score'),
                            style: TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '$score/10',
                          style: const TextStyle(
                            fontSize: AppTextSize.s24,
                            color: AppColours.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: score.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: '$score/10',
                      activeColor: AppColours.blue,
                      onChanged: (value) {
                        setDialogState(() => score = value.round());
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rejectReasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: text.t('Reject reason, optional'),
                        hintStyle: const TextStyle(fontSize: AppTextSize.s18, color: AppColours.textMuted),
                        filled: true,
                        fillColor: AppColours.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: text.t('Reject'),
                            icon: Icons.close_rounded,
                            outlined: true,
                            onPressed: () async {
                              final confirmed = await confirmDataChange(
                                context,
                                action: 'Reject Task?',
                                details:
                                    'This will reject the submitted task and save the review result.',
                              );
                              if (!confirmed || !context.mounted) return;
                              Navigator.of(context).pop();
                              onRejected(rejectReasonController.text);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            text: text.t('Approve'),
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              final confirmed = await confirmDataChange(
                                context,
                                action: 'Approve Task?',
                                details:
                                    'This will approve the submitted task and award the selected score.',
                              );
                              if (!confirmed || !context.mounted) return;
                              Navigator.of(context).pop();
                              onApproved(score);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).then((_) => rejectReasonController.dispose());
}

void showSopDialog(BuildContext context, StaffTask task) {
  final text = AppTextScope.of(context);
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(fontSize: AppTextSize.s25, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  text.t('Standard Operating Procedure'),
                  style: TextStyle(fontSize: AppTextSize.s20, color: AppColours.textMuted),
                ),
                const SizedBox(height: 28),
                Container(
                  height: 270,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColours.mutedBox,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: AppColours.blue, size: 90),
                      const SizedBox(height: 12),
                      Text(
                        text.t('Video tutorial available'),
                        style: TextStyle(fontSize: AppTextSize.s20, color: AppColours.textMuted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColours.blue),
                        onPressed: () {},
                        child: Text(
                          text.t('Watch Video'),
                          style: TextStyle(fontSize: AppTextSize.s18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  text.t('Expected Outcome:'),
                  style: TextStyle(fontSize: AppTextSize.s23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(
                  task.sopOutcome,
                  style: const TextStyle(fontSize: AppTextSize.s20, color: AppColours.textMuted),
                ),
                const SizedBox(height: 28),
                Text(
                  text.t('Description:'),
                  style: TextStyle(fontSize: AppTextSize.s23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(
                  task.sopDescription,
                  style: const TextStyle(fontSize: AppTextSize.s20, color: AppColours.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
