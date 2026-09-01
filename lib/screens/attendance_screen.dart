import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/attendance_models.dart';
import '../models/auth_models.dart';
import '../models/people_models.dart';
import '../models/points_models.dart';
import '../models/organisation_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';
import '../widgets/device_contact_picker.dart';
import '../widgets/phone_number_field.dart';
import 'people_audit_screen.dart';
import 'points_screen.dart';
import 'tenant_setup_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final UserRole role;
  final EastAppApi api;
  final EastAppUser currentUser;
  final EastAppTenant currentTenant;
  final EastAppLeaderboard? pointsLeaderboard;
  final ValueChanged<EastAppLeaderboard> onPointsChanged;
  final VoidCallback onReportDataInvalidated;
  final ValueChanged<EastAppUser> onCurrentUserChanged;
  final Future<void> Function(EastAppSession context) onBusinessContextSelected;
  final Future<void> Function(EastAppTenant tenant) onBusinessCreated;
  final WorkLocation workLocation;
  final List<AttendanceRecord> attendanceRecords;
  final void Function(AttendanceRecord record) onClockIn;
  final void Function(AttendanceRecord record) onClockOut;

  const AttendanceScreen({
    super.key,
    required this.role,
    required this.api,
    required this.currentUser,
    required this.currentTenant,
    required this.pointsLeaderboard,
    required this.onPointsChanged,
    required this.onReportDataInvalidated,
    required this.onCurrentUserChanged,
    required this.onBusinessContextSelected,
    required this.onBusinessCreated,
    required this.workLocation,
    required this.attendanceRecords,
    required this.onClockIn,
    required this.onClockOut,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

enum _PeoplePage {
  home,
  users,
  roles,
  points,
  tenants,
  audit,
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const int _usersPageSize = 20;

  List<_PeopleUser> users = [];
  List<_PeopleRole> roles = [];
  int usersPage = 0;
  int usersTotal = 0;
  bool usersLastPage = true;
  bool usersLoading = false;
  bool usersLoadingMore = false;
  bool usersLoaded = false;
  String? usersError;
  String usersSearch = '';
  bool? usersActiveFilter;
  String? usersRoleFilter;
  DateTime? usersUpdatedAt;

  bool rolesLoaded = false;
  DateTime? rolesUpdatedAt;
  bool rolesLoading = false;
  String? rolesError;

  EastAppAttendanceToday? todayAttendance;
  bool attendanceLoading = false;
  String? attendanceError;
  _PeoplePage page = _PeoplePage.home;
  double peopleSwipeStartX = 0;
  double peopleSwipeDeltaX = 0;

  bool get isOwner => widget.currentUser.role.isOwner;
  bool get isHead => widget.role == UserRole.head;
  bool get isManager => widget.role == UserRole.manager;
  bool get canManageUsers => isHead || isManager;
  bool get canCreateUsers => canManageUsers;
  bool get canManageTenants => isOwner;
  bool get canManagePoints => isOwner || isHead;

  String get currentSelfUserId => widget.currentUser.employeeId;

  String get currentSelfUserName => widget.currentUser.fullName;

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged = oldWidget.currentUser.id != widget.currentUser.id;
    final tenantChanged = oldWidget.currentTenant.id != widget.currentTenant.id;
    final roleChanged = oldWidget.currentUser.role.systemKey !=
        widget.currentUser.role.systemKey;

    if (identityChanged || tenantChanged) {
      todayAttendance = null;
      attendanceLoading = false;
      attendanceError = null;
    }

    if (identityChanged || tenantChanged || roleChanged) {
      // Never keep a privileged user/role list after a context or role change.
      users = [];
      roles = [];
      usersPage = 0;
      usersTotal = 0;
      usersLastPage = true;
      usersLoading = false;
      usersLoadingMore = false;
      usersLoaded = false;
      usersError = null;
      usersSearch = '';
      usersActiveFilter = null;
      usersRoleFilter = null;
      rolesLoaded = false;
      rolesLoading = false;
      rolesError = null;
      page = _PeoplePage.home;
    }
  }


  Future<void> loadUsers({
    bool reset = true,
    bool forceRefresh = false,
  }) async {
    if (!canManageUsers || usersLoading || usersLoadingMore) return;
    final nextPage = reset || forceRefresh ? 0 : usersPage + 1;
    setState(() {
      if (nextPage == 0) {
        usersLoading = true;
        usersError = null;
      } else {
        usersLoadingMore = true;
      }
    });

    final query = Uri(queryParameters: {
      'search': usersSearch.trim(),
      if (usersActiveFilter != null) 'active': usersActiveFilter.toString(),
      if (usersRoleFilter != null) 'role': usersRoleFilter!,
      'page': '$nextPage',
      'size': '$_usersPageSize',
    }).query;
    final viewerRole = widget.currentUser.role.systemKey;
    final cacheKey =
        '${EastAppApi.usersCachePrefix(widget.currentTenant.id)}$viewerRole:$query';
    try {
      final result = await widget.api.listUsers(
        search: usersSearch,
        active: usersActiveFilter,
        role: usersRoleFilter,
        viewerRole: viewerRole,
        page: nextPage,
        size: _usersPageSize,
        tenantId: widget.currentTenant.id,
        forceRefresh: forceRefresh,
      );
      if (!mounted || !canManageUsers) return;
      setState(() {
        if (nextPage == 0) users.clear();
        users.addAll(result.content.map(_PeopleUser.fromApi));
        usersPage = result.page;
        usersTotal = result.totalElements;
        usersLastPage = result.last;
        usersLoading = false;
        usersLoadingMore = false;
        usersLoaded = true;
        usersUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
      });
    } on EastAppApiException catch (error) {
      if (!mounted || !canManageUsers) return;
      setState(() {
        usersError = error.message;
        usersLoading = false;
        usersLoadingMore = false;
        usersLoaded = true;
      });
    }
  }

  Future<void> loadRoles({bool force = false}) async {
    if (!canManageUsers || rolesLoading || rolesLoaded && !force) return;
    setState(() {
      rolesLoading = true;
      rolesError = null;
    });
    final viewerRole = widget.currentUser.role.systemKey;
    final cacheKey =
        '${EastAppApi.rolesCachePrefix(widget.currentTenant.id)}visible:$viewerRole';
    try {
      final result = await widget.api.listRoles(
        tenantId: widget.currentTenant.id,
        viewerRole: viewerRole,
        forceRefresh: force,
      );
      if (!mounted || !canManageUsers) return;
      setState(() {
        roles = result.map(_PeopleRole.fromApi).toList();
        rolesLoaded = true;
        rolesLoading = false;
        rolesUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
      });
    } on EastAppApiException catch (error) {
      if (!mounted || !canManageUsers) return;
      setState(() {
        rolesError = error.message;
        rolesLoading = false;
      });
    }
  }

  Future<bool> ensureRolesLoaded() async {
    if (rolesLoaded) return true;
    await loadRoles();
    if (!mounted) return false;
    if (!rolesLoaded && rolesError != null) {
      showErrorSnackBar(context, rolesError!);
    }
    return rolesLoaded;
  }

  void updateUsersSearch(String value) {
    setState(() {
      usersSearch = value.trim();
      _clearLoadedUserQuery();
    });
  }

  void updateUsersActiveFilter(bool? value) {
    setState(() {
      usersActiveFilter = value;
      _clearLoadedUserQuery();
    });
  }

  void updateUsersRoleFilter(String? value) {
    setState(() {
      usersRoleFilter = value;
      _clearLoadedUserQuery();
    });
  }

  void _clearLoadedUserQuery() {
    users = [];
    usersPage = 0;
    usersTotal = 0;
    usersLastPage = true;
    usersLoaded = false;
    usersError = null;
    usersUpdatedAt = null;
  }

  void openPage(_PeoplePage nextPage) {
    if (page == nextPage) return;
    if ((nextPage == _PeoplePage.users || nextPage == _PeoplePage.roles) &&
        !canManageUsers) {
      showWarningSnackBar(context, 'Only Owner, Head and Manager can access User and Role.');
      return;
    }
    if (nextPage == _PeoplePage.points && !canManagePoints) {
      showWarningSnackBar(context, 'Only Owner and Head can adjust points.');
      return;
    }
    if (nextPage == _PeoplePage.tenants && !canManageTenants) {
      showWarningSnackBar(context, 'Only Owner can manage businesses.');
      return;
    }
    if (nextPage == _PeoplePage.audit && !isHead) {
      showWarningSnackBar(context, 'Only Owner and Head can view People Audit.');
      return;
    }
    AppFeedback.select();
    setState(() => page = nextPage);
    if (nextPage == _PeoplePage.users) {
      unawaited(loadRoles());
    } else if (nextPage == _PeoplePage.roles) {
      unawaited(loadRoles());
    }
  }

  void goPeopleHome({bool fromSwipe = false}) {
    if (page == _PeoplePage.home) return;
    if (fromSwipe) {
      AppFeedback.swipeBack();
    } else {
      AppFeedback.select();
    }
    setState(() => page = _PeoplePage.home);
  }

  Future<bool> handleBackNavigation() async {
    if (page != _PeoplePage.home) {
      goPeopleHome();
    }
    return false;
  }

  void handlePeopleSwipeStart(DragStartDetails details) {
    peopleSwipeStartX = details.globalPosition.dx;
    peopleSwipeDeltaX = 0;
  }

  void handlePeopleSwipeUpdate(DragUpdateDetails details) {
    peopleSwipeDeltaX += details.delta.dx;
  }

  void handlePeopleSwipeEnd(DragEndDetails details) {
    if (page == _PeoplePage.home) return;
    final isRightSwipe = peopleSwipeDeltaX > 72 ||
        details.primaryVelocity != null && details.primaryVelocity! > 380;
    final isLeftEdgeSwipe = peopleSwipeStartX <= 48 &&
        (peopleSwipeDeltaX > 32 ||
            details.primaryVelocity != null && details.primaryVelocity! > 180);
    if (isRightSwipe || isLeftEdgeSwipe) {
      goPeopleHome(fromSwipe: true);
    }
  }

  int assignedUserCount(String roleName) {
    return users.where((user) => user.role == roleName).length;
  }

  bool canEditUser(_PeopleUser user) {
    if (isOwner) return true;
    if (isHead) return user.roleSystemKey != 'OWNER';
    if (!isManager) return false;
    return user.roleSystemKey != 'OWNER' &&
        user.roleSystemKey != 'HEAD' &&
        user.roleSystemKey != 'MANAGER';
  }

  void showComingSoon(String title) {
    final text = AppTextScope.of(context);
    AppFeedback.warning();
    _showPeopleBottomSheet(
      context,
      heightFactor: 0.42,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PeopleSheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColours.blueSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_outlined, color: AppColours.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text.t(title),
                    style: const TextStyle(
                      fontSize: AppTextSize.s24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text.t('Coming soon. User setup is enabled first.'),
              style: const TextStyle(
                fontSize: AppTextSize.s16,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }


  bool get canGenerateAttendanceQr => isOwner || isHead || isManager;

  void openAttendanceOptions() {
    AppFeedback.tap();
    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.58,
      child: _AttendanceMenuSheet(
        canGenerateQr: canGenerateAttendanceQr,
        onCheckInOut: () {
          Navigator.of(context).pop();
          Future.microtask(_openAttendanceCheckInOut);
        },
        onQrCode: () {
          if (!canGenerateAttendanceQr) {
            showWarningSnackBar(
              context,
              AppTextScope.of(context).t(
                'Only Owner, Head and Manager can generate attendance QR codes.',
              ),
            );
            return;
          }
          Navigator.of(context).pop();
          Future.microtask(_openAttendanceQrGenerator);
        },
      ),
    );
  }

  Future<void> _openAttendanceCheckInOut() async {
    AppFeedback.select();
    setState(() {
      attendanceLoading = true;
      attendanceError = null;
    });
    try {
      final value = await widget.api.attendanceToday();
      if (!mounted) return;
      setState(() {
        todayAttendance = value;
        attendanceLoading = false;
      });
      await _showPeopleBottomSheet<void>(
        context,
        heightFactor: 0.70,
        child: _AttendanceCheckInOutSheet(
          attendance: value,
          onClockIn: value.hasClockedIn
              ? null
              : () => _scanAndSubmitAttendance('Clock In'),
          onClockOut: value.hasClockedIn && !value.hasClockedOut
              ? () => _scanAndSubmitAttendance('Clock Out')
              : null,
        ),
      );
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        attendanceError = error.message;
        attendanceLoading = false;
      });
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _openAttendanceQrGenerator() async {
    if (!canGenerateAttendanceQr) {
      showWarningSnackBar(
        context,
        AppTextScope.of(context).t(
          'Only Owner, Head and Manager can generate attendance QR codes.',
        ),
      );
      return;
    }
    await _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.94,
      child: _AttendanceQrGeneratorSheet(api: widget.api),
    );
  }

  Future<void> _scanAndSubmitAttendance(String actionLabel) async {
    final qrPayload = await _showPeopleBottomSheet<String>(
      context,
      heightFactor: 0.86,
      child: _AttendanceQrScannerSheet(actionLabel: actionLabel),
    );
    if (qrPayload == null || qrPayload.trim().isEmpty || !mounted) return;

    final locationIssue = await _checkLocationAccessForAttendance();
    if (!mounted) return;
    if (locationIssue != null) {
      _showAttendanceAccessRequired([locationIssue]);
      return;
    }

    try {
      final capturedLocation = await _captureAttendanceLocation();
      if (!mounted) return;
      final event = await widget.api.createAttendanceEvent(
        clientEventId: _newAttendanceClientEventId(),
        deviceCapturedAt: DateTime.now(),
        latitude: capturedLocation.latitude,
        longitude: capturedLocation.longitude,
        accuracyMeters: capturedLocation.accuracyMeters.toDouble(),
        qrPayload: qrPayload.trim(),
        devicePlatform: Platform.isIOS
            ? 'IOS'
            : Platform.isAndroid
                ? 'ANDROID'
                : Platform.operatingSystem.toUpperCase(),
        deviceOsVersion: Platform.operatingSystemVersion.replaceAll('\n', ' '),
        appVersion: 'east_app_v305',
      );

      final refreshed = await widget.api.attendanceToday();
      await widget.api.invalidateFeatureCache(
        'tenant:${widget.currentTenant.id}:report:',
      );
      widget.onReportDataInvalidated();
      if (!mounted) return;
      setState(() => todayAttendance = refreshed);
      Navigator.of(context).pop();
      showSuccessSnackBar(
        context,
        AppTextScope.of(context).t(
          event.eventType == 'CLOCK_OUT'
              ? 'Clock out completed'
              : 'Clock in completed',
        ),
      );
    } on _LocationCaptureException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, AppTextScope.of(context).t(error.message));
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<String?> _checkLocationAccessForAttendance() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!serviceEnabled) {
      return 'Location Services is off. Turn on Location Services to use Attendance.';
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission denied. Allow location access to use Attendance.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Open app settings and allow location access.';
    }
    return null;
  }

  Future<_CapturedAttendanceLocation> _captureAttendanceLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw _LocationCaptureException(
        'Location service is off. Turn on Location Services to continue Attendance.',
      );
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      throw _LocationCaptureException(
        'Location permission is required to continue Attendance.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw _LocationCaptureException(
        'Location permission is permanently denied. Open app settings and allow location access.',
      );
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) {
        throw _LocationCaptureException(
          'Unable to capture the current GPS location. Please try again.',
        );
      }
      position = lastKnown;
    }

    return _CapturedAttendanceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy.round(),
    );
  }

  void _showAttendanceAccessRequired(List<String> issues) {
    final text = AppTextScope.of(context);
    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.48,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PeopleSheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColours.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.location_off_outlined,
                    color: AppColours.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text.t('Location access required'),
                    style: const TextStyle(
                      fontSize: AppTextSize.s22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text.t(
                'GPS location is required for attendance and is recorded with each Check In / Out.',
              ),
              style: const TextStyle(
                fontSize: AppTextSize.s14,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColours.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text.t(issue),
                        style: const TextStyle(
                          fontSize: AppTextSize.s13,
                          color: AppColours.textMain,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: text.t('Location Settings'),
                    icon: Icons.location_on_outlined,
                    onPressed: () => Geolocator.openLocationSettings(),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    text: text.t('App Settings'),
                    icon: Icons.settings_outlined,
                    onPressed: () => Geolocator.openAppSettings(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _newAttendanceClientEventId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = math.Random.secure().nextInt(0x7fffffff);
    return '${widget.currentUser.id}-$timestamp-$random';
  }

  Future<void> invalidateUserRelatedCaches() async {
    final tenantId = widget.currentTenant.id;
    await Future.wait([
      widget.api.invalidateFeatureCache(EastAppApi.usersCachePrefix(tenantId)),
      widget.api.invalidateFeatureCache(EastAppApi.rolesCachePrefix(tenantId)),
      widget.api.invalidateFeatureCache(EastAppApi.stockTagsCachePrefix(tenantId)),
      widget.api.invalidateFeatureCache('tenant:$tenantId:report:'),
    ]);
    widget.api.invalidateTaskRecords(tenantId);
    widget.api.invalidateTaskTemplates(tenantId);
    widget.onReportDataInvalidated();
  }

  Future<void> openUserForm() async {
    if (!canCreateUsers) {
      showWarningSnackBar(
        context,
        'Only Owner, Head and Manager can create users.',
      );
      return;
    }

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.94,
      child: _UserFormSheet(
        tenant: widget.currentTenant,
        loadRoles: () async {
          final tenantRoles = await widget.api.listAssignableRoles();
          return tenantRoles
              .map(_PeopleRole.fromApi)
              .toList(growable: false);
        },
        allowRoleEdit: true,
        onSaveUser: (draft) async {
          final created = await widget.api.createUser(
            password: draft.password,
            fullName: draft.fullName,
            phoneE164: draft.phoneE164,
            roleId: draft.roleId,
            birthDate: draft.birthDate,
            startDate: draft.startDate,
            endDate: draft.endDate,
          );
          await invalidateUserRelatedCaches();
          if (usersLoaded) {
            unawaited(loadUsers(reset: true, forceRefresh: true));
          }
          unawaited(loadRoles(force: true));
          return created.employeeId;
        },
      ),
    );
  }

  Future<void> openEditUserForm(_PeopleUser user) async {
    if (!canEditUser(user)) {
      showWarningSnackBar(
        context,
        isManager
            ? 'Manager cannot edit Owner, Head or Manager users.'
            : 'Head cannot edit Owner users.',
      );
      return;
    }
    if (!await ensureRolesLoaded() || !mounted) return;

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.94,
      child: _UserFormSheet(
        user: user,
        tenant: widget.currentTenant,
        initialRoles: roles,
        allowRoleEdit: true,
        allowedRoleSystemKeys: user.roleSystemKey == 'OWNER'
            ? const {'OWNER'}
            : isManager
                ? const {'SUPERVISOR', 'STAFF_1', 'STAFF_2'}
                : null,
        allowPasswordReset: user.id != widget.currentUser.id,
        allowStatusEdit:
            user.id != widget.currentUser.id && user.roleSystemKey != 'OWNER',
        onSaveUser: (draft) async {
          final updatedUser = await widget.api.updateUser(
            userId: user.id,
            fullName: draft.fullName,
            phoneE164: draft.phoneE164,
            roleId: draft.roleId,
            active: draft.active,
            profilePhotoKey: user.profilePhotoKey,
            birthDate: draft.birthDate,
            startDate: draft.startDate,
            endDate: draft.endDate,
          );
          if (user.id == widget.currentUser.id) {
            widget.onCurrentUserChanged(updatedUser);
          }
          if (draft.password != null) {
            await widget.api.resetUserPassword(
              userId: user.id,
              password: draft.password!,
            );
          }
          await invalidateUserRelatedCaches();
          await Future.wait([
            if (usersLoaded) loadUsers(reset: true, forceRefresh: true),
            loadRoles(force: true),
          ]);
          return null;
        },
        onDeleteUser: () {
          Navigator.of(context).pop();
          Future.microtask(() => openDeleteUserForm(user));
        },
      ),
    );
  }

  void openDeleteUserForm(_PeopleUser user) {
    if (!canEditUser(user)) {
      showWarningSnackBar(
        context,
        isManager
            ? 'Manager cannot deactivate Owner, Head or Manager users.'
            : 'Head cannot deactivate Owner users.',
      );
      return;
    }

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.52,
      child: _DeleteUserSheet(
        user: user,
        onDeactivateUser: (lastWorkingDate) async {
          await widget.api.updateUser(
            userId: user.id,
            fullName: user.fullName,
            phoneE164: user.phoneNumber,
            roleId: user.roleId,
            active: false,
            profilePhotoKey: user.profilePhotoKey,
            birthDate: user.bornDate,
            startDate: user.startDate,
            endDate: lastWorkingDate,
          );
          await invalidateUserRelatedCaches();
          await Future.wait([
            if (usersLoaded) loadUsers(reset: true, forceRefresh: true),
            loadRoles(force: true),
          ]);
        },
      ),
    );
  }

  Widget buildPeopleHome(BuildContext context) {
    final text = AppTextScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PageTitle(
          title: text.t('People Dashboard'),
          subtitle: canManageUsers
              ? text.t('Manage users, roles and attendance')
              : text.t('View attendance'),
        ),
        const SizedBox(height: 8),
        _PeopleSectionTitle(text.t('People')),
        _PeopleMenuGrid(
          children: [
            if (canManageUsers)
              _PeopleMenuCard(
                title: text.t('User'),
                subtitle: text.t('List users'),
                icon: Icons.people_outline_rounded,
                onTap: () => openPage(_PeoplePage.users),
              ),
            _PeopleMenuCard(
              title: text.t('Attendance'),
              subtitle: text.t('Clock in/out'),
              icon: Icons.work_history_outlined,
              onTap: openAttendanceOptions,
            ),
            _PeopleMenuCard(
              title: text.t('Schedule'),
              subtitle: text.t('Shift planning'),
              icon: Icons.calendar_month_outlined,
              onTap: () => showComingSoon(text.t('Schedule')),
            ),
            if (canManageUsers)
              _PeopleMenuCard(
                title: text.t('Role'),
                subtitle: text.t('View role hierarchy'),
                icon: Icons.admin_panel_settings_outlined,
                onTap: () => openPage(_PeoplePage.roles),
              ),
            if (canManagePoints)
              _PeopleMenuCard(
                title: text.t('Points'),
                subtitle: text.t('Add or deduct points'),
                icon: Icons.add_chart_rounded,
                onTap: () => openPage(_PeoplePage.points),
              ),
            if (canManageTenants)
              _PeopleMenuCard(
                title: text.t('Business'),
                subtitle: text.t('Manage businesses'),
                icon: Icons.business_outlined,
                onTap: () => openPage(_PeoplePage.tenants),
              ),
            if (isHead)
              _PeopleMenuCard(
                title: text.t('Audit'),
                subtitle: text.t('Attendance reports'),
                icon: Icons.analytics_outlined,
                onTap: () => openPage(_PeoplePage.audit),
              ),
          ],
        ),
      ],
    );
  }

  Widget _withPeopleSetupRefresh({
    required Widget child,
    required DateTime? updatedAt,
    required Future<void> Function() onRefresh,
  }) {
    return Column(
      children: [
        _PeopleSetupRefreshBar(updatedAt: updatedAt, onRefresh: onRefresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget buildCurrentPage() {
    switch (page) {
      case _PeoplePage.users:
        return _withPeopleSetupRefresh(
          updatedAt: usersUpdatedAt,
          onRefresh: () => loadUsers(reset: true, forceRefresh: true),
          child: _UserSetupPage(
            users: users,
            totalUsers: usersTotal,
            hasLoaded: usersLoaded,
            loading: usersLoading,
            loadingMore: usersLoadingMore,
            lastPage: usersLastPage,
            error: usersError,
            activeFilter: usersActiveFilter,
            roleFilter: usersRoleFilter,
            roles: roles,
            canManageUsers: canManageUsers,
            canCreateUsers: canCreateUsers,
            onBack: goPeopleHome,
            onCreateUser: openUserForm,
            onUserTap: canManageUsers ? openEditUserForm : null,
            onSearchChanged: updateUsersSearch,
            onSearch: () => unawaited(loadUsers(reset: true)),
            onActiveFilterChanged: updateUsersActiveFilter,
            onRoleFilterChanged: updateUsersRoleFilter,
            onLoadMore: () => loadUsers(reset: false),
            onRetry: () => loadUsers(reset: true, forceRefresh: true),
          ),
        );
      case _PeoplePage.roles:
        return _withPeopleSetupRefresh(
          updatedAt: rolesUpdatedAt,
          onRefresh: () => loadRoles(force: true),
          child: _RoleSetupPage(
            roles: roles,
            loading: rolesLoading,
            error: rolesError,
            onBack: goPeopleHome,
            onRetry: () => loadRoles(force: true),
          ),
        );
      case _PeoplePage.points:
        return PeoplePointsScreen(
          api: widget.api,
          initialLeaderboard: widget.pointsLeaderboard,
          onBack: goPeopleHome,
          onLeaderboardChanged: widget.onPointsChanged,
        );
      case _PeoplePage.tenants:
        return TenantSetupScreen(
          api: widget.api,
          isOwner: isOwner,
          currentTenant: widget.currentTenant,
          onSwitchBusiness: widget.onBusinessContextSelected,
          onBusinessCreated: widget.onBusinessCreated,
          onBack: goPeopleHome,
        );
      case _PeoplePage.audit:
        return PeopleAuditScreen(
          api: widget.api,
          onBack: goPeopleHome,
        );
      case _PeoplePage.home:
        return buildPeopleHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(handleBackNavigation());
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: handlePeopleSwipeStart,
        onHorizontalDragUpdate: handlePeopleSwipeUpdate,
        onHorizontalDragEnd: handlePeopleSwipeEnd,
        child: KeyedSubtree(
          key: ValueKey<_PeoplePage>(page),
          child: buildCurrentPage(),
        ),
      ),
    );
  }
}


class _PeoplePageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? trailing;

  const _PeoplePageScaffold({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: PageTitle(
                title: text.t(title),
                subtitle: text.t(subtitle),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: trailing!,
              ),
          ],
        ),
        ...children,
      ],
    );
  }
}

class _PeopleSetupRefreshBar extends StatefulWidget {
  final DateTime? updatedAt;
  final Future<void> Function() onRefresh;

  const _PeopleSetupRefreshBar({required this.updatedAt, required this.onRefresh});

  @override
  State<_PeopleSetupRefreshBar> createState() => _PeopleSetupRefreshBarState();
}

class _PeopleSetupRefreshBarState extends State<_PeopleSetupRefreshBar> {
  bool refreshing = false;

  Future<void> refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  String get updatedText {
    final value = widget.updatedAt;
    if (value == null) return 'Not loaded';
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Last updated ${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Material(
      color: const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(
          children: [
            const Icon(Icons.storage_rounded, size: 18, color: AppColours.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.t(updatedText),
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontSize: AppTextSize.s12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: refreshing ? null : refresh,
              icon: refreshing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              label: Text(text.t('Refresh')),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSetupPage extends StatefulWidget {
  final List<_PeopleUser> users;
  final int totalUsers;
  final bool hasLoaded;
  final bool loading;
  final bool loadingMore;
  final bool lastPage;
  final String? error;
  final bool? activeFilter;
  final String? roleFilter;
  final List<_PeopleRole> roles;
  final bool canManageUsers;
  final bool canCreateUsers;
  final VoidCallback onBack;
  final VoidCallback onCreateUser;
  final ValueChanged<_PeopleUser>? onUserTap;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearch;
  final ValueChanged<bool?> onActiveFilterChanged;
  final ValueChanged<String?> onRoleFilterChanged;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRetry;

  const _UserSetupPage({
    required this.users,
    required this.totalUsers,
    required this.hasLoaded,
    required this.loading,
    required this.loadingMore,
    required this.lastPage,
    required this.error,
    required this.activeFilter,
    required this.roleFilter,
    required this.roles,
    required this.canManageUsers,
    required this.canCreateUsers,
    required this.onBack,
    required this.onCreateUser,
    required this.onUserTap,
    required this.onSearchChanged,
    required this.onSearch,
    required this.onActiveFilterChanged,
    required this.onRoleFilterChanged,
    required this.onLoadMore,
    required this.onRetry,
  });

  @override
  State<_UserSetupPage> createState() => _UserSetupPageState();
}

class _UserSetupPageState extends State<_UserSetupPage> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void handleSearch(String value) {
    widget.onSearchChanged(value);
    setState(() {});
  }

  String get statusValue {
    if (widget.activeFilter == true) return 'Active';
    if (widget.activeFilter == false) return 'Inactive';
    return 'All';
  }

  String get roleValue {
    final filter = widget.roleFilter;
    if (filter == null) return 'All Roles';
    for (final role in widget.roles) {
      if (role.systemKey == filter) return role.name;
    }
    return 'All Roles';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return _PeoplePageScaffold(
      title: text.t('User'),
      subtitle: widget.canManageUsers
          ? text.t('Search and edit users.')
          : text.t('View users.'),
      onBack: widget.onBack,
      trailing: widget.canCreateUsers
          ? SizedBox(
              width: 150,
              child: PrimaryButton(
                text: text.t('Create User'),
                icon: Icons.add_rounded,
                onPressed: widget.onCreateUser,
              ),
            )
          : null,
      children: [
        Row(
          children: [
            Expanded(
              child: _PeopleMiniMetric(
                label: text.t('Total'),
                value: '${widget.totalUsers}',
                icon: Icons.groups_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PeopleMiniMetric(
                label: text.t('Loaded'),
                value: '${widget.users.length}',
                icon: Icons.downloading_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PeopleMiniMetric(
                label: text.t('Status'),
                value: statusValue,
                icon: Icons.filter_alt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          style: AppTextStyles.formValue,
          onChanged: handleSearch,
          onSubmitted: (value) {
            widget.onSearchChanged(value);
            widget.onSearch();
          },
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: AppInputStyle.decoration(
            text.t('Search users'),
          ).copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      AppFeedback.select();
                      searchController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {});
                      widget.onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        _PeopleFilterDropdown(
          label: text.t('Status'),
          value: statusValue,
          options: const ['All', 'Active', 'Inactive'],
          onChanged: (value) {
            widget.onActiveFilterChanged(
              value == 'Active'
                  ? true
                  : value == 'Inactive'
                      ? false
                      : null,
            );
          },
        ),
        const SizedBox(height: 10),
        _PeopleFilterDropdown(
          label: text.t('Role'),
          value: roleValue,
          options: [
            'All Roles',
            ...widget.roles.where((role) => role.active).map((role) => role.name),
          ],
          onChanged: (value) {
            if (value == 'All Roles') {
              widget.onRoleFilterChanged(null);
              return;
            }
            for (final role in widget.roles) {
              if (role.name == value) {
                widget.onRoleFilterChanged(role.systemKey);
                return;
              }
            }
          },
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          text: text.t('Search Users'),
          icon: Icons.search_rounded,
          onPressed: widget.loading ? null : widget.onSearch,
        ),
        const SizedBox(height: 14),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.error != null)
          WhiteCard(
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColours.red),
                const SizedBox(height: 8),
                Text(
                  widget.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColours.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: widget.onRetry,
                  child: Text(text.t('Retry')),
                ),
              ],
            ),
          )
        else if (!widget.hasLoaded)
          WhiteCard(
            child: Text(
              text.t('Choose any filters, then tap Search Users.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else ...[
          _PeopleUserList(
            users: widget.users,
            onUserTap: widget.onUserTap,
          ),
          if (!widget.lastPage) ...[
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: widget.loadingMore ? null : widget.onLoadMore,
                icon: widget.loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  text.t(widget.loadingMore ? 'Loading...' : 'Load more'),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RoleSetupPage extends StatelessWidget {
  final List<_PeopleRole> roles;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final Future<void> Function() onRetry;

  const _RoleSetupPage({
    required this.roles,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onRetry,
  });

  int assignedCount(String roleName) {
    return roles.firstWhere((role) => role.name == roleName).assignedUsers;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final rolesInUse = roles.where((role) => role.assignedUsers > 0).length;

    return _PeoplePageScaffold(
      title: text.t('Role'),
      subtitle: 'Fixed EastApp role hierarchy',
      onBack: onBack,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          WhiteCard(
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColours.red),
                const SizedBox(height: 8),
                Text(
                  error!,
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
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _PeopleMiniMetric(
                  label: text.t('Total'),
                  value: '${roles.length}',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PeopleMiniMetric(
                  label: text.t('In Use'),
                  value: '$rolesInUse',
                  icon: Icons.link_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WhiteCard(
            child: Text(
              text.t(
                'Owner → Head → Manager → Supervisor → Staff1 → Staff2. Roles are fixed and cannot be created, renamed or deleted.',
              ),
              style: const TextStyle(
                color: AppColours.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PeopleRoleList(
            roles: roles,
            assignedCount: assignedCount,
            onRoleTap: null,
          ),
        ],
      ],
    );
  }
}

class _PeopleFilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PeopleFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(text.t(label), style: AppTextStyles.formLabel),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(text.t(option)),
                  ))
              .toList(),
          onChanged: (nextValue) {
            if (nextValue == null) return;
            AppFeedback.select();
            onChanged(nextValue);
          },
          decoration: AppInputStyle.decoration(
            text.t(label),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: AppTextStyles.formValue,
        ),
      ],
    );
  }
}

class _PeopleRoleList extends StatelessWidget {
  final List<_PeopleRole> roles;
  final int Function(String roleName) assignedCount;
  final ValueChanged<_PeopleRole>? onRoleTap;

  const _PeopleRoleList({
    required this.roles,
    required this.assignedCount,
    required this.onRoleTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    if (roles.isEmpty) {
      return WhiteCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          text.t('No role found'),
          style: const TextStyle(
            fontSize: AppTextSize.s16,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < roles.length; i++) ...[
            _PeopleRoleRow(
              role: roles[i],
              assignedCount: assignedCount(roles[i].name),
              onTap: onRoleTap == null ? null : () => onRoleTap!(roles[i]),
            ),
            if (i != roles.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _PeopleRoleRow extends StatelessWidget {
  final _PeopleRole role;
  final int assignedCount;
  final VoidCallback? onTap;

  const _PeopleRoleRow({
    required this.role,
    required this.assignedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: role.active ? AppColours.blue : AppColours.mutedBox,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                role.isHead
                    ? Icons.security_rounded
                    : Icons.admin_panel_settings_outlined,
                color: role.active ? Colors.white : AppColours.textMuted,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t(role.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text.t(
                      '$assignedCount ${assignedCount == 1 ? 'user' : 'users'} assigned',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s12,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SmallStatusPill(
              text: text.t(role.active ? 'Active' : 'Inactive'),
              textColour: role.active ? AppColours.green : AppColours.textMuted,
              backgroundColour:
                  role.active ? AppColours.greenSoft : AppColours.mutedBox,
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColours.textMuted,
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapturedAttendanceLocation {
  final double latitude;
  final double longitude;
  final int accuracyMeters;

  const _CapturedAttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });
}

class _LocationCaptureException implements Exception {
  final String message;

  const _LocationCaptureException(this.message);
}

class _AttendanceMenuSheet extends StatelessWidget {
  final bool canGenerateQr;
  final VoidCallback onCheckInOut;
  final VoidCallback onQrCode;

  const _AttendanceMenuSheet({
    required this.canGenerateQr,
    required this.onCheckInOut,
    required this.onQrCode,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  text.t('Attendance'),
                  style: const TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
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
            text.t(
              'Select an attendance action. Data is loaded only when requested.',
            ),
            style: const TextStyle(
              fontSize: AppTextSize.s13,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          _AttendanceFeatureCard(
            icon: Icons.how_to_reg_outlined,
            title: text.t('Check In / Out'),
            subtitle: text.t(
              'Load today\'s attendance, then scan the required QR code.',
            ),
            onTap: onCheckInOut,
          ),
          const SizedBox(height: 12),
          _AttendanceFeatureCard(
            icon: Icons.qr_code_2_rounded,
            title: text.t('QR Code'),
            subtitle: canGenerateQr
                ? text.t('Generate a 30-minute Check In or Check Out QR code.')
                : text.t('Owner, Head or Manager permission is required.'),
            onTap: canGenerateQr ? onQrCode : null,
            disabled: !canGenerateQr,
          ),
        ],
      ),
    );
  }
}

class _AttendanceFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool disabled;

  const _AttendanceFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: WhiteCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: disabled ? AppColours.mutedBox : AppColours.blueSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: disabled ? AppColours.textMuted : AppColours.blue,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t(title),
                    style: TextStyle(
                      fontSize: AppTextSize.s17,
                      fontWeight: FontWeight.w700,
                      color: disabled ? AppColours.textMuted : AppColours.textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text.t(subtitle),
                    style: const TextStyle(
                      fontSize: AppTextSize.s12,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              disabled ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
              color: AppColours.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCheckInOutSheet extends StatelessWidget {
  final EastAppAttendanceToday attendance;
  final VoidCallback? onClockIn;
  final VoidCallback? onClockOut;

  const _AttendanceCheckInOutSheet({
    required this.attendance,
    required this.onClockIn,
    required this.onClockOut,
  });

  String get statusLabel {
    if (attendance.hasClockedOut) return 'Completed for today';
    if (attendance.hasClockedIn) return 'Checked in · ready to check out';
    return 'Not checked in';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  text.t('Check In / Out'),
                  style: const TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    attendance.hasClockedOut
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 21,
                    color: attendance.hasClockedOut
                        ? AppColours.green
                        : AppColours.blue,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.t(statusLabel),
                        style: const TextStyle(
                          fontSize: AppTextSize.s15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text.t(
                          'GPS location and a valid attendance QR are required.',
                        ),
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
          ),
          const SizedBox(height: 16),
          _AttendanceActionCard(
            title: 'Check In',
            subtitle: attendance.hasClockedIn
                ? 'Already checked in today.'
                : 'Scan a valid Check In QR code.',
            icon: Icons.login_rounded,
            enabled: onClockIn != null,
            onTap: onClockIn,
          ),
          const SizedBox(height: 12),
          _AttendanceActionCard(
            title: 'Check Out',
            subtitle: attendance.hasClockedOut
                ? 'Already checked out today.'
                : attendance.hasClockedIn
                    ? 'Scan a valid Check Out QR code.'
                    : 'Available after Check In.',
            icon: Icons.logout_rounded,
            enabled: onClockOut != null,
            onTap: onClockOut,
          ),
        ],
      ),
    );
  }
}

class _AttendanceActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _AttendanceActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Pressable(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: WhiteCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled ? AppColours.blueSoft : AppColours.mutedBox,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: enabled ? AppColours.blue : AppColours.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.t(title),
                    style: TextStyle(
                      fontSize: AppTextSize.s16,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppColours.textMain : AppColours.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text.t(subtitle),
                    style: const TextStyle(
                      fontSize: AppTextSize.s12,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              enabled ? Icons.qr_code_scanner_rounded : Icons.lock_outline_rounded,
              color: enabled ? AppColours.blue : AppColours.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceQrGeneratorSheet extends StatefulWidget {
  final EastAppApi api;

  const _AttendanceQrGeneratorSheet({required this.api});

  @override
  State<_AttendanceQrGeneratorSheet> createState() => _AttendanceQrGeneratorSheetState();
}

class _AttendanceQrGeneratorSheetState extends State<_AttendanceQrGeneratorSheet> {
  String selectedAction = 'CLOCK_IN';
  EastAppAttendanceQrCode? generated;
  bool generating = false;
  String? error;
  Timer? ticker;

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> generate() async {
    if (generating) return;
    AppFeedback.tap();
    setState(() {
      generating = true;
      error = null;
    });
    try {
      final result = await widget.api.generateAttendanceQrCode(
        eventType: selectedAction,
      );
      if (!mounted) return;
      ticker?.cancel();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() {
        generated = result;
        generating = false;
      });
    } on EastAppApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        error = apiError.message;
        generating = false;
      });
    }
  }

  Duration get remaining {
    final value = generated;
    if (value == null) return Duration.zero;
    final delta = value.expiresAt.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }

  String get remainingLabel {
    final value = remaining;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final value = generated;
    final expired = value != null && remaining == Duration.zero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  text.t('Attendance QR Code'),
                  style: const TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
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
            text.t(
              'Select the action first, then press Generate QR. Each QR works for any employee in this business for 30 minutes.',
            ),
            style: const TextStyle(
              fontSize: AppTextSize.s13,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedAction,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: text.t('QR Action'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: [
              DropdownMenuItem(
                value: 'CLOCK_IN',
                child: Text(text.t('Check In')),
              ),
              DropdownMenuItem(
                value: 'CLOCK_OUT',
                child: Text(text.t('Check Out')),
              ),
            ],
            onChanged: generating
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => selectedAction = value);
                  },
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: text.t(generating
                ? 'Generating...'
                : value == null
                    ? 'Generate QR'
                    : 'Generate New QR'),
            icon: Icons.qr_code_2_rounded,
            onPressed: generating ? null : generate,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(
                color: AppColours.red,
                fontSize: AppTextSize.s13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (value != null) ...[
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: WhiteCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text.t(value.actionLabel),
                              style: const TextStyle(
                                fontSize: AppTextSize.s18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SmallStatusPill(
                            text: expired ? text.t('Expired') : remainingLabel,
                            textColour: expired ? AppColours.red : AppColours.green,
                            backgroundColour: expired ? AppColours.redSoft : AppColours.greenSoft,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: expired ? 0.35 : 1,
                        child: QrImageView(
                          data: value.qrPayload,
                          version: QrVersions.auto,
                          size: 250,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        text.t(
                          expired
                              ? 'This QR has expired. Generate a new QR to continue.'
                              : 'Valid for multiple employees until ${_formatAttendanceQrTime(value.expiresAt)}.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTextSize.s13,
                          color: expired ? AppColours.red : AppColours.textMuted,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceQrScannerSheet extends StatefulWidget {
  final String actionLabel;

  const _AttendanceQrScannerSheet({required this.actionLabel});

  @override
  State<_AttendanceQrScannerSheet> createState() => _AttendanceQrScannerSheetState();
}

class _AttendanceQrScannerSheetState extends State<_AttendanceQrScannerSheet> {
  final MobileScannerController scannerController = MobileScannerController();
  bool handled = false;

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  void onDetect(BarcodeCapture capture) {
    if (handled) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        value = candidate;
        break;
      }
    }
    if (value == null) return;
    handled = true;
    AppFeedback.success();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  text.t('Scan ${widget.actionLabel} QR'),
                  style: const TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
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
            text.t(
              'Scan a valid ${widget.actionLabel} QR code. GPS will be captured after the QR is scanned.',
            ),
            style: const TextStyle(
              fontSize: AppTextSize.s13,
              color: AppColours.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: scannerController,
                    onDetect: onDetect,
                  ),
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAttendanceQrTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}


class _PeopleMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PeopleMiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColours.blue, size: 18),
          const SizedBox(width: 6),
          Text(
            text.t(value),
            style: const TextStyle(
              fontSize: AppTextSize.s16,
              fontWeight: FontWeight.w700,
              color: AppColours.textMain,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text.t(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleSectionTitle extends StatelessWidget {
  final String title;

  const _PeopleSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 7),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: AppTextSize.s15,
          fontWeight: FontWeight.w700,
          color: AppColours.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PeopleMenuGrid extends StatelessWidget {
  final List<Widget> children;

  const _PeopleMenuGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 330;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: cardWidth, height: 100, child: child))
              .toList(),
        );
      },
    );
  }
}


class _PeopleMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badgeWidget;

  const _PeopleMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeWidget,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColours.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColours.blue, size: 22),
                  ),
                  const Spacer(),
                  ?badgeWidget,
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColours.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                text.t(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text.t(subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleUserList extends StatelessWidget {
  final List<_PeopleUser> users;
  final ValueChanged<_PeopleUser>? onUserTap;

  const _PeopleUserList({
    required this.users,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    if (users.isEmpty) {
      return WhiteCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          text.t('No user found'),
          style: const TextStyle(
            fontSize: AppTextSize.s16,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < users.length; i++) ...[
            _PeopleUserRow(
              user: users[i],
              onTap: onUserTap == null ? null : () => onUserTap!(users[i]),
            ),
            if (i != users.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _PeopleUserRow extends StatelessWidget {
  final _PeopleUser user;
  final VoidCallback? onTap;

  const _PeopleUserRow({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final lastWorkingText = user.lastWorkingDate == null
        ? ''
        : ' · ${text.t('Last')}: ${_formatPeopleDate(user.lastWorkingDate)}';

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: user.active ? AppColours.blue : AppColours.mutedBox,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                user.hasProfilePhoto ? Icons.person_rounded : Icons.person_outline_rounded,
                color: user.active ? Colors.white : AppColours.textMuted,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.employeeId} · ${text.t(user.role)} · ${user.phoneNumber}$lastWorkingText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s12,
                      color: AppColours.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SmallStatusPill(
              text: text.t(user.active ? 'Active' : 'Inactive'),
              textColour: user.active ? AppColours.green : AppColours.textMuted,
              backgroundColour: user.active ? AppColours.greenSoft : AppColours.mutedBox,
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserDraft {
  final String? password;
  final String fullName;
  final String phoneE164;
  final String roleId;
  final DateTime? birthDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;

  const _UserDraft({
    required this.password,
    required this.fullName,
    required this.phoneE164,
    required this.roleId,
    required this.birthDate,
    required this.startDate,
    required this.endDate,
    required this.active,
  });
}

class _UserFormSheet extends StatefulWidget {
  final _PeopleUser? user;
  final EastAppTenant tenant;
  final List<_PeopleRole> initialRoles;
  final Future<List<_PeopleRole>> Function()? loadRoles;
  final bool allowRoleEdit;
  final Set<String>? allowedRoleSystemKeys;
  final bool allowPasswordReset;
  final bool allowStatusEdit;
  final Future<String?> Function(_UserDraft draft) onSaveUser;
  final VoidCallback? onDeleteUser;

  const _UserFormSheet({
    this.user,
    required this.tenant,
    this.initialRoles = const <_PeopleRole>[],
    this.loadRoles,
    this.allowRoleEdit = false,
    this.allowedRoleSystemKeys,
    this.allowPasswordReset = true,
    this.allowStatusEdit = true,
    required this.onSaveUser,
    this.onDeleteUser,
  });

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final employeeIdController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  PhoneCountry phoneCountry = defaultPhoneCountry;

  DateTime? bornDate;
  DateTime? startDate = DateTime.now();
  DateTime? endDate;
  List<_PeopleRole> availableRoles = const [];
  String selectedRole = '';
  bool active = true;
  bool showErrors = false;
  bool saving = false;
  bool rolesLoading = false;
  bool contactsLoading = false;
  String? rolesError;
  bool obscurePassword = true;

  bool get isEditing => widget.user != null;

  String? get passwordError {
    if (!showErrors) return null;
    final value = passwordController.text;
    if (isEditing && !widget.allowPasswordReset) return null;
    if (value.isNotEmpty && value.length < 4) return 'Minimum 4 characters';
    return null;
  }

  String? get fullNameError =>
      showErrors && fullNameController.text.trim().isEmpty
          ? 'Full Name required'
          : null;

  String? get bornDateError =>
      showErrors && bornDate == null ? 'Born Date required' : null;

  String? get phoneError {
    if (!showErrors) return null;
    if (phoneController.text.trim().isEmpty) return 'Phone Number required';
    final value = buildE164(phoneCountry, phoneController.text);
    if (!isValidE164(value)) return 'Enter a valid phone number';
    return null;
  }

  bool roleAllowed(_PeopleRole role) {
    final allowedKeys = widget.allowedRoleSystemKeys;
    if (allowedKeys == null) return true;
    return allowedKeys.contains(role.systemKey);
  }

  List<_PeopleRole> get selectableRoles {
    return availableRoles.where((role) {
      return role.active && roleAllowed(role);
    }).toList(growable: false);
  }

  bool get roleAvailableForAssignment {
    return selectableRoles.any((role) => role.name == selectedRole);
  }

  String? get roleError => showErrors && !roleAvailableForAssignment
      ? rolesLoading
          ? 'Loading roles'
          : 'Active Role required'
      : null;

  bool get canSubmitUser =>
      passwordError == null &&
      fullNameError == null &&
      bornDateError == null &&
      phoneError == null &&
      roleError == null &&
      !rolesLoading;

  @override
  void initState() {
    super.initState();
    availableRoles = widget.initialRoles;
    final user = widget.user;
    if (user != null && availableRoles.any((role) => role.id == user.roleId)) {
      selectedRole = user.role;
    } else {
      selectedRole = _defaultRoleName(selectableRoles);
    }

    if (user != null) {
      employeeIdController.text = user.employeeId;
      fullNameController.text = user.fullName;
      phoneCountry = countryFromE164(user.phoneNumber);
      phoneController.text = localDigitsFromE164(user.phoneNumber, phoneCountry);
      bornDate = user.bornDate;
      startDate = user.startDate;
      endDate = user.endDate;
      active = user.active;
    }

    if (widget.loadRoles != null) {
      unawaited(loadAssignableRoles());
    }
  }

  Future<void> loadAssignableRoles() async {
    setState(() {
      rolesLoading = true;
      rolesError = null;
    });
    try {
      final loaded = await widget.loadRoles!();
      if (!mounted) return;
      setState(() {
        availableRoles = loaded;
        if (!availableRoles.any((role) => role.name == selectedRole)) {
          selectedRole = _defaultRoleName(selectableRoles);
        }
        rolesLoading = false;
      });
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        rolesError = error.message;
        rolesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    employeeIdController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String formatDate(DateTime? value, {String fallback = 'Select date'}) {
    if (value == null) return fallback;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> pickDate({
    required DateTime? initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    FocusScope.of(context).unfocus();
    AppFeedback.select();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() => onPicked(picked));
  }

  Future<void> pickPhoneFromContacts() async {
    FocusScope.of(context).unfocus();
    await AppFeedback.select();
    if (!mounted) return;
    setState(() => contactsLoading = true);
    final text = AppTextScope.of(context);
    try {
      final phones = await loadDeviceContactPhones();
      if (!mounted) return;
      if (phones.isEmpty) {
        showErrorSnackBar(context, text.t('No contacts with phone numbers'));
        return;
      }
      final selected = await showDeviceContactPhonePicker(context, phones);
      if (selected == null || !mounted) return;
      final value = phoneFieldValueFromContact(
        selected.number,
        fallbackCountry: phoneCountry,
      );
      if (value == null) {
        showErrorSnackBar(
          context,
          text.t("This contact's country code is not supported."),
        );
        return;
      }
      setState(() {
        phoneCountry = value.country;
        phoneController.text = value.localDigits;
      });
    } on DeviceContactsPermissionException {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        text.t('Full Contacts access is required. Allow it in Settings.'),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, text.t('Could not load contacts.'));
    } finally {
      if (mounted) setState(() => contactsLoading = false);
    }
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => showErrors = true);
    if (!canSubmitUser) {
      AppFeedback.warning();
      return;
    }

    final selected = selectableRoles.firstWhere(
      (role) => role.name == selectedRole,
    );
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t(isEditing ? 'Update User?' : 'Create User?'),
      details: text.t(selected.systemKey == 'OWNER' &&
              (!isEditing || widget.user?.roleSystemKey != 'OWNER')
          ? 'This will assign Owner access and a separate employee ID in every business.'
          : isEditing
              ? 'This will update the selected user account and access settings.'
              : 'This will create an employee ID only inside ${widget.tenant.businessName}.'),
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      final generatedEmployeeId = await widget.onSaveUser(
        _UserDraft(
          password: !widget.allowPasswordReset || passwordController.text.isEmpty
              ? null
              : passwordController.text,
          fullName: fullNameController.text.trim(),
          phoneE164: buildE164(phoneCountry, phoneController.text),
          roleId: selected.id,
          birthDate: bornDate,
          startDate: startDate,
          endDate: endDate,
          active: isEditing ? active : true,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(
        context,
        text.t(isEditing
            ? 'User updated'
            : generatedEmployeeId == null
                ? 'User created'
                : 'User created · $generatedEmployeeId'),
      );
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PeopleSheetHandle(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    text.t(isEditing ? 'Edit User' : 'Create User'),
                    style: const TextStyle(
                      fontSize: AppTextSize.s26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isEditing)
              _PeopleInput(
                label: 'Employee ID',
                controller: employeeIdController,
                hint: '',
                keyboardType: TextInputType.text,
                enabled: false,
              )
            else
              WhiteCard(
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColours.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text.t(
                          'Employee ID will be generated automatically by this business.',
                        ),
                        style: const TextStyle(
                          fontSize: AppTextSize.s14,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            WhiteCard(
              child: Row(
                children: [
                  const Icon(Icons.business_outlined, color: AppColours.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.t('Business'),
                          style: const TextStyle(
                            fontSize: AppTextSize.s12,
                            color: AppColours.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.tenant.businessName,
                          style: const TextStyle(
                            fontSize: AppTextSize.s16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isEditing || widget.allowPasswordReset) ...[
              const SizedBox(height: 12),
              _PeopleInput(
                label: isEditing ? 'New Password (Optional)' : 'Password',
                controller: passwordController,
                hint: isEditing
                    ? 'Minimum 4 characters'
                    : 'Required for a new person; blank for an existing login',
                keyboardType: TextInputType.visiblePassword,
                obscureText: obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => obscurePassword = !obscurePassword);
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                errorText: passwordError,
                onChanged: (_) {
                  if (showErrors) setState(() {});
                },
              ),
              if (!isEditing) ...[
                const SizedBox(height: 6),
                Text(
                  text.t(
                    'When the phone number already belongs to an application login, the same profile and password are reused and only a new employee ID is created for this business.',
                  ),
                  style: const TextStyle(
                    fontSize: AppTextSize.s12,
                    color: AppColours.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            _PeopleInput(
              label: 'Full Name',
              controller: fullNameController,
              hint: 'Example: Lee Kim Khong',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              errorText: fullNameError,
              onChanged: (_) {
                if (showErrors) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Born Date',
              value: formatDate(bornDate),
              icon: Icons.cake_outlined,
              errorText: bornDateError,
              onTap: () => pickDate(
                initialDate: bornDate ?? DateTime(1998, 1, 1),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                onPicked: (value) => bornDate = value,
              ),
            ),
            const SizedBox(height: 12),
            PhoneNumberField(
              label: text.t('Phone Number'),
              controller: phoneController,
              country: phoneCountry,
              onCountryChanged: (value) {
                setState(() => phoneCountry = value);
              },
              hint: '165076207',
              errorText: phoneError,
              onChanged: (_) {
                if (showErrors) setState(() {});
              },
              onContactPressed: isEditing ? null : pickPhoneFromContacts,
              contactLoading: contactsLoading,
            ),
            const SizedBox(height: 12),
            if (rolesLoading)
              WhiteCard(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(text.t('Loading roles for this business...')),
                  ],
                ),
              )
            else if (rolesError != null)
              WhiteCard(
                child: Column(
                  children: [
                    Text(rolesError!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: loadAssignableRoles,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(text.t('Retry')),
                    ),
                  ],
                ),
              )
            else
              _RoleField(
                value: selectedRole,
                roles: selectableRoles,
                errorText: roleError,
                helperText: 'Only roles from ${widget.tenant.businessName} are loaded.',
                onChanged: widget.allowRoleEdit
                    ? (value) {
                        if (value == null) return;
                        AppFeedback.select();
                        setState(() => selectedRole = value);
                      }
                    : null,
              ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Start Date',
              value: formatDate(startDate, fallback: 'Not set'),
              icon: Icons.event_available_outlined,
              onTap: () => pickDate(
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                onPicked: (value) => startDate = value,
              ),
              trailing: startDate == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => startDate = null),
                      icon: const Icon(Icons.clear_rounded, size: 20),
                    ),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'End Date (Optional)',
              value: formatDate(endDate, fallback: 'Not set'),
              icon: Icons.event_busy_outlined,
              onTap: () => pickDate(
                initialDate: endDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                onPicked: (value) => endDate = value,
              ),
              trailing: endDate == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => endDate = null),
                      icon: const Icon(Icons.clear_rounded, size: 20),
                    ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              _ActiveStatusField(
                value: active,
                onChanged: !widget.allowStatusEdit
                    ? null
                    : (value) {
                        if (value == null) return;
                        AppFeedback.select();
                        setState(() => active = value);
                      },
              ),
            ],
            if (isEditing &&
                widget.allowStatusEdit &&
                widget.user?.active == true) ...[
              const SizedBox(height: 12),
              _DangerButton(
                text: 'Deactivate User',
                icon: Icons.person_remove_outlined,
                onPressed: saving ? null : widget.onDeleteUser,
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              text: text.t(saving
                  ? 'Saving...'
                  : isEditing
                      ? 'Save Changes'
                      : 'Save User'),
              icon: Icons.save_outlined,
              onPressed: saving ? null : submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteUserSheet extends StatefulWidget {
  final _PeopleUser user;
  final Future<void> Function(DateTime lastWorkingDate) onDeactivateUser;

  const _DeleteUserSheet({
    required this.user,
    required this.onDeactivateUser,
  });

  @override
  State<_DeleteUserSheet> createState() => _DeleteUserSheetState();
}

class _DeleteUserSheetState extends State<_DeleteUserSheet> {
  DateTime lastWorkingDate = DateTime.now();
  bool saving = false;

  String formatDate(DateTime value) => _formatPeopleDate(value);

  Future<void> pickLastWorkingDate() async {
    FocusScope.of(context).unfocus();
    AppFeedback.select();
    final picked = await showDatePicker(
      context: context,
      initialDate: lastWorkingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() => lastWorkingDate = picked);
  }

  Future<void> submit() async {
    final text = AppTextScope.of(context);
    final confirmed = await confirmDataChange(
      context,
      action: text.t('Deactivate User?'),
      details: text.t(
        'This will set the user to inactive using the selected last working date.',
      ),
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      await widget.onDeactivateUser(lastWorkingDate);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(context, text.t('User set to inactive'));
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PeopleSheetHandle(),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColours.redSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_remove_outlined,
                    color: AppColours.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.t('Deactivate User'),
                        style: const TextStyle(
                          fontSize: AppTextSize.s24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.user.fullName} · ${widget.user.employeeId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.s14,
                          color: AppColours.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColours.redSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColours.red.withValues(alpha: 0.18)),
              ),
              child: Text(
                text.t(
                  'Status will be set to Inactive and all sessions will be revoked.',
                ),
                style: const TextStyle(
                  fontSize: AppTextSize.s14,
                  color: AppColours.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Last Working Date',
              value: formatDate(lastWorkingDate),
              icon: Icons.event_busy_outlined,
              onTap: saving ? null : pickLastWorkingDate,
            ),
            const SizedBox(height: 16),
            _DangerButton(
              text: saving ? 'Saving...' : 'Set User Inactive',
              icon: Icons.block_outlined,
              onPressed: saving ? null : submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const _DangerButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final appText = AppTextScope.of(context);
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColours.redSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColours.red.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColours.red, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                appText.t(text),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  color: AppColours.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;

  const _PeopleInput({
    required this.label,
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.t(label), style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.next,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          onChanged: onChanged,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: AppTextStyles.formValue,
          decoration: AppInputStyle.decoration(
            text.t(hint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ).copyWith(
            errorText: errorText == null ? null : text.t(errorText!),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? errorText;

  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.t(label), style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        WhiteCard(
          padding: EdgeInsets.zero,
          child: Pressable(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: errorText == null ? AppColours.blue : AppColours.red, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text.t(value),
                      style: TextStyle(
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w700,
                        color: errorText == null ? AppColours.textMain : AppColours.red,
                      ),
                    ),
                  ),
                  ?trailing,
                  const Icon(Icons.calendar_month_outlined, color: AppColours.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Text(
            text.t(errorText!),
            style: const TextStyle(
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w700,
              color: AppColours.red,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveStatusField extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _ActiveStatusField({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.t('Active'), style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        DropdownButtonFormField<bool>(
          initialValue: value,
          items: [
            DropdownMenuItem<bool>(
              value: true,
              child: Text(text.t('Active')),
            ),
            DropdownMenuItem<bool>(
              value: false,
              child: Text(text.t('Inactive')),
            ),
          ],
          onChanged: onChanged,
          decoration: AppInputStyle.decoration(
            text.t('Select status'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: const TextStyle(
            fontSize: AppTextSize.s17,
            fontWeight: FontWeight.w700,
            color: AppColours.textMain,
          ),
        ),
      ],
    );
  }
}

class _RoleField extends StatelessWidget {
  final String value;
  final List<_PeopleRole> roles;
  final ValueChanged<String?>? onChanged;
  final String? helperText;
  final String? errorText;

  const _RoleField({
    required this.value,
    required this.roles,
    required this.onChanged,
    this.helperText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final hasCurrentValue = roles.any((role) => role.name == value);
    final options = hasCurrentValue
        ? roles
        : [
            _PeopleRole(
              id: 'CURRENT',
              systemKey: 'CURRENT',
              name: value,
              active: false,
            ),
            ...roles,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.t('Role'), style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: options
              .map((role) => DropdownMenuItem<String>(
                    value: role.name,
                    child: Text(
                      role.active
                          ? text.t(role.name)
                          : '${text.t(role.name)} · ${text.t('Inactive')}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: AppInputStyle.decoration(
            text.t('Select role'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ).copyWith(
            errorText: errorText == null ? null : text.t(errorText!),
          ),
          style: const TextStyle(
            fontSize: AppTextSize.s17,
            fontWeight: FontWeight.w700,
            color: AppColours.textMain,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            text.t(helperText!),
            style: const TextStyle(
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w600,
              color: AppColours.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeopleSheetHandle extends StatelessWidget {
  const _PeopleSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: AppColours.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

Future<T?> _showPeopleBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  double heightFactor = 0.9,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: heightFactor,
        child: child,
      );
    },
  );
}

String _formatPeopleDate(DateTime? value, {String fallback = 'Not set'}) {
  if (value == null) return fallback;
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

class _PeopleRole {
  final String id;
  final String systemKey;
  final String name;
  final bool active;
  final int assignedUsers;

  const _PeopleRole({
    required this.id,
    required this.systemKey,
    required this.name,
    required this.active,
    this.assignedUsers = 0,
  });

  factory _PeopleRole.fromApi(EastAppRole role) {
    return _PeopleRole(
      id: role.id,
      systemKey: role.systemKey,
      name: role.name,
      active: role.active,
      assignedUsers: role.assignedUsers ?? 0,
    );
  }

  bool get isOwner => systemKey == 'OWNER';
  bool get isHead => systemKey == 'HEAD';

  _PeopleRole copyWith({
    String? name,
    bool? active,
    int? assignedUsers,
  }) {
    return _PeopleRole(
      id: id,
      systemKey: systemKey,
      name: name ?? this.name,
      active: active ?? this.active,
      assignedUsers: assignedUsers ?? this.assignedUsers,
    );
  }
}

String _defaultRoleName(List<_PeopleRole> roles) {
  for (final preferred in const ['Staff1', 'Staff2']) {
    for (final role in roles) {
      if (role.active && role.name == preferred) return role.name;
    }
  }
  for (final role in roles) {
    if (role.active && !role.isHead && !role.isOwner) return role.name;
  }
  for (final role in roles) {
    if (role.active) return role.name;
  }
  return _defaultPeopleRole;
}

class _PeopleUser {
  final String id;
  final String employeeId;
  final String fullName;
  final String? profilePhotoKey;
  final DateTime? bornDate;
  final String phoneNumber;
  final String roleId;
  final String? roleSystemKey;
  final String role;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final String deactivationReason;
  final DateTime? lastWorkingDate;

  const _PeopleUser({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.profilePhotoKey,
    required this.bornDate,
    required this.phoneNumber,
    required this.roleId,
    required this.roleSystemKey,
    required this.role,
    required this.startDate,
    required this.endDate,
    required this.active,
    this.deactivationReason = '',
    this.lastWorkingDate,
  });

  factory _PeopleUser.fromApi(EastAppUser user) {
    return _PeopleUser(
      id: user.id,
      employeeId: user.employeeId,
      fullName: user.fullName,
      profilePhotoKey: user.profilePhotoKey,
      bornDate: user.birthDate,
      phoneNumber: user.phoneE164,
      roleId: user.role.id,
      roleSystemKey: user.role.systemKey,
      role: user.role.name,
      startDate: user.startDate,
      endDate: user.endDate,
      active: user.active,
    );
  }

  bool get hasProfilePhoto => profilePhotoKey != null && profilePhotoKey!.isNotEmpty;
  bool get hasIdPhoto => false;

  _PeopleUser copyWith({
    String? employeeId,
    String? fullName,
    String? profilePhotoKey,
    DateTime? bornDate,
    String? phoneNumber,
    String? roleId,
    String? roleSystemKey,
    String? role,
    DateTime? startDate,
    DateTime? endDate,
    bool? active,
    String? deactivationReason,
    DateTime? lastWorkingDate,
  }) {
    return _PeopleUser(
      id: id,
      employeeId: employeeId ?? this.employeeId,
      fullName: fullName ?? this.fullName,
      profilePhotoKey: profilePhotoKey ?? this.profilePhotoKey,
      bornDate: bornDate ?? this.bornDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roleId: roleId ?? this.roleId,
      roleSystemKey: roleSystemKey ?? this.roleSystemKey,
      role: role ?? this.role,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      deactivationReason: deactivationReason ?? this.deactivationReason,
      lastWorkingDate: lastWorkingDate ?? this.lastWorkingDate,
    );
  }
}

const _defaultPeopleRole = 'Staff1';
