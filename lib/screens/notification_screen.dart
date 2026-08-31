import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import '../localization/app_text_scope.dart';
import '../models/notification_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';

class NotificationScreen extends StatefulWidget {
  final EastAppApi api;
  final String? initialNotificationId;
  final VoidCallback onChanged;

  const NotificationScreen({
    super.key,
    required this.api,
    required this.onChanged,
    this.initialNotificationId,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<EastAppNotification> items = const [];
  bool loading = true;
  bool openingInitial = false;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final page = await widget.api.notifications(size: 100);
      if (!mounted) return;
      setState(() {
        items = page.content;
        loading = false;
      });
      widget.onChanged();
      await openInitialIfNeeded();
    } on EastAppApiException {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openInitialIfNeeded() async {
    final id = widget.initialNotificationId;
    if (id == null || id.isEmpty || openingInitial) return;
    openingInitial = true;
    EastAppNotification? notification;
    for (final item in items) {
      if (item.id == id) {
        notification = item;
        break;
      }
    }
    if (notification == null) {
      try {
        notification = await widget.api.notificationDetail(id);
      } on EastAppApiException {
        return;
      }
    }
    if (!mounted) return;
    await openNotification(notification);
  }

  Future<void> openNotification(EastAppNotification notification) async {
    EastAppNotification resolved = notification;
    if (notification.isUnread) {
      try {
        resolved = await widget.api.markNotificationRead(notification.id);
        if (!mounted) return;
        setState(() {
          items = items
              .map((item) => item.id == resolved.id ? resolved : item)
              .toList(growable: false);
        });
        widget.onChanged();
      } on EastAppApiException {
        return;
      }
    }
    if (!mounted) return;
    AppFeedback.select();
    await showActivityEventDetails(context, resolved.event);
  }

  Future<bool> dismiss(
    EastAppNotification notification, {
    bool removeImmediately = true,
  }) async {
    try {
      await widget.api.dismissNotification(notification.id);
      if (!mounted) return true;
      if (removeImmediately) removeFromList(notification);
      AppFeedback.tap();
      return true;
    } on EastAppApiException {
      return false;
    }
  }

  void removeFromList(EastAppNotification notification) {
    if (!mounted) return;
    setState(() {
      items = items.where((item) => item.id != notification.id).toList();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Scaffold(
      backgroundColor: AppColours.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: IconButton(
                      onPressed: Navigator.of(context).pop,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Expanded(
                    child: PageTitle(
                      title: text.t('Notifications'),
                      subtitle: text.t('Business changes from other people'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (loading && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                WhiteCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          size: 42,
                          color: AppColours.textMuted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          text.t('No notifications yet.'),
                          style: AppTextStyles.formValue.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...items.map(
                  (notification) => Dismissible(
                    key: ValueKey(notification.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => dismiss(
                      notification,
                      removeImmediately: false,
                    ),
                    onDismissed: (_) => removeFromList(notification),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.only(right: 20),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: AppColours.red,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    child: _NotificationCard(
                      notification: notification,
                      onTap: () => openNotification(notification),
                      onDelete: () => dismiss(notification),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final EastAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final event = notification.event;
    final text = AppTextScope.of(context);
    final colour = activityModuleColour(event.module);
    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 7, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colour.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      activityModuleIcon(event.module),
                      color: colour,
                      size: 22,
                    ),
                  ),
                  if (notification.isUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColours.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.content(event.summary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSize.s15,
                        fontWeight: notification.isUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: AppColours.textMain,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${text.t(event.module)} · ${formatActivityDateTime(context, event.occurredAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        fontWeight: FontWeight.w600,
                        color: AppColours.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: text.t('Remove'),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: AppColours.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showActivityEventDetails(
  BuildContext context,
  EastAppActivityEvent event,
) async {
  final text = AppTextScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColours.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: activityModuleColour(event.module)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    activityModuleIcon(event.module),
                    color: activityModuleColour(event.module),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text.t('Activity Details'),
                    style: const TextStyle(
                      fontSize: AppTextSize.s22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailLine(label: text.t('Who'), value: event.actorName),
            _DetailLine(
              label: text.t('Employee ID'),
              value: event.actorEmployeeId,
            ),
            _DetailLine(
              label: text.t('Role'),
              value: activityRoleLabel(text, event.actorRole),
            ),
            _DetailLine(label: text.t('Area'), value: text.t(event.module)),
            _DetailLine(
              label: text.t('What happened'),
              value: text.content(event.summary),
            ),
            if (event.detail.isNotEmpty)
              _DetailLine(
                label: text.t('Details'),
                value: text.content(event.detail),
              ),
            _DetailLine(
              label: text.t('When'),
              value: formatActivityDateTime(context, event.occurredAt),
            ),
            if (event.targetId != null)
              _DetailLine(
                label: text.t('Record ID'),
                value: event.targetId!,
              ),
          ],
        ),
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: AppTextSize.s13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColours.textMain,
                fontWeight: FontWeight.w700,
                fontSize: AppTextSize.s14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatActivityDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} · '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String activityRoleLabel(AppText text, String systemKey) {
  final label = switch (systemKey) {
    'STAFF_1' => 'Staff 1',
    'STAFF_2' => 'Staff 2',
    'SUPERVISOR' => 'Supervisor',
    'MANAGER' => 'Manager',
    'HEAD' => 'Head',
    'OWNER' => 'Owner',
    _ => systemKey.replaceAll('_', ' '),
  };
  return text.t(label);
}

IconData activityModuleIcon(String module) {
  return switch (module.toLowerCase()) {
    'sales' || 'report' => Icons.analytics_outlined,
    'stock' => Icons.inventory_2_outlined,
    'attendance' => Icons.schedule_rounded,
    'people' => Icons.people_outline_rounded,
    'daily task' => Icons.task_alt_rounded,
    'knowledge' => Icons.school_outlined,
    'points' => Icons.stars_outlined,
    'advertising' => Icons.campaign_outlined,
    'complaint' => Icons.support_agent_rounded,
    'waste' => Icons.delete_sweep_outlined,
    'daily photo' => Icons.photo_camera_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

Color activityModuleColour(String module) {
  return switch (module.toLowerCase()) {
    'sales' || 'report' => AppColours.blue,
    'stock' => AppColours.green,
    'attendance' => const Color(0xFF7C3AED),
    'people' => const Color(0xFF0F766E),
    'daily task' => const Color(0xFFEA580C),
    'knowledge' => const Color(0xFF4F46E5),
    'points' => const Color(0xFFD97706),
    'complaint' => AppColours.red,
    _ => AppColours.textMuted,
  };
}
