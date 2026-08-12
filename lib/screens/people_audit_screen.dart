import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/attendance_models.dart';
import '../models/people_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';

class PeopleAuditScreen extends StatefulWidget {
  final EastAppApi api;
  final VoidCallback onBack;

  const PeopleAuditScreen({
    super.key,
    required this.api,
    required this.onBack,
  });

  @override
  State<PeopleAuditScreen> createState() => _PeopleAuditScreenState();
}

class _PeopleAuditScreenState extends State<PeopleAuditScreen> {
  static const int _pageSize = 20;

  final TextEditingController searchController = TextEditingController();
  final List<EastAppUser> users = [];
  int usersPage = 0;
  int totalUsers = 0;
  bool usersLastPage = true;
  bool usersLoading = false;
  bool usersLoadingMore = false;
  bool hasSearchedUsers = false;
  String? usersError;
  bool? activeFilter;

  EastAppUser? selectedUser;
  AttendanceAuditPeriod period = AttendanceAuditPeriod.day;
  DateTime anchor = DateTime.now();
  EastAppAttendanceUserDetail? detail;
  final List<EastAppAttendanceEvent> events = [];
  final List<EastAppAttendanceFaceAttempt> faceAttempts = [];
  int eventsPage = 0;
  bool eventsLastPage = true;
  bool reportLoading = false;
  bool eventsLoadingMore = false;
  String? reportError;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers({required bool reset}) async {
    if (usersLoading || usersLoadingMore) return;
    final nextPage = reset ? 0 : usersPage + 1;
    setState(() {
      if (reset) {
        usersLoading = true;
        usersError = null;
        hasSearchedUsers = true;
        selectedUser = null;
        _clearReport();
      } else {
        usersLoadingMore = true;
      }
    });

    try {
      final result = await widget.api.listUsers(
        search: searchController.text,
        active: activeFilter,
        page: nextPage,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) users.clear();
        users.addAll(result.content);
        usersPage = result.page;
        totalUsers = result.totalElements;
        usersLastPage = result.last;
        usersLoading = false;
        usersLoadingMore = false;
      });
    } on EastAppApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        usersError = exception.message;
        usersLoading = false;
        usersLoadingMore = false;
      });
    }
  }

  void changeActiveFilter(bool? value) {
    if (activeFilter == value) return;
    AppFeedback.select();
    setState(() {
      activeFilter = value;
      users.clear();
      totalUsers = 0;
      hasSearchedUsers = false;
      usersError = null;
      selectedUser = null;
      _clearReport();
    });
  }

  Future<void> selectUser(EastAppUser user) async {
    if (selectedUser?.id == user.id && detail != null) return;
    AppFeedback.select();
    setState(() {
      selectedUser = user;
      _clearReport();
    });
    await loadReport(reset: true);
  }

  Future<void> loadReport({required bool reset}) async {
    final user = selectedUser;
    if (user == null || reportLoading || eventsLoadingMore) return;
    final nextPage = reset ? 0 : eventsPage + 1;
    setState(() {
      if (reset) {
        reportLoading = true;
        reportError = null;
        detail = null;
        events.clear();
        eventsPage = 0;
        eventsLastPage = true;
      } else {
        eventsLoadingMore = true;
      }
    });

    try {
      final detailFuture = widget.api.attendanceUserAudit(
        userId: user.id,
        period: period,
        anchor: anchor,
        page: nextPage,
        size: _pageSize,
      );
      final attemptsFuture = reset
          ? widget.api.attendanceFaceAttempts(
              userId: user.id,
              period: period,
              anchor: anchor,
              page: 0,
              size: 100,
            )
          : null;
      final value = await detailFuture;
      final attemptsPage = attemptsFuture == null ? null : await attemptsFuture;
      if (!mounted || selectedUser?.id != user.id) return;
      setState(() {
        detail = value;
        if (reset) {
          events.clear();
          faceAttempts
            ..clear()
            ..addAll(attemptsPage?.content ?? const []);
        }
        events.addAll(value.events.content);
        eventsPage = value.events.page;
        eventsLastPage = value.events.last;
        reportLoading = false;
        eventsLoadingMore = false;
      });
    } on EastAppApiException catch (exception) {
      if (!mounted || selectedUser?.id != user.id) return;
      setState(() {
        reportError = exception.message;
        reportLoading = false;
        eventsLoadingMore = false;
      });
    }
  }

  void _clearReport() {
    detail = null;
    events.clear();
    faceAttempts.clear();
    reportError = null;
    eventsPage = 0;
    eventsLastPage = true;
  }

  Future<void> changePeriod(AttendanceAuditPeriod value) async {
    if (value == period || reportLoading) return;
    AppFeedback.select();
    setState(() {
      period = value;
      anchor = DateTime.now();
      _clearReport();
    });
    await loadReport(reset: true);
  }

  Future<void> movePeriod(int direction) async {
    if (reportLoading) return;
    AppFeedback.select();
    setState(() {
      anchor = switch (period) {
        AttendanceAuditPeriod.day => anchor.add(Duration(days: direction)),
        AttendanceAuditPeriod.week => anchor.add(Duration(days: 7 * direction)),
        AttendanceAuditPeriod.month =>
          DateTime(anchor.year, anchor.month + direction, 1),
        AttendanceAuditPeriod.year =>
          DateTime(anchor.year + direction, 1, 1),
      };
      _clearReport();
    });
    await loadReport(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        _pageHeader(),
        const SizedBox(height: 14),
        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => loadUsers(reset: true),
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: AppInputStyle.decoration('Search employee').copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<bool?>(
          initialValue: activeFilter,
          decoration: AppInputStyle.decoration('Employee Status'),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('All')),
            DropdownMenuItem<bool?>(value: true, child: Text('Active')),
            DropdownMenuItem<bool?>(value: false, child: Text('Inactive')),
          ],
          onChanged: changeActiveFilter,
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          text: usersLoading ? 'Searching...' : 'Search Employees',
          icon: usersLoading ? null : Icons.search_rounded,
          onPressed: usersLoading ? null : () => loadUsers(reset: true),
        ),
        const SizedBox(height: 14),
        _employeeResults(),
        if (selectedUser != null) ...[
          const SizedBox(height: 16),
          _periodControls(),
          const SizedBox(height: 14),
          _reportContent(),
        ],
      ],
    );
  }

  Widget _pageHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 2),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'People Audit',
                style: TextStyle(
                  fontSize: AppTextSize.s24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Search an employee to view attendance history',
                style: TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _employeeResults() {
    if (!hasSearchedUsers) {
      return const Text(
        'Enter a name or employee ID, then tap Search Employees.',
        style: TextStyle(
          fontSize: AppTextSize.s15,
          color: AppColours.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (usersLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (usersError != null) {
      return _AuditError(
        message: usersError!,
        onRetry: () => loadUsers(reset: true),
      );
    }
    if (users.isEmpty) {
      return const Text(
        'No employees found.',
        style: TextStyle(
          color: AppColours.textMuted,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Employees',
                style: TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$totalUsers found',
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              final selected = selectedUser?.id == user.id;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                leading: CircleAvatar(
                  child: Text(
                    user.fullName.trim().isEmpty
                        ? '?'
                        : user.fullName.trim()[0].toUpperCase(),
                  ),
                ),
                title: Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${user.employeeId} · ${user.role.name}'),
                trailing: selected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColours.green,
                      )
                    : Icon(
                        user.active
                            ? Icons.chevron_right_rounded
                            : Icons.block_rounded,
                        color: user.active
                            ? AppColours.textMuted
                            : AppColours.red,
                      ),
                onTap: reportLoading && !selected
                    ? null
                    : () => selectUser(user),
              );
            },
          ),
        ),
        if (!usersLastPage) ...[
          const SizedBox(height: 8),
          PrimaryButton(
            text: usersLoadingMore ? 'Loading...' : 'Load More Employees',
            icon: usersLoadingMore ? null : Icons.expand_more_rounded,
            onPressed:
                usersLoadingMore ? null : () => loadUsers(reset: false),
          ),
        ],
      ],
    );
  }

  Widget _periodControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Period',
          style: TextStyle(
            fontSize: AppTextSize.s18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AttendanceAuditPeriod.values.map((item) {
              final selected = item == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(item.label),
                  onSelected: reportLoading
                      ? null
                      : (_) => changePeriod(item),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColours.textMain,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: AppColours.blue,
                  backgroundColor: AppColours.mutedBox,
                  side: BorderSide.none,
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton(
              onPressed: reportLoading ? null : () => movePeriod(-1),
              child: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColours.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  detail?.label ?? _fallbackLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTextSize.s15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: reportLoading ? null : () => movePeriod(1),
              child: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reportContent() {
    if (reportLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 38),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (reportError != null) {
      return _AuditError(
        message: reportError!,
        onRetry: () => loadReport(reset: true),
      );
    }
    if (detail == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryGrid(detail!.summary),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Failed Face Attempts',
                style: TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${faceAttempts.length}',
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (faceAttempts.isEmpty)
          const Text(
            'No failed face attempts in this period.',
            style: TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          ...faceAttempts.map(
            (attempt) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _FaceAttemptCard(api: widget.api, attempt: attempt),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Attendance Events',
                style: TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${events.length}',
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text(
            'No attendance events in this period.',
            style: TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _AttendanceEventCard(event: event),
            ),
          ),
        if (!eventsLastPage) ...[
          const SizedBox(height: 4),
          PrimaryButton(
            text: eventsLoadingMore ? 'Loading...' : 'Load More Events',
            icon: eventsLoadingMore ? null : Icons.expand_more_rounded,
            onPressed:
                eventsLoadingMore ? null : () => loadReport(reset: false),
          ),
        ],
      ],
    );
  }

  Widget _summaryGrid(EastAppAttendanceUserAudit summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AuditMetric(
                label: 'Present days',
                value: '${summary.presentDays}',
                icon: Icons.event_available_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AuditMetric(
                label: 'Completed',
                value: '${summary.completedDays}',
                icon: Icons.task_alt_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AuditMetric(
                label: 'Missing out',
                value: '${summary.missingCheckOutDays}',
                icon: Icons.logout_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AuditMetric(
                label: 'Completion',
                value: '${summary.completionPercent.toStringAsFixed(0)}%',
                icon: Icons.percent_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fallbackLabel() {
    final day = anchor.day.toString().padLeft(2, '0');
    final month = anchor.month.toString().padLeft(2, '0');
    return '$day/$month/${anchor.year}';
  }
}

class _AuditMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AuditMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColours.blueSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColours.blue, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: AppTextSize.s18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceAttemptCard extends StatefulWidget {
  final EastAppApi api;
  final EastAppAttendanceFaceAttempt attempt;

  const _FaceAttemptCard({required this.api, required this.attempt});

  @override
  State<_FaceAttemptCard> createState() => _FaceAttemptCardState();
}

class _FaceAttemptCardState extends State<_FaceAttemptCard> {
  Future<Uint8List>? photoFuture;

  @override
  void initState() {
    super.initState();
    if (widget.attempt.photoStored) {
      photoFuture = widget.api.attendanceFaceAttemptPhotoBytes(widget.attempt.id);
    }
  }

  Future<void> openPhoto(Uint8List bytes) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Failed Face Attempt'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    final attemptedAt = attempt.deviceAttemptedAt.toLocal();
    final distanceKilometres = attempt.distanceMeters / 1000;
    return WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoFuture != null)
            FutureBuilder<Uint8List>(
              future: photoFuture,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                return InkWell(
                  onTap: bytes == null || bytes.isEmpty ? null : () => openPhoto(bytes),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 86,
                    decoration: BoxDecoration(
                      color: AppColours.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColours.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: snapshot.hasError
                        ? const Icon(Icons.broken_image_outlined, color: AppColours.red)
                        : bytes == null || bytes.isEmpty
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : Image.memory(bytes, fit: BoxFit.cover),
                  ),
                );
              },
            )
          else
            Container(
              width: 72,
              height: 86,
              decoration: BoxDecoration(
                color: AppColours.redSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.no_photography_outlined, color: AppColours.red),
            ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Attempt ${attempt.faceAttemptNumber} · ${attempt.intendedEventType == 'CLOCK_OUT' ? 'Clock Out' : 'Clock In'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _AttendanceEventCard._formatDateTime(attemptedAt),
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  attempt.failureReason,
                  style: const TextStyle(color: AppColours.red, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${distanceKilometres.toStringAsFixed(2)} km from ${attempt.workLocationName}',
                  style: const TextStyle(color: AppColours.blue, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  attempt.capturedAddress,
                  style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${attempt.latitude.toStringAsFixed(6)}, ${attempt.longitude.toStringAsFixed(6)} · GPS ±${attempt.accuracyMeters.round()} m · Faces ${attempt.faceCount}',
                  style: const TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceEventCard extends StatelessWidget {
  final EastAppAttendanceEvent event;

  const _AttendanceEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final occurredAt = event.occurredAt.toLocal();
    final type = event.eventType == 'CLOCK_IN' ? 'Clock In' : 'Clock Out';
    final facePassed = event.faceValid && !event.faceVerificationBypassed;
    final attendanceAccepted = event.cameraCaptureValid &&
        event.qrCheckpointValid &&
        (facePassed || event.faceVerificationBypassed);
    final distanceKilometres = event.distanceMeters / 1000;
    return WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: facePassed ? AppColours.greenSoft : AppColours.orangeSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              event.eventType == 'CLOCK_IN'
                  ? Icons.login_rounded
                  : Icons.logout_rounded,
              color: facePassed ? AppColours.green : AppColours.orange,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _formatDateTime(occurredAt),
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  'How far from office',
                  style: TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${distanceKilometres.toStringAsFixed(2)} km away',
                  style: const TextStyle(
                    fontSize: AppTextSize.s18,
                    color: AppColours.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  event.capturedAddress,
                  style: const TextStyle(
                    color: AppColours.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Office: ${event.workLocationName} · GPS ±${event.accuracyMeters.round()} m',
                  style: const TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.faceVerificationBypassed
                      ? 'Face verification: failed after ${event.faceAttemptCount} attempts · attendance continued'
                      : 'Face verification: passed on attempt ${event.faceAttemptCount}',
                  style: TextStyle(
                    fontSize: AppTextSize.s12,
                    color: facePassed ? AppColours.green : AppColours.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!attendanceAccepted)
                  const Text(
                    'Attendance proof incomplete',
                    style: TextStyle(
                      fontSize: AppTextSize.s12,
                      color: AppColours.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}

class _AuditError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AuditError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColours.red),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColours.red,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
