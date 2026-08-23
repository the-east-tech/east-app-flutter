import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
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
  bool reportLoading = false;
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
    await loadReport();
  }

  Future<void> loadReport() async {
    final user = selectedUser;
    if (user == null || reportLoading) return;
    setState(() {
      reportLoading = true;
      reportError = null;
      detail = null;
    });

    try {
      final value = await widget.api.attendanceUserAudit(
        userId: user.id,
        period: period,
        anchor: anchor,
        page: 0,
        size: 100,
      );
      if (!mounted || selectedUser?.id != user.id) return;
      setState(() {
        detail = value;
        reportLoading = false;
      });
    } on EastAppApiException catch (exception) {
      if (!mounted || selectedUser?.id != user.id) return;
      setState(() {
        reportError = exception.message;
        reportLoading = false;
      });
    }
  }

  void _clearReport() {
    detail = null;
    reportError = null;
  }

  Future<void> changePeriod(AttendanceAuditPeriod value) async {
    if (value == period || reportLoading) return;
    AppFeedback.select();
    setState(() {
      period = value;
      anchor = DateTime.now();
      _clearReport();
    });
    await loadReport();
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
    await loadReport();
  }

  Future<void> openMonth(EastAppAttendanceMonthSummary month) async {
    if (reportLoading) return;
    AppFeedback.select();
    setState(() {
      period = AttendanceAuditPeriod.month;
      anchor = DateTime(anchor.year, month.month, 1);
      _clearReport();
    });
    await loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
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
          decoration: AppInputStyle.decoration(text.t('Search employee')).copyWith(
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
          decoration: AppInputStyle.decoration(text.t('Employee Status')),
          items: [
            DropdownMenuItem<bool?>(value: null, child: Text(text.t('All'))),
            DropdownMenuItem<bool?>(value: true, child: Text(text.t('Active'))),
            DropdownMenuItem<bool?>(value: false, child: Text(text.t('Inactive'))),
          ],
          onChanged: changeActiveFilter,
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          text: text.t(usersLoading ? 'Searching...' : 'Search Employees'),
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
    final text = AppTextScope.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.t('People Audit'),
                style: const TextStyle(
                  fontSize: AppTextSize.s24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                text.t('Search an employee to view attendance history'),
                style: const TextStyle(
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
    final text = AppTextScope.of(context);
    if (!hasSearchedUsers) {
      return Text(
        text.t('Enter a name or employee ID, then tap Search Employees.'),
        style: const TextStyle(
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
      return Text(
        text.t('No employees found.'),
        style: const TextStyle(
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
            Expanded(
              child: Text(
                text.t('Employees'),
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              text.t('$totalUsers found'),
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
                subtitle: Text(
                  '${user.employeeId} · ${text.t(user.role.name)}',
                ),
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
            text: text.t(
              usersLoadingMore ? 'Loading...' : 'Load More Employees',
            ),
            icon: usersLoadingMore ? null : Icons.expand_more_rounded,
            onPressed:
                usersLoadingMore ? null : () => loadUsers(reset: false),
          ),
        ],
      ],
    );
  }

  Widget _periodControls() {
    final text = AppTextScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.t('Attendance Period'),
          style: const TextStyle(
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
                  label: Text(text.t(item.label)),
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
        onRetry: loadReport,
      );
    }
    final value = detail;
    if (value == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryGrid(value.summary),
        const SizedBox(height: 16),
        if (period == AttendanceAuditPeriod.year)
          _yearlyContent(value)
        else
          _payrollContent(value),
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AuditMetric(
                label: 'Total working',
                value: _formatMinutes(summary.totalWorkingMinutes),
                icon: Icons.schedule_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AuditMetric(
                label: 'Average / day',
                value: _formatMinutes(summary.averageWorkingMinutes),
                icon: Icons.timelapse_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _payrollContent(EastAppAttendanceUserDetail value) {
    final text = AppTextScope.of(context);
    final days = value.days;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.t('Attendance Table'),
          style: const TextStyle(
            fontSize: AppTextSize.s18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text.t(
            'Confirmed working time includes completed Check In + Check Out records only.',
          ),
          style: const TextStyle(
            fontSize: AppTextSize.s12,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (days.isEmpty)
          Text(
            text.t('No attendance records in this period.'),
            style: const TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          _attendanceTable(days),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                text.t('Attendance Events'),
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              text.t('${days.length} days'),
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (days.isEmpty)
          Text(
            text.t('No attendance events in this period.'),
            style: const TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          ...days.reversed.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _AttendanceDayCard(day: day),
            ),
          ),
      ],
    );
  }

  Widget _attendanceTable(List<EastAppAttendanceDay> days) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          columnSpacing: 22,
          columns: [
            DataColumn(label: Text(text.t('Date'))),
            DataColumn(label: Text(text.t('Check In'))),
            DataColumn(label: Text(text.t('Check Out'))),
            DataColumn(label: Text(text.t('Working Time'))),
            DataColumn(label: Text(text.t('Status'))),
          ],
          rows: days
              .map(
                (day) => DataRow(
                  cells: [
                    DataCell(Text(_formatDate(day.date))),
                    DataCell(Text(_formatTime(day.checkInAt))),
                    DataCell(Text(_formatTime(day.checkOutAt))),
                    DataCell(Text(
                      day.completed ? _formatMinutes(day.workingMinutes) : '—',
                    )),
                    DataCell(_StatusLabel(completed: day.completed)),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _yearlyContent(EastAppAttendanceUserDetail value) {
    final text = AppTextScope.of(context);
    final summary = value.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.t('Annual Attendance Performance'),
          style: const TextStyle(
            fontSize: AppTextSize.s18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        WhiteCard(
          child: Column(
            children: [
              _AnnualLine(
                label: 'Attendance reliability',
                value: '${summary.completionPercent.toStringAsFixed(0)}%',
              ),
              const Divider(height: 18),
              _AnnualLine(
                label: 'Missing Check Outs',
                value: '${summary.missingCheckOutDays}',
              ),
              const Divider(height: 18),
              _AnnualLine(
                label: 'Average working / completed day',
                value: _formatMinutes(summary.averageWorkingMinutes),
              ),
              const Divider(height: 18),
              _AnnualLine(
                label: 'Average Clock In',
                value: summary.averageClockInTime ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          text.t('Monthly Breakdown'),
          style: const TextStyle(
            fontSize: AppTextSize.s18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text.t(
            'Tap a month to open its detailed payroll attendance view.',
          ),
          style: const TextStyle(
            fontSize: AppTextSize.s12,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _monthlyTable(value.months),
      ],
    );
  }

  Widget _monthlyTable(List<EastAppAttendanceMonthSummary> months) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 42,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          columnSpacing: 22,
          columns: [
            DataColumn(label: Text(text.t('Month'))),
            DataColumn(label: Text(text.t('Present'))),
            DataColumn(label: Text(text.t('Completed'))),
            DataColumn(label: Text(text.t('Missing Out'))),
            DataColumn(label: Text(text.t('Hours'))),
            DataColumn(label: Text(text.t('Completion'))),
          ],
          rows: months
              .map(
                (month) => DataRow(
                  onSelectChanged: reportLoading
                      ? null
                      : (_) => unawaited(openMonth(month)),
                  cells: [
                    DataCell(Text(month.label)),
                    DataCell(Text('${month.presentDays}')),
                    DataCell(Text('${month.completedDays}')),
                    DataCell(Text('${month.missingCheckOutDays}')),
                    DataCell(Text(_formatMinutes(month.totalWorkingMinutes))),
                    DataCell(Text(
                      '${month.completionPercent.toStringAsFixed(0)}%',
                    )),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
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
    final text = AppTextScope.of(context);
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
                  text.t(value),
                  style: const TextStyle(
                    fontSize: AppTextSize.s18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  text.t(label),
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

class _AttendanceDayCard extends StatelessWidget {
  final EastAppAttendanceDay day;

  const _AttendanceDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final completed = day.completed;
    final statusColour = completed ? AppColours.green : AppColours.red;
    final statusBackground =
        completed ? AppColours.greenSoft : AppColours.redSoft;

    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: statusColour,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t(_formatLongDate(day.date)),
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      text.t(
                        completed ? 'Complete' : 'Incomplete attendance',
                      ),
                      style: TextStyle(
                        fontSize: AppTextSize.s12,
                        color: statusColour,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AttendanceTimeLine(
            label: 'Check In',
            value: _formatTime(day.checkInAt),
          ),
          const SizedBox(height: 6),
          _AttendanceTimeLine(
            label: 'Check Out',
            value: _formatTime(day.checkOutAt),
            valueColour: day.checkOutAt == null ? AppColours.red : null,
          ),
          const SizedBox(height: 6),
          _AttendanceTimeLine(
            label: 'Working Time',
            value: completed ? _formatMinutes(day.workingMinutes) : '—',
          ),
          if (day.events.isNotEmpty) ...[
            const Divider(height: 24),
            ...day.events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AttendanceEventDetail(event: event),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceEventDetail extends StatelessWidget {
  final EastAppAttendanceEvent event;

  const _AttendanceEventDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final type = text.t(
      event.eventType == 'CLOCK_IN' ? 'Check In' : 'Check Out',
    );
    final distanceKilometres = event.distanceMeters / 1000;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          event.eventType == 'CLOCK_IN'
              ? Icons.login_rounded
              : Icons.logout_rounded,
          color: AppColours.textMuted,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    _formatTime(event.occurredAt.toLocal()),
                    style: const TextStyle(
                      fontSize: AppTextSize.s12,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                text.t(
                  '${distanceKilometres.toStringAsFixed(2)} km from office',
                ),
                style: const TextStyle(
                  color: AppColours.blue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                event.capturedAddress,
                style: const TextStyle(
                  color: AppColours.textMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text.t(
                  'Office: ${event.workLocationName} · GPS ±${event.accuracyMeters.round()} m',
                ),
                style: const TextStyle(
                  fontSize: AppTextSize.s12,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text.t(
                  'Validated by ${event.validationMethod} · QR + GPS',
                ),
                style: const TextStyle(
                  fontSize: AppTextSize.s12,
                  color: AppColours.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceTimeLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColour;

  const _AttendanceTimeLine({
    required this.label,
    required this.value,
    this.valueColour,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            text.t(label),
            style: const TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text.t(value),
            style: TextStyle(
              color: valueColour ?? AppColours.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnualLine extends StatelessWidget {
  final String label;
  final String value;

  const _AnnualLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            text.t(label),
            style: const TextStyle(
              color: AppColours.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text.t(value),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final bool completed;

  const _StatusLabel({required this.completed});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final colour = completed ? AppColours.green : AppColours.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          completed ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 16,
          color: colour,
        ),
        const SizedBox(width: 5),
        Text(
          text.t(completed ? 'Complete' : 'Missing Out'),
          style: TextStyle(
            color: colour,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
    final text = AppTextScope.of(context);
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
            child: Text(text.t('Retry')),
          ),
        ],
      ),
    );
  }
}

String _formatMinutes(int? minutes) {
  if (minutes == null) return '—';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder.toString().padLeft(2, '0')}m';
}

String _formatTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatLongDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
