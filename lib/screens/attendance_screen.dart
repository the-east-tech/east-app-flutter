import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';

import '../data/sample_data.dart';
import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../models/attendance_models.dart';
import '../models/auth_models.dart';
import '../models/people_models.dart';
import '../models/points_models.dart';
import '../models/organisation_models.dart';
import '../services/east_app_api.dart';
import '../theme/app_theme.dart';
import '../utils/app_diagnostics.dart';
import '../widgets/app_components.dart';
import '../widgets/app_feedback.dart';
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
  String? usersError;
  String usersSearch = '';
  bool? usersActiveFilter;
  DateTime? usersUpdatedAt;

  bool rolesLoaded = false;
  DateTime? rolesUpdatedAt;
  bool rolesLoading = false;
  String? rolesError;

  EastAppAttendanceToday? todayAttendance;
  bool attendanceLoading = true;
  String? attendanceError;
  _PeoplePage page = _PeoplePage.home;
  double peopleSwipeStartX = 0;
  double peopleSwipeDeltaX = 0;

  bool get isOwner => widget.currentUser.role.isOwner;
  bool get isHead => widget.role == UserRole.head;
  bool get isManager => widget.role == UserRole.manager;
  bool get canManageUsers => isHead || isManager;
  bool get canCreateUsers => isOwner || isHead;
  bool get canManageTenants => isOwner || isHead;
  bool get canManagePoints => isOwner || isHead;

  String get currentSelfUserId => widget.currentUser.employeeId;

  String get currentSelfUserName => widget.currentUser.fullName;

  @override
  void initState() {
    super.initState();
    unawaited(loadTodayAttendance());
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      unawaited(loadTodayAttendance());
    }
    final couldManageBefore = oldWidget.role == UserRole.head ||
        oldWidget.role == UserRole.manager;
    if (couldManageBefore == canManageUsers) return;

    if (!canManageUsers) {
      users = [];
      roles = [];
      usersPage = 0;
      usersTotal = 0;
      usersLastPage = true;
      usersLoading = false;
      usersLoadingMore = false;
      usersError = null;
      rolesLoaded = false;
      rolesLoading = false;
      rolesError = null;
      page = _PeoplePage.home;
    }
  }

  Future<void> loadTodayAttendance() async {
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
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        attendanceError = error.message;
        attendanceLoading = false;
      });
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
      'page': '$nextPage',
      'size': '$_usersPageSize',
    }).query;
    final cacheKey = '${EastAppApi.usersCachePrefix(widget.currentTenant.id)}$query';
    try {
      final result = await widget.api.listUsers(
        search: usersSearch,
        active: usersActiveFilter,
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
        usersUpdatedAt = widget.api.featureCacheUpdatedAt(cacheKey) ?? DateTime.now();
      });
    } on EastAppApiException catch (error) {
      if (!mounted || !canManageUsers) return;
      setState(() {
        usersError = error.message;
        usersLoading = false;
        usersLoadingMore = false;
      });
    }
  }

  Future<void> loadRoles({bool force = false}) async {
    if (!canManageUsers || rolesLoading || rolesLoaded && !force) return;
    setState(() {
      rolesLoading = true;
      rolesError = null;
    });
    final cacheKey = '${EastAppApi.rolesCachePrefix(widget.currentTenant.id)}all';
    try {
      final result = await widget.api.listRoles(
        tenantId: widget.currentTenant.id,
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
    usersSearch = value.trim();
    unawaited(loadUsers(reset: true));
  }

  void updateUsersActiveFilter(bool? value) {
    usersActiveFilter = value;
    unawaited(loadUsers(reset: true));
  }

  void openPage(_PeoplePage nextPage) {
    if (page == nextPage) return;
    if ((nextPage == _PeoplePage.users || nextPage == _PeoplePage.roles) &&
        !canManageUsers) {
      showWarningSnackBar(context, 'Only Owner, Head and Manager can view setup.');
      return;
    }
    if (nextPage == _PeoplePage.points && !canManagePoints) {
      showWarningSnackBar(context, 'Only Owner and Head can adjust points.');
      return;
    }
    if (nextPage == _PeoplePage.tenants && !canManageTenants) {
      showWarningSnackBar(context, 'Only Owner and Head can manage businesses.');
      return;
    }
    if (nextPage == _PeoplePage.audit && !isHead) {
      showWarningSnackBar(context, 'Only Owner and Head can view People Audit.');
      return;
    }
    AppFeedback.select();
    setState(() => page = nextPage);
    if (nextPage == _PeoplePage.users) {
      unawaited(loadUsers(reset: true));
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

  bool _isTodayAttendanceText(String? value) {
    if (value == null) return false;
    final lower = value.toLowerCase();
    return lower.contains('today') ||
        lower.contains('just now') ||
        lower.contains('server time');
  }

  AttendanceRecord? get _selfTodayAttendanceRecord {
    for (final record in widget.attendanceRecords) {
      if (record.staffId != currentSelfUserId) continue;
      if (_isTodayAttendanceText(record.clockInTime) ||
          _isTodayAttendanceText(record.clockOutTime)) {
        return record;
      }
    }
    return null;
  }

  void showComingSoon(String title) {
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
                    title,
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
            const Text(
              'Coming soon. User setup is enabled first.',
              style: TextStyle(
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


  void openAttendanceOptions() {
    unawaited(_openAttendanceOptions());
  }

  Future<void> _openAttendanceOptions() async {
    AppFeedback.tap();
    final hasAccess = await _ensureAttendanceAccess();
    if (!hasAccess) return;

    if (attendanceLoading) {
      showWarningSnackBar(context, 'Loading attendance status.');
      return;
    }
    if (attendanceError != null) {
      showErrorSnackBar(context, attendanceError!);
      return;
    }

    openFaceScanSheet();
  }

  Future<bool> _ensureAttendanceAccess() async {
    AppDiagnostics.instance.log('Attendance permission gate started: request location permission, then request camera permission, then decide whether Attendance Verification can open');

    final locationIssue = await _checkLocationAccessForAttendance();
    final cameraIssue = await _checkCameraAccessForAttendance();

    final issues = <String>[
      if (locationIssue != null) locationIssue,
      if (cameraIssue != null) cameraIssue,
    ];

    if (issues.isNotEmpty) {
      AppFeedback.warning();
      AppDiagnostics.instance.log(jsonEncode({
        'source': 'EastApp.attendancePermissionGate.response',
        'accepted': false,
        'location.accepted': locationIssue == null,
        'camera.accepted': cameraIssue == null,
        'location.issue': locationIssue,
        'camera.issue': cameraIssue,
        'rule': 'request_location_then_camera_before_opening_verification',
        'opensAttendanceVerification': false,
      }));
      if (mounted) _showAttendanceAccessRequired(issues);
      return false;
    }

    AppDiagnostics.instance.log(jsonEncode({
      'source': 'EastApp.attendancePermissionGate.response',
      'accepted': true,
      'location.accepted': true,
      'camera.accepted': true,
      'rule': 'request_location_then_camera_before_opening_verification',
      'opensAttendanceVerification': true,
    }));
    return true;
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

  Future<String?> _checkCameraAccessForAttendance() async {
    CameraController? probeController;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return jsonEncode({
          'source': 'camera.permissionGate.availableCameras.response',
          'availableCameras.length': 0,
          'availableCameras': <Object?>[],
        });
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      AppDiagnostics.instance.setDeviceInfo(jsonEncode({
        'source': 'dart:io.Platform.permissionGate',
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion.replaceAll('\n', ' '),
      }));
      AppDiagnostics.instance.setCameraInfo(jsonEncode({
        'source': 'camera.permissionGate.availableCameras.response',
        'permissionGate.intent': 'request_camera_permission_before_opening_attendance',
        'permissionGate.initialisesCamera': true,
        'permissionGate.initialisesCamera.reason': 'camera plugin exposes permission through CameraController.initialize',
        'permissionGate.resolutionPreset': 'low',
        'availableCameras.length': cameras.length,
        'availableCameras': cameras.map((item) => {
              'name': item.name,
              'lensDirection': item.lensDirection.name,
              'sensorOrientation': item.sensorOrientation,
            }).toList(),
        'selectedCamera.name': camera.name,
        'selectedCamera.lensDirection': camera.lensDirection.name,
        'selectedCamera.sensorOrientation': camera.sensorOrientation,
      }));

      probeController = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await probeController.initialize();
      AppDiagnostics.instance.setCameraInfo(jsonEncode({
        'source': 'CameraController.initialize.permissionGate.response',
        'permissionGate.intent': 'camera_permission_granted_before_opening_attendance',
        'permissionGate.initialisesCamera': true,
        'permissionGate.resolutionPreset': 'low',
        'availableCameras.length': cameras.length,
        'availableCameras': cameras.map((item) => {
              'name': item.name,
              'lensDirection': item.lensDirection.name,
              'sensorOrientation': item.sensorOrientation,
            }).toList(),
        'selectedCamera.name': camera.name,
        'selectedCamera.lensDirection': camera.lensDirection.name,
        'selectedCamera.sensorOrientation': camera.sensorOrientation,
        'controller.value.isInitialized': probeController.value.isInitialized,
        'controller.value.previewSize': probeController.value.previewSize?.toString(),
      }));
      return null;
    } on CameraException catch (error) {
      return jsonEncode({
        'source': 'CameraController.initialize.permissionGate.catch',
        'permissionGate.intent': 'request_camera_permission_before_opening_attendance',
        'error.runtimeType': error.runtimeType.toString(),
        'error.code': error.code,
        'error.description': error.description,
      });
    } catch (error) {
      return jsonEncode({
        'source': 'CameraController.initialize.permissionGate.catch',
        'permissionGate.intent': 'request_camera_permission_before_opening_attendance',
        'error.runtimeType': error.runtimeType.toString(),
        'error.toString': error.toString(),
      });
    } finally {
      await probeController?.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }

  void _showAttendanceAccessRequired(List<String> issues) {
    _showPeopleBottomSheet(
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
                    color: AppColours.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_person_outlined, color: AppColours.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attendance access required',
                    style: TextStyle(
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
            const Text(
              'Camera and location are required before using Attendance.',
              style: TextStyle(
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
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppColours.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue,
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
                    text: 'Location Settings',
                    icon: Icons.location_on_outlined,
                    onPressed: () => Geolocator.openLocationSettings(),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    text: 'App Settings',
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

  void openFaceScanSheet() {
    final initialMode = todayAttendance?.hasClockedIn == true &&
            todayAttendance?.hasClockedOut != true
        ? 'Clock Out'
        : 'Clock In';

    _showPeopleBottomSheet(
      context,
      heightFactor: 0.94,
      child: _FaceScanSheet(
        api: widget.api,
        workLocation: widget.workLocation,
        branchName: widget.workLocation.name,
        initialMode: initialMode,
        onSubmit: (modeLabel, capturedLocation, submissionData) async {
          final event = await widget.api.createAttendanceEvent(
            clientEventId: _newAttendanceClientEventId(),
            eventType: modeLabel == 'Clock Out' ? 'CLOCK_OUT' : 'CLOCK_IN',
            deviceCapturedAt: submissionData.deviceCapturedAt,
            latitude: capturedLocation.latitude,
            longitude: capturedLocation.longitude,
            accuracyMeters: capturedLocation.accuracyMeters.toDouble(),
            cameraCaptureValid: true,
            faceValid: submissionData.faceValid,
            faceCount: submissionData.faceCount,
            faceAttemptCount: submissionData.faceAttemptCount,
            faceVerificationBypassed: submissionData.faceVerificationBypassed,
            faceBoxWidth: submissionData.faceBoxWidth,
            faceBoxHeight: submissionData.faceBoxHeight,
            faceYaw: submissionData.faceYaw,
            faceRoll: submissionData.faceRoll,
            facePitch: submissionData.facePitch,
            qrCheckpointValid: true,
            devicePlatform: submissionData.devicePlatform,
            deviceOsVersion: submissionData.deviceOsVersion,
            appVersion: 'east_app_v272',
            validationMethod: submissionData.faceVerificationBypassed
                ? 'FACE_DETECTION_BYPASSED_AFTER_3_ATTEMPTS'
                : 'ML_KIT_FACE_DETECTION',
          );

          await loadTodayAttendance();
          if (!mounted) return;
          Navigator.of(context).pop();
          showSuccessSnackBar(
            context,
            modeLabel == 'Clock Out'
                ? 'Clock out completed'
                : 'Clock in completed',
          );
        },
      ),
    );
  }

  Future<void> openUserForm() async {
    if (!canCreateUsers) {
      showWarningSnackBar(
        context,
        'Only Owner and Head can create users.',
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
          unawaited(loadUsers(reset: true, forceRefresh: true));
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
    if (!await ensureRolesLoaded()) return;

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.94,
      child: _UserFormSheet(
        user: user,
        tenant: widget.currentTenant,
        initialRoles: roles,
        allowRoleEdit: true,
        allowedRoleSystemKeys:
            isManager ? const {'STAFF_1', 'STAFF_2'} : null,
        allowPasswordReset: user.id != widget.currentUser.id,
        allowStatusEdit: user.id != widget.currentUser.id,
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
          await Future.wait([
            loadUsers(reset: true, forceRefresh: true),
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
          await Future.wait([
            loadUsers(reset: true, forceRefresh: true),
            loadRoles(force: true),
          ]);
        },
      ),
    );
  }

  void openRoleForm() {
    if (!isHead) {
      showWarningSnackBar(context, 'Only Owner and Head can create roles.');
      return;
    }

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.66,
      child: _RoleFormSheet(
        existingRoles: roles,
        onSaveRole: (draft) async {
          await widget.api.createRole(name: draft.name);
          await loadRoles(force: true);
        },
      ),
    );
  }

  void openEditRoleForm(_PeopleRole role) {
    if (!isHead) return;

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.72,
      child: _RoleFormSheet(
        role: role,
        existingRoles: roles,
        assignedCount: role.assignedUsers,
        onSaveRole: (draft) async {
          await widget.api.updateRole(
            roleId: role.id,
            name: draft.name,
            active: draft.active,
          );
          if (widget.currentUser.role.id == role.id && widget.api.token != null) {
            final refreshed = await widget.api.currentSession(widget.api.token!);
            widget.onCurrentUserChanged(refreshed.user);
          }
          await loadRoles(force: true);
        },
        onDeleteRole: role.assignedUsers == 0 && !role.isBuiltIn
            ? () {
                Navigator.of(context).pop();
                Future.microtask(() => openDeleteRoleForm(role));
              }
            : null,
      ),
    );
  }

  void openDeleteRoleForm(_PeopleRole role) {
    if (role.isBuiltIn) {
      showWarningSnackBar(context, 'Built-in roles cannot be deleted.');
      return;
    }
    if (role.assignedUsers > 0) {
      showWarningSnackBar(context, 'Assigned roles cannot be deleted.');
      return;
    }

    _showPeopleBottomSheet<void>(
      context,
      heightFactor: 0.42,
      child: _DeleteRoleSheet(
        role: role,
        onDeleteRole: () async {
          await widget.api.deleteRole(role.id);
          await loadRoles(force: true);
        },
      ),
    );
  }

  Widget buildPeopleHome(BuildContext context) {
    final text = AppTextScope.of(context);
    final selfCheckedIn = todayAttendance?.hasClockedIn ?? false;
    final selfCheckedOut = todayAttendance?.hasClockedOut ?? false;

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
              badgeWidget: _AttendanceProgressBadge(
                inDone: selfCheckedIn,
                outDone: selfCheckedOut,
              ),
            ),
            _PeopleMenuCard(
              title: text.t('Schedule'),
              subtitle: text.t('Shift planning'),
              icon: Icons.calendar_month_outlined,
              onTap: () => showComingSoon(text.t('Schedule')),
            ),
            _PeopleMenuCard(
              title: text.t('Role'),
              subtitle: text.t(isHead ? 'Manage roles' : 'View roles'),
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
            loading: usersLoading,
            loadingMore: usersLoadingMore,
            lastPage: usersLastPage,
            error: usersError,
            activeFilter: usersActiveFilter,
            canManageUsers: canManageUsers,
            canCreateUsers: canCreateUsers,
            onBack: goPeopleHome,
            onCreateUser: openUserForm,
            onUserTap: canManageUsers ? openEditUserForm : null,
            onSearchChanged: updateUsersSearch,
            onActiveFilterChanged: updateUsersActiveFilter,
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
            canManageRoles: isHead,
            onBack: goPeopleHome,
            onCreateRole: openRoleForm,
            onRoleTap: isHead ? openEditRoleForm : null,
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
    return WillPopScope(
      onWillPop: handleBackNavigation,
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
            Expanded(child: PageTitle(title: title, subtitle: subtitle)),
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
                updatedText,
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
              label: const Text('Refresh'),
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
  final bool loading;
  final bool loadingMore;
  final bool lastPage;
  final String? error;
  final bool? activeFilter;
  final bool canManageUsers;
  final bool canCreateUsers;
  final VoidCallback onBack;
  final VoidCallback onCreateUser;
  final ValueChanged<_PeopleUser>? onUserTap;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onActiveFilterChanged;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRetry;

  const _UserSetupPage({
    required this.users,
    required this.totalUsers,
    required this.loading,
    required this.loadingMore,
    required this.lastPage,
    required this.error,
    required this.activeFilter,
    required this.canManageUsers,
    required this.canCreateUsers,
    required this.onBack,
    required this.onCreateUser,
    required this.onUserTap,
    required this.onSearchChanged,
    required this.onActiveFilterChanged,
    required this.onLoadMore,
    required this.onRetry,
  });

  @override
  State<_UserSetupPage> createState() => _UserSetupPageState();
}

class _UserSetupPageState extends State<_UserSetupPage> {
  final searchController = TextEditingController();
  Timer? searchDebounce;

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void handleSearch(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => widget.onSearchChanged(value),
    );
    setState(() {});
  }

  String get statusValue {
    if (widget.activeFilter == true) return 'Active';
    if (widget.activeFilter == false) return 'Inactive';
    return 'All';
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
                      searchDebounce?.cancel();
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
                  child: const Text('Retry'),
                ),
              ],
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
                label: Text(widget.loadingMore ? 'Loading...' : 'Load more'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RoleSetupPage extends StatefulWidget {
  final List<_PeopleRole> roles;
  final bool loading;
  final String? error;
  final bool canManageRoles;
  final VoidCallback onBack;
  final VoidCallback onCreateRole;
  final ValueChanged<_PeopleRole>? onRoleTap;
  final Future<void> Function() onRetry;

  const _RoleSetupPage({
    required this.roles,
    required this.loading,
    required this.error,
    required this.canManageRoles,
    required this.onBack,
    required this.onCreateRole,
    required this.onRoleTap,
    required this.onRetry,
  });

  @override
  State<_RoleSetupPage> createState() => _RoleSetupPageState();
}

class _RoleSetupPageState extends State<_RoleSetupPage> {
  final searchController = TextEditingController();
  String statusFilter = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  int assignedCount(String roleName) {
    return widget.roles
        .firstWhere((role) => role.name == roleName)
        .assignedUsers;
  }

  List<_PeopleRole> get filteredRoles {
    final query = searchController.text.trim().toLowerCase();
    return widget.roles.where((role) {
      final matchesSearch = query.isEmpty ||
          role.name.toLowerCase().contains(query) ||
          role.id.toLowerCase().contains(query);
      final matchesStatus = statusFilter == 'All' ||
          (statusFilter == 'Active' && role.active) ||
          (statusFilter == 'Inactive' && !role.active);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final visibleRoles = filteredRoles;
    final activeRoles = widget.roles.where((role) => role.active).length;
    final rolesInUse = widget.roles.where((role) => role.assignedUsers > 0).length;

    return _PeoplePageScaffold(
      title: text.t('Role'),
      subtitle: widget.canManageRoles
          ? text.t('Manage roles and availability.')
          : text.t('View roles.'),
      onBack: widget.onBack,
      trailing: widget.canManageRoles
          ? SizedBox(
              width: 150,
              child: PrimaryButton(
                text: text.t('Create Role'),
                icon: Icons.add_rounded,
                onPressed: widget.onCreateRole,
              ),
            )
          : null,
      children: [
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
                  child: const Text('Retry'),
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
                  value: '${widget.roles.length}',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PeopleMiniMetric(
                  label: text.t('Active'),
                  value: '$activeRoles',
                  icon: Icons.verified_outlined,
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
          TextField(
            controller: searchController,
            style: AppTextStyles.formValue,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: AppInputStyle.decoration(
              text.t('Search roles'),
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
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          _PeopleFilterDropdown(
            label: text.t('Status'),
            value: statusFilter,
            options: const ['All', 'Active', 'Inactive'],
            onChanged: (value) => setState(() => statusFilter = value),
          ),
          const SizedBox(height: 14),
          _PeopleRoleList(
            roles: visibleRoles,
            assignedCount: assignedCount,
            onRoleTap: widget.onRoleTap,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: AppTextStyles.formLabel),
        ),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: (nextValue) {
            if (nextValue == null) return;
            AppFeedback.select();
            onChanged(nextValue);
          },
          decoration: AppInputStyle.decoration(
            label,
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
    if (roles.isEmpty) {
      return const WhiteCard(
        padding: EdgeInsets.all(18),
        child: Text(
          'No role found',
          style: TextStyle(
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
                    role.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.s17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$assignedCount ${assignedCount == 1 ? 'user' : 'users'} assigned',
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
              text: role.active ? 'Active' : 'Inactive',
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

class _AttendanceOptionsSheet extends StatelessWidget {
  final String faceActionText;
  final VoidCallback onScanFace;

  const _AttendanceOptionsSheet({
    required this.faceActionText,
    required this.onScanFace,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.work_history_outlined, color: AppColours.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance',
                      style: TextStyle(
                        fontSize: AppTextSize.s24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose verification method',
                      style: TextStyle(
                        fontSize: AppTextSize.s13,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _AttendanceOptionCard(
            title: 'Scan QR',
            subtitle: 'Coming soon',
            icon: Icons.qr_code_scanner_rounded,
            statusText: 'Soon',
            onTap: null,
          ),
          const SizedBox(height: 10),
          _AttendanceOptionCard(
            title: 'Scan Face',
            subtitle: '$faceActionText with live face presence detection',
            icon: Icons.face_retouching_natural_outlined,
            statusText: 'Try',
            onTap: onScanFace,
          ),
        ],
      ),
    );
  }
}

class _AttendanceOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String statusText;
  final VoidCallback? onTap;

  const _AttendanceOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.statusText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final iconColour = isEnabled ? AppColours.blue : AppColours.textMuted;
    final iconBackground = isEnabled ? AppColours.background : AppColours.mutedBox;
    final titleColour = isEnabled ? AppColours.textMain : AppColours.textMuted;

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Opacity(
          opacity: isEnabled ? 1 : 0.62,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColour, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w700,
                        color: titleColour,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
                text: statusText,
                textColour: isEnabled ? AppColours.green : AppColours.textMuted,
                backgroundColour: isEnabled ? AppColours.greenSoft : AppColours.mutedBox,
              ),
              const SizedBox(width: 4),
              if (isEnabled)
                const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted, size: 22)
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
        ),
      ),
    );
  }
}



class _IosStillPhotoCandidate {
  final int rotationQuarterTurns;
  final bool mirror;

  const _IosStillPhotoCandidate({
    required this.rotationQuarterTurns,
    required this.mirror,
  });

  int get normalisedQuarterTurns => rotationQuarterTurns % 4;

  String get fileSuffix => 'r${normalisedQuarterTurns * 90}_${mirror ? 'mirror' : 'normal'}';
}

class _FaceScanResult {
  final List<Face> faces;
  final Size frameSize;
  final Uint8List? photoBytes;
  final String source;
  final String rawResponse;

  const _FaceScanResult({
    required this.faces,
    required this.frameSize,
    required this.photoBytes,
    required this.source,
    required this.rawResponse,
  });
}

class _NormalisedImageFile {
  final File file;
  final Uint8List bytes;
  final Size frameSize;

  const _NormalisedImageFile({
    required this.file,
    required this.bytes,
    required this.frameSize,
  });
}

class _StillPhotoByteCandidate {
  final int rotationQuarterTurns;
  final bool mirror;

  const _StillPhotoByteCandidate({
    required this.rotationQuarterTurns,
    required this.mirror,
  });

  int get normalisedQuarterTurns => rotationQuarterTurns % 4;

  String get label => 'r${normalisedQuarterTurns * 90}_${mirror ? 'mirror' : 'normal'}';
}

class _MlKitBitmapImage {
  final Uint8List rgbaBytes;
  final Uint8List pngBytes;
  final Size frameSize;
  final int width;
  final int height;
  final _StillPhotoByteCandidate candidate;

  const _MlKitBitmapImage({
    required this.rgbaBytes,
    required this.pngBytes,
    required this.frameSize,
    required this.width,
    required this.height,
    required this.candidate,
  });
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

class _AttendanceSubmissionData {
  final DateTime deviceCapturedAt;
  final bool faceValid;
  final int faceCount;
  final int faceAttemptCount;
  final bool faceVerificationBypassed;
  final double? faceBoxWidth;
  final double? faceBoxHeight;
  final double? faceYaw;
  final double? faceRoll;
  final double? facePitch;
  final String devicePlatform;
  final String deviceOsVersion;

  const _AttendanceSubmissionData({
    required this.deviceCapturedAt,
    required this.faceValid,
    required this.faceCount,
    required this.faceAttemptCount,
    required this.faceVerificationBypassed,
    required this.faceBoxWidth,
    required this.faceBoxHeight,
    required this.faceYaw,
    required this.faceRoll,
    required this.facePitch,
    required this.devicePlatform,
    required this.deviceOsVersion,
  });
}

class _LocationCaptureException implements Exception {
  final String message;

  const _LocationCaptureException(this.message);
}

class _FaceScanSheet extends StatefulWidget {
  final EastAppApi api;
  final WorkLocation workLocation;
  final String branchName;
  final String initialMode;
  final Future<void> Function(
    String modeLabel,
    _CapturedAttendanceLocation capturedLocation,
    _AttendanceSubmissionData submissionData,
  ) onSubmit;

  const _FaceScanSheet({
    required this.api,
    required this.workLocation,
    required this.branchName,
    required this.initialMode,
    required this.onSubmit,
  });

  @override
  State<_FaceScanSheet> createState() => _FaceScanSheetState();
}

class _FaceScanSheetState extends State<_FaceScanSheet> {
  CameraController? cameraController;
  FaceDetector? faceDetector;
  CameraDescription? selectedCamera;
  Size? latestFrameSize;
  bool cameraReady = false;
  bool verifying = false;
  bool submitting = false;
  bool facePresencePassed = false;
  bool singleFacePassed = false;
  bool faceSizePassed = false;
  bool faceAnglePassed = false;
  bool faceFramingPassed = false;
  bool locationCaptured = false;
  bool qrCaptured = false;
  bool verificationReady = false;
  bool faceVerificationBypassed = false;
  int faceAttemptCount = 0;
  DateTime? verifiedAt;
  DateTime? qrCapturedAt;
  int detectedFaceCount = 0;
  double? detectedFaceBoxWidth;
  double? detectedFaceBoxHeight;
  double? detectedFaceYaw;
  double? detectedFaceRoll;
  double? detectedFacePitch;
  String faceBoxText = '-';
  String faceAngleText = '-';
  String faceFramingText = '-';
  String qrCheckpointText = '-';
  String gpsAddressText = 'Location not captured';
  String gpsCoordinatesText = '-';
  String gpsAccuracyText = '-';
  String distanceStatusText = 'Calculated after submission';
  _CapturedAttendanceLocation? capturedLocation;
  Uint8List? capturedFaceBytes;
  Uint8List? capturedStillPreviewBytes;
  String? selectedMode;
  String statusText = 'Initialising camera...';
  String? errorText;
  String? lastCameraFrameInfo;

  // Raw ML Kit detector options.
  static const FaceDetectorMode _mlKitPerformanceMode = FaceDetectorMode.accurate;
  static const bool _mlKitEnableClassification = false;
  static const bool _mlKitEnableLandmarks = false;
  static const bool _mlKitEnableContours = false;
  static const double _mlKitMinFaceSize = 0.02;

  // User-friendly face verification tolerance.
  static const double _minimumFaceAbsolutePx = 64.0;
  static const double _minimumFaceShortSideFactor = 0.12;
  static const double _frameEdgeMarginFactor = 0.010;
  static const double _roiBoundaryToleranceFactor = 0.12;
  static const double _portraitGuideWidthFactor = 0.78;
  static const double _portraitGuideHeightFactor = 0.92;
  static const double _landscapeGuideWidthFactor = 0.62;
  static const double _landscapeGuideHeightFactor = 0.88;
  static const double _advisoryHeadYaw = 50.0;
  static const double _advisoryHeadRoll = 50.0;
  static const double _advisoryHeadPitch = 50.0;

  @override
  void initState() {
    super.initState();
    selectedMode = widget.initialMode;
    initialiseFaceDetector();
  }

  @override
  void dispose() {
    cameraController?.dispose();
    faceDetector?.close();
    super.dispose();
  }

  Future<void> initialiseFaceDetector() async {
    AppDiagnostics.instance.setMlKitSettings(_rawJson(_mlKitSettingsRaw('FaceDetectorOptions.initialise')));
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: _mlKitPerformanceMode,
        enableClassification: _mlKitEnableClassification,
        enableLandmarks: _mlKitEnableLandmarks,
        enableContours: _mlKitEnableContours,
        minFaceSize: _mlKitMinFaceSize,
      ),
    );

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found on this device.');
      }

      selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      cameraController = controller;
      await controller.initialize();
      var zoomText = 'default';
      try {
        final minZoom = await controller.getMinZoomLevel();
        await controller.setZoomLevel(minZoom);
        zoomText = minZoom.toStringAsFixed(2);
      } catch (error) {
        AppDiagnostics.instance.log(_rawJson({'source': 'CameraController.getMinZoomLevel/setZoomLevel', 'error': _errorRaw(error)}));
      }
      final previewSize = controller.value.previewSize;
      final previewText = previewSize == null
          ? 'unknown'
          : '${previewSize.width.round()}x${previewSize.height.round()}';
      AppDiagnostics.instance.setDeviceInfo(_rawJson({
        'source': 'dart:io.Platform',
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'defaultTargetPlatform': defaultTargetPlatform.name,
      }));
      AppDiagnostics.instance.setCameraInfo(_rawJson({
        'source': 'camera.availableCameras.CameraController.initialize.response',
        'availableCameras.length': cameras.length,
        'availableCameras': _camerasRaw(cameras),
        'selectedCamera.name': selectedCamera!.name,
        'selectedCamera.lensDirection': selectedCamera!.lensDirection.name,
        'selectedCamera.sensorOrientation': selectedCamera!.sensorOrientation,
        'resolutionPreset': 'medium',
        'zoomLevel': zoomText,
        'controller.value.isInitialized': controller.value.isInitialized,
        'controller.value.previewSize': previewText,
      }));

      if (!mounted) return;
      setState(() {
        cameraReady = true;
        statusText = 'Select action, then capture face';
        errorText = null;
      });
    } on CameraException catch (error) {
      final rawError = _rawJson({'source': 'CameraController.initialize.catch', 'error': _errorRaw(error)});
      AppDiagnostics.instance.log(rawError);
      AppDiagnostics.instance.setCameraInfo(rawError);
      if (!mounted) return;
      setState(() {
        cameraReady = false;
        statusText = 'Camera unavailable';
        errorText = rawError;
      });
    } catch (error) {
      final rawError = _rawJson({'source': 'initialiseFaceDetector.catch', 'error': _errorRaw(error)});
      AppDiagnostics.instance.log(rawError);
      AppDiagnostics.instance.setCameraInfo(rawError);
      if (!mounted) return;
      setState(() {
        cameraReady = false;
        statusText = 'Camera unavailable';
        errorText = rawError;
      });
    }
  }

  void resetFaceChecks() {
    facePresencePassed = false;
    singleFacePassed = false;
    faceSizePassed = false;
    faceAnglePassed = false;
    faceFramingPassed = false;
    locationCaptured = false;
    verificationReady = false;
    faceVerificationBypassed = false;
    verifiedAt = null;
    detectedFaceCount = 0;
    detectedFaceBoxWidth = null;
    detectedFaceBoxHeight = null;
    detectedFaceYaw = null;
    detectedFaceRoll = null;
    detectedFacePitch = null;
    faceBoxText = '-';
    faceAngleText = '-';
    faceFramingText = '-';
    gpsAddressText = 'Location not captured';
    gpsCoordinatesText = '-';
    gpsAccuracyText = '-';
    distanceStatusText = 'Calculated after submission';
    capturedLocation = null;
    capturedFaceBytes = null;
    capturedStillPreviewBytes = null;
  }

  Future<void> verifyFacePresence() async {
    final controller = cameraController;
    final detector = faceDetector;
    if (controller == null || detector == null || !controller.value.isInitialized) {
      AppFeedback.warning();
      setState(() {
        statusText = 'Camera not ready';
        errorText = 'Wait for camera initialisation, then try again.';
      });
      return;
    }

    if (verifying || submitting) return;
    if (faceAttemptCount >= 3 && faceVerificationBypassed) {
      AppFeedback.warning();
      setState(() {
        statusText = 'Face verification already completed';
        errorText = 'Three attempts were unsuccessful. Attendance may continue and will be flagged in the audit.';
      });
      return;
    }

    AppFeedback.tap();
    setState(() {
      verifying = true;
      resetFaceChecks();
      faceAttemptCount += 1;
      statusText = 'Capturing camera photo · attempt $faceAttemptCount of 3...';
      errorText = null;
    });

    try {
      final scanResult = await _captureStillFaceScan(controller, detector);
      if (!mounted) return;

      final faces = scanResult.faces;
      detectedFaceCount = faces.length;
      if (faces.isEmpty) {
        await _recordFaceAttemptFailure(
          userMessage: 'No face was detected.',
          diagnosticMessage: scanResult.rawResponse,
          photoBytes: scanResult.photoBytes,
        );
        return;
      }

      setState(() => facePresencePassed = true);

      if (faces.length > 1) {
        await _recordFaceAttemptFailure(
          userMessage: 'More than one face was detected.',
          diagnosticMessage: scanResult.rawResponse,
          photoBytes: scanResult.photoBytes,
        );
        return;
      }

      setState(() => singleFacePassed = true);

      final face = faces.first;
      final faceWidth = face.boundingBox.width.abs();
      final faceHeight = face.boundingBox.height.abs();
      final frameShortSide = math.min(scanResult.frameSize.width, scanResult.frameSize.height);
      final minimumFaceSide = math.max(_minimumFaceAbsolutePx, frameShortSide * _minimumFaceShortSideFactor);
      final faceRatio = faceWidth / math.max(faceHeight, 1.0);
      final headYaw = (face.headEulerAngleY ?? 0).abs();
      final headRoll = (face.headEulerAngleZ ?? 0).abs();
      final headPitch = (face.headEulerAngleX ?? 0).abs();

      setState(() {
        detectedFaceCount = 1;
        detectedFaceBoxWidth = faceWidth;
        detectedFaceBoxHeight = faceHeight;
        detectedFaceYaw = headYaw;
        detectedFaceRoll = headRoll;
        detectedFacePitch = headPitch;
        faceBoxText = '${faceWidth.round()} × ${faceHeight.round()} px';
        faceAngleText = 'Yaw ${headYaw.toStringAsFixed(0)}°, roll ${headRoll.toStringAsFixed(0)}°, pitch ${headPitch.toStringAsFixed(0)}°';
      });

      if (faceWidth < minimumFaceSide || faceHeight < minimumFaceSide) {
        final raw = _rawJson({
          'source': 'EastApp.faceSizeValidation.response',
          'accepted': false,
          'reason': 'face_box_smaller_than_minimum_side',
          'face.boundingBox.width': faceWidth,
          'face.boundingBox.height': faceHeight,
          'faceRatio': faceRatio,
          'accepted.minimumFaceSide': minimumFaceSide,
          'accepted.rule': 'minimum_side_only',
        });
        await _recordFaceAttemptFailure(
          userMessage: 'Move closer so the face is clearer.',
          diagnosticMessage: raw,
          photoBytes: scanResult.photoBytes,
        );
        return;
      }

      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.faceSizeValidation.response',
        'accepted': true,
        'reason': 'face_box_meets_minimum_side',
        'face.boundingBox.width': faceWidth,
        'face.boundingBox.height': faceHeight,
        'faceRatio': faceRatio,
        'accepted.minimumFaceSide': minimumFaceSide,
        'accepted.rule': 'minimum_side_only',
        'removed.blockingRule': 'face_ratio_out_of_range',
      }));

      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.faceAngleValidation.response',
        'accepted': true,
        'reason': 'angle_is_advisory_only',
        'headEulerAngleY.abs.yaw': headYaw,
        'headEulerAngleZ.abs.roll': headRoll,
        'headEulerAngleX.abs.pitch': headPitch,
        'advisory.maxHeadYaw': _advisoryHeadYaw,
        'advisory.maxHeadRoll': _advisoryHeadRoll,
        'advisory.maxHeadPitch': _advisoryHeadPitch,
      }));

      var photoBytes = scanResult.photoBytes;
      final acceptedStillPreviewBytes = photoBytes;
      final faceThumbnailBytes = await _cropFaceThumbnailPng(photoBytes, face, scanResult.frameSize);
      if (faceThumbnailBytes != null) {
        photoBytes = faceThumbnailBytes;
      }

      setState(() {
        faceSizePassed = true;
        faceFramingPassed = true;
        faceAnglePassed = true;
        faceVerificationBypassed = false;
        faceFramingText = 'Visual guide only · face box accepted';
        capturedFaceBytes = photoBytes;
        capturedStillPreviewBytes = acceptedStillPreviewBytes;
        statusText = 'Face accepted. Capturing GPS location...';
      });

      await WidgetsBinding.instance.endOfFrame;
      final locationResult = await _captureAttendanceLocation();
      if (!mounted) return;

      final now = DateTime.now();
      setState(() {
        locationCaptured = true;
        verificationReady = true;
        verifiedAt = now;
        capturedLocation = locationResult;
        gpsAddressText = 'Resolved by the server after submission';
        gpsCoordinatesText = '${locationResult.latitude.toStringAsFixed(6)}, ${locationResult.longitude.toStringAsFixed(6)}';
        gpsAccuracyText = '±${locationResult.accuracyMeters} m';
        distanceStatusText = 'Calculated by the server from ${widget.workLocation.name}';
        verifying = false;
        statusText = 'Face and GPS captured. Capture QR, then submit.';
      });
      AppDiagnostics.instance.log(_rawJson({
        'source': 'EastApp.faceValidation',
        'accepted': true,
        'attempt': faceAttemptCount,
        'scanResult.source': scanResult.source,
        'faces.length': faces.length,
        'frame.width': scanResult.frameSize.width.round(),
        'frame.height': scanResult.frameSize.height.round(),
        'face.boundingBox.width': faceWidth.round(),
        'face.boundingBox.height': faceHeight.round(),
      }));
      AppFeedback.success();
    } on _LocationCaptureException catch (error) {
      if (!mounted) return;
      _failValidation(error.message);
    } on CameraException catch (error) {
      final rawError = _rawJson({'source': 'CameraController.takePicture.catch', 'error': _errorRaw(error)});
      AppDiagnostics.instance.log(rawError);
      if (!mounted) return;
      setState(() {
        verifying = false;
        faceAttemptCount = math.max(0, faceAttemptCount - 1);
        statusText = 'Camera capture failed';
        errorText = 'The camera could not capture a photo. Try again.';
      });
    } catch (error) {
      final rawError = _rawJson({'source': 'FaceDetector.processImage.catch', 'error': _errorRaw(error)});
      AppDiagnostics.instance.log(rawError);
      AppDiagnostics.instance.addFaceScanTrace(rawError);
      if (!mounted) return;
      await _recordFaceAttemptFailure(
        userMessage: 'Face detection could not complete on this device.',
        diagnosticMessage: rawError,
      );
    }
  }

  Future<void> _recordFaceAttemptFailure({
    required String userMessage,
    required String diagnosticMessage,
    Uint8List? photoBytes,
  }) async {
    AppFeedback.warning();
    final attemptedAt = DateTime.now();
    AppDiagnostics.instance.log(_rawJson({
      'source': 'EastApp.faceAttempt.failed',
      'attempt': faceAttemptCount,
      'maximumAttempts': 3,
      'willBypass': faceAttemptCount >= 3,
      'diagnostic': diagnosticMessage,
    }));

    if (!mounted) return;
    setState(() {
      capturedStillPreviewBytes = photoBytes;
      capturedFaceBytes = null;
      statusText = 'Face verification failed. Capturing GPS location...';
      errorText = userMessage;
    });

    _CapturedAttendanceLocation locationResult;
    try {
      locationResult = await _captureAttendanceLocation();
    } on _LocationCaptureException catch (error) {
      if (!mounted) return;
      setState(() {
        verifying = false;
        verificationReady = false;
        locationCaptured = false;
        statusText = 'Face verification and GPS capture failed';
        errorText = '$userMessage ${error.message}';
      });
      return;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        verifying = false;
        verificationReady = false;
        locationCaptured = false;
        statusText = 'Face verification failed · GPS timed out';
        errorText = '$userMessage GPS location could not be captured. Try again.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      locationCaptured = true;
      capturedLocation = locationResult;
      gpsAddressText = 'Resolved by the server for the failed attempt';
      gpsCoordinatesText = '${locationResult.latitude.toStringAsFixed(6)}, ${locationResult.longitude.toStringAsFixed(6)}';
      gpsAccuracyText = '±${locationResult.accuracyMeters} m';
      distanceStatusText = 'Calculated by the server from ${widget.workLocation.name}';
    });

    String? auditSaveError;
    try {
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final random = math.Random.secure().nextInt(0x7fffffff);
      await widget.api.createAttendanceFaceAttempt(
        clientAttemptId: 'face-attempt-$timestamp-$random',
        intendedEventType: selectedMode == 'Clock Out' ? 'CLOCK_OUT' : 'CLOCK_IN',
        deviceAttemptedAt: attemptedAt,
        latitude: locationResult.latitude,
        longitude: locationResult.longitude,
        accuracyMeters: locationResult.accuracyMeters.toDouble(),
        failureReason: userMessage,
        faceCount: detectedFaceCount,
        faceAttemptNumber: faceAttemptCount,
        faceBoxWidth: detectedFaceBoxWidth,
        faceBoxHeight: detectedFaceBoxHeight,
        faceYaw: detectedFaceYaw,
        faceRoll: detectedFaceRoll,
        facePitch: detectedFacePitch,
        devicePlatform: Platform.isIOS
            ? 'IOS'
            : Platform.isAndroid
                ? 'ANDROID'
                : Platform.operatingSystem.toUpperCase(),
        deviceOsVersion: Platform.operatingSystemVersion.replaceAll('\n', ' '),
        appVersion: 'east_app_v272',
        validationMethod: 'ML_KIT_FACE_DETECTION_FAILED',
        photoBytes: photoBytes,
      );
    } on EastAppApiException catch (error) {
      auditSaveError = error.message;
      AppDiagnostics.instance.log(_rawJson({
        'source': 'EastApp.faceAttempt.auditSave.failed',
        'attempt': faceAttemptCount,
        'error': error.technicalDetails,
      }));
    }

    if (!mounted) return;
    if (faceAttemptCount < 3) {
      setState(() {
        verifying = false;
        verificationReady = false;
        statusText = 'Face failed · GPS captured · attempt $faceAttemptCount of 3';
        errorText = auditSaveError == null
            ? '$userMessage Location was captured and recorded. Try again.'
            : '$userMessage Location was captured, but the failed-attempt audit could not be saved: $auditSaveError';
      });
      return;
    }

    final now = DateTime.now();
    setState(() {
      faceVerificationBypassed = true;
      locationCaptured = true;
      verificationReady = true;
      verifiedAt = now;
      capturedLocation = locationResult;
      verifying = false;
      statusText = 'Face bypassed after 3 attempts. GPS captured. Capture QR, then submit.';
      errorText = auditSaveError == null
          ? 'Face verification did not pass after three attempts. The failed attempt and location were recorded for audit.'
          : 'Face verification did not pass. GPS was captured, but the failed-attempt audit could not be saved: $auditSaveError';
    });
  }

  Future<_CapturedAttendanceLocation> _captureAttendanceLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw _LocationCaptureException('Location service is off. Turn on Location Services to continue Attendance.');
    }

    final permission = await Geolocator.checkPermission();
    AppDiagnostics.instance.log(_rawJson({
      'source': 'EastApp.locationCapture.permissionCheckOnly',
      'permission': permission.name,
      'requestPermission.insideVerificationSheet': false,
      'reason': 'permissions are requested only before opening Attendance Verification',
    }));

    if (permission == LocationPermission.denied) {
      throw _LocationCaptureException('Location permission was not granted before Attendance Verification opened. Close Attendance and tap Attendance again.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw _LocationCaptureException('Location permission is permanently denied. Open app settings and allow location access to continue Attendance.');
    }

    Position position;
    var locationSource = 'Geolocator.getCurrentPosition';
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } on TimeoutException catch (error) {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition == null) {
        AppDiagnostics.instance.log(_rawJson({
          'source': 'EastApp.locationCapture.timeout',
          'error.runtimeType': error.runtimeType.toString(),
          'timeout.seconds': 6,
          'fallback': 'Geolocator.getLastKnownPosition',
          'fallback.result': null,
        }));
        rethrow;
      }
      position = lastKnownPosition;
      locationSource = 'Geolocator.getLastKnownPosition.afterTimeout';
      AppDiagnostics.instance.log(_rawJson({
        'source': 'EastApp.locationCapture.fallback',
        'reason': 'current_position_timeout',
        'timeout.seconds': 6,
        'fallback': locationSource,
        'position.latitude': position.latitude,
        'position.longitude': position.longitude,
        'position.accuracy': position.accuracy,
      }));
    }

    AppDiagnostics.instance.log(_rawJson({
      'source': 'EastApp.locationCapture.response',
      'location.source': locationSource,
      'accuracy.requested': 'medium',
      'timeout.seconds': 6,
      'position.latitude': position.latitude,
      'position.longitude': position.longitude,
      'position.accuracy': position.accuracy,
    }));

    return _CapturedAttendanceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy.round(),
    );
  }

  Future<_FaceScanResult> _captureStillFaceScan(CameraController controller, FaceDetector detector) async {
    final tempFiles = <File>[];
    AppDiagnostics.instance.resetFaceScanTrace();
    final mlKitSettings = _mlKitSettingsRaw('FaceDetectorOptions.capture');
    AppDiagnostics.instance.setMlKitSettings(_rawJson(mlKitSettings));
    AppDiagnostics.instance.addFaceScanTrace(_rawJson(mlKitSettings));

    if (mounted) {
      setState(() => statusText = 'Capturing camera photo...');
    }

    final capture = await controller.takePicture();
    final tempFile = File(capture.path);
    tempFiles.add(tempFile);
    final photoBytes = await tempFile.readAsBytes();
    if (mounted) {
      setState(() => statusText = 'Processing captured photo...');
    }
    final frameSize = await _decodeImageSize(photoBytes);
    latestFrameSize = frameSize;
    lastCameraFrameInfo = 'still_capture_jpeg, size=${frameSize.width.round()}x${frameSize.height.round()}';
    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'CameraController.takePicture',
      'XFile.path': capture.path,
      'file.exists': await tempFile.exists(),
      'file.lengthBytes': photoBytes.length,
      'decodedImage.width': frameSize.width.round(),
      'decodedImage.height': frameSize.height.round(),
      'jpeg.exifOrientation': _jpegExifOrientation(photoBytes),
      'jpeg.exifOrientationLabel': _jpegExifOrientationLabel(_jpegExifOrientation(photoBytes)),
      'platform.operatingSystem': Platform.operatingSystem,
      'camera.name': selectedCamera?.name,
      'camera.lensDirection': selectedCamera?.lensDirection.name,
      'camera.sensorOrientation': selectedCamera?.sensorOrientation,
      'controller.value.previewSize.width': controller.value.previewSize?.width.round(),
      'controller.value.previewSize.height': controller.value.previewSize?.height.round(),
    }));

    final exifOrientation = _jpegExifOrientation(photoBytes);
    final exifOrientationLabel = _jpegExifOrientationLabel(exifOrientation);

    if (Platform.isAndroid) {
      final androidResult = await _tryAndroidStillPhotoBitmapCandidates(
        detector: detector,
        photoBytes: photoBytes,
        sourcePath: capture.path,
        exifOrientation: exifOrientation,
        exifOrientationLabel: exifOrientationLabel,
      );
      if (androidResult != null) {
        await _deleteCaptureTempFiles(tempFiles);
        return androidResult;
      }

      final rawResponse = _rawJson({
        'source': 'FaceDetector.processImage.response',
        'inputImage.constructor': 'InputImage.fromBitmap',
        'platform.operatingSystem': Platform.operatingSystem,
        'candidate.count': _androidStillPhotoBitmapCandidates.length,
        'faces.length': 0,
        'reason': 'android_still_photo_bitmap_candidates_no_face',
      });
      AppDiagnostics.instance.log(rawResponse);
      AppDiagnostics.instance.addFaceScanTrace(rawResponse);
      await _deleteCaptureTempFiles(tempFiles);
      return _FaceScanResult(
        faces: <Face>[],
        frameSize: frameSize,
        photoBytes: photoBytes,
        source: 'InputImage.fromBitmap.androidRgba.noFace',
        rawResponse: rawResponse,
      );
    }

    final inputImage = InputImage.fromFilePath(capture.path);
    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'FaceDetector.processImage.request',
      'inputImage.constructor': 'InputImage.fromFilePath',
      'inputImage.filePath': capture.path,
      'file.lengthBytes': photoBytes.length,
      'decodedImage.width': frameSize.width.round(),
      'decodedImage.height': frameSize.height.round(),
      'jpeg.exifOrientation': exifOrientation,
      'jpeg.exifOrientationLabel': exifOrientationLabel,
    }));
    final faces = await detector.processImage(inputImage);
    final responseRaw = _rawJson({
      'source': 'FaceDetector.processImage.response',
      'inputImage.constructor': 'InputImage.fromFilePath',
      'faces.length': faces.length,
      'faces': _facesRaw(faces),
    });
    AppDiagnostics.instance.log(responseRaw);
    AppDiagnostics.instance.addFaceScanTrace(responseRaw);

    if (faces.isNotEmpty || !Platform.isIOS || exifOrientation == null || exifOrientation == 1) {
      await _deleteCaptureTempFiles(tempFiles);
      return _FaceScanResult(
        faces: faces,
        frameSize: frameSize,
        photoBytes: photoBytes,
        source: 'InputImage.fromFilePath',
        rawResponse: responseRaw,
      );
    }

    final normalisedImage = await _writeExifOrientationNormalisedPng(
      photoBytes: photoBytes,
      exifOrientation: exifOrientation,
      sourcePath: capture.path,
    );
    if (normalisedImage == null) {
      await _deleteCaptureTempFiles(tempFiles);
      return _FaceScanResult(
        faces: faces,
        frameSize: frameSize,
        photoBytes: photoBytes,
        source: 'InputImage.fromFilePath',
        rawResponse: responseRaw,
      );
    }
    tempFiles.add(normalisedImage.file);

    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'FaceDetector.processImage.request',
      'inputImage.constructor': 'InputImage.fromFilePath',
      'inputImage.filePath': normalisedImage.file.path,
      'normalised.from': capture.path,
      'normalised.reason': 'ios_jpeg_exif_orientation',
      'normalised.format': 'png',
      'normalised.appliedExifOrientation': exifOrientation,
      'normalised.appliedExifOrientationLabel': exifOrientationLabel,
      'file.lengthBytes': normalisedImage.bytes.length,
      'decodedImage.width': normalisedImage.frameSize.width.round(),
      'decodedImage.height': normalisedImage.frameSize.height.round(),
    }));
    final normalisedFaces = await detector.processImage(InputImage.fromFilePath(normalisedImage.file.path));
    final normalisedResponseRaw = _rawJson({
      'source': 'FaceDetector.processImage.response',
      'inputImage.constructor': 'InputImage.fromFilePath',
      'inputImage.filePath': normalisedImage.file.path,
      'normalised.from': capture.path,
      'normalised.reason': 'ios_jpeg_exif_orientation',
      'normalised.appliedExifOrientation': exifOrientation,
      'normalised.appliedExifOrientationLabel': exifOrientationLabel,
      'faces.length': normalisedFaces.length,
      'faces': _facesRaw(normalisedFaces),
    });
    AppDiagnostics.instance.log(normalisedResponseRaw);
    AppDiagnostics.instance.addFaceScanTrace(normalisedResponseRaw);

    if (normalisedFaces.isNotEmpty) {
      await _deleteCaptureTempFiles(tempFiles);
      return _FaceScanResult(
        faces: normalisedFaces,
        frameSize: normalisedImage.frameSize,
        photoBytes: normalisedImage.bytes,
        source: 'InputImage.fromFilePath.normalisedPng',
        rawResponse: normalisedResponseRaw,
      );
    }

    final iosCandidateResult = await _tryIosStillPhotoOrientationCandidates(
      detector: detector,
      photoBytes: photoBytes,
      sourcePath: capture.path,
      tempFiles: tempFiles,
      exifOrientation: exifOrientation,
      exifOrientationLabel: exifOrientationLabel,
    );
    if (iosCandidateResult != null) {
      await _deleteCaptureTempFiles(tempFiles);
      return iosCandidateResult;
    }

    await _deleteCaptureTempFiles(tempFiles);
    return _FaceScanResult(
      faces: normalisedFaces,
      frameSize: normalisedImage.frameSize,
      photoBytes: normalisedImage.bytes,
      source: 'InputImage.fromFilePath.normalisedPng',
      rawResponse: normalisedResponseRaw,
    );
  }


  static const List<_StillPhotoByteCandidate> _androidStillPhotoBitmapCandidates = <_StillPhotoByteCandidate>[
    _StillPhotoByteCandidate(rotationQuarterTurns: 0, mirror: false),
    _StillPhotoByteCandidate(rotationQuarterTurns: 0, mirror: true),
    _StillPhotoByteCandidate(rotationQuarterTurns: 1, mirror: false),
    _StillPhotoByteCandidate(rotationQuarterTurns: 3, mirror: false),
    _StillPhotoByteCandidate(rotationQuarterTurns: 2, mirror: false),
    _StillPhotoByteCandidate(rotationQuarterTurns: 1, mirror: true),
    _StillPhotoByteCandidate(rotationQuarterTurns: 3, mirror: true),
    _StillPhotoByteCandidate(rotationQuarterTurns: 2, mirror: true),
  ];

  Future<_FaceScanResult?> _tryAndroidStillPhotoBitmapCandidates({
    required FaceDetector detector,
    required Uint8List photoBytes,
    required String sourcePath,
    required int? exifOrientation,
    required String? exifOrientationLabel,
  }) async {
    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'EastApp.androidStillPhotoBitmapFallback.start',
      'reason': 'Use InputImage.fromBitmap to bypass Android InputImage.fromBytes NV21 converter crashes',
      'input.constructor.removed': 'InputImage.fromBytes',
      'input.constructor.active': 'InputImage.fromBitmap',
      'candidate.count': _androidStillPhotoBitmapCandidates.length,
      'source.filePath': sourcePath,
      'source.bytes.length': photoBytes.length,
      'source.jpeg.exifOrientation': exifOrientation,
      'source.jpeg.exifOrientationLabel': exifOrientationLabel,
    }));

    String? lastResponseRaw;
    for (final candidate in _androidStillPhotoBitmapCandidates) {
      final bitmapImage = await _buildMlKitBitmapImage(
        photoBytes: photoBytes,
        candidate: candidate,
        sourcePath: sourcePath,
        exifOrientation: exifOrientation,
        exifOrientationLabel: exifOrientationLabel,
      );

      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'FaceDetector.processImage.request',
        'inputImage.constructor': 'InputImage.fromBitmap',
        'inputImage.bitmap.format': 'rawRgba',
        'inputImage.bitmap.rotation': 0,
        'inputImage.bitmap.width': bitmapImage.width,
        'inputImage.bitmap.height': bitmapImage.height,
        'candidate.reason': 'android_still_photo_bitmap_candidate',
        'candidate.label': candidate.label,
        'candidate.rotationQuarterTurns': candidate.normalisedQuarterTurns,
        'candidate.rotationDegrees': candidate.normalisedQuarterTurns * 90,
        'candidate.mirror': candidate.mirror,
        'source.filePath': sourcePath,
        'source.jpeg.exifOrientation': exifOrientation,
        'source.jpeg.exifOrientationLabel': exifOrientationLabel,
        'rgba.bytes.length': bitmapImage.rgbaBytes.length,
        'png.bytes.length': bitmapImage.pngBytes.length,
        'decodedImage.width': bitmapImage.width,
        'decodedImage.height': bitmapImage.height,
      }));

      final inputImage = InputImage.fromBitmap(
        bitmap: bitmapImage.rgbaBytes,
        width: bitmapImage.width,
        height: bitmapImage.height,
        rotation: 0,
      );
      final faces = await detector.processImage(inputImage);
      final responseRaw = _rawJson({
        'source': 'FaceDetector.processImage.response',
        'inputImage.constructor': 'InputImage.fromBitmap',
        'inputImage.bitmap.format': 'rawRgba',
        'inputImage.bitmap.rotation': 0,
        'candidate.reason': 'android_still_photo_bitmap_candidate',
        'candidate.label': candidate.label,
        'candidate.rotationQuarterTurns': candidate.normalisedQuarterTurns,
        'candidate.rotationDegrees': candidate.normalisedQuarterTurns * 90,
        'candidate.mirror': candidate.mirror,
        'source.filePath': sourcePath,
        'source.jpeg.exifOrientation': exifOrientation,
        'source.jpeg.exifOrientationLabel': exifOrientationLabel,
        'faces.length': faces.length,
        'faces': _facesRaw(faces),
      });
      lastResponseRaw = responseRaw;
      AppDiagnostics.instance.log(responseRaw);
      AppDiagnostics.instance.addFaceScanTrace(responseRaw);

      if (faces.isNotEmpty) {
        latestFrameSize = bitmapImage.frameSize;
        lastCameraFrameInfo = 'android_still_photo_bitmap, candidate=${candidate.label}, size=${bitmapImage.width}x${bitmapImage.height}';
        return _FaceScanResult(
          faces: faces,
          frameSize: bitmapImage.frameSize,
          photoBytes: bitmapImage.pngBytes,
          source: 'InputImage.fromBitmap.androidRgba.${candidate.label}',
          rawResponse: responseRaw,
        );
      }
    }

    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'EastApp.androidStillPhotoBitmapFallback.end',
      'candidate.count': _androidStillPhotoBitmapCandidates.length,
      'faces.length': 0,
      'lastResponse': lastResponseRaw,
    }));
    return null;
  }

  Future<_MlKitBitmapImage> _buildMlKitBitmapImage({
    required Uint8List photoBytes,
    required _StillPhotoByteCandidate candidate,
    required String sourcePath,
    required int? exifOrientation,
    required String? exifOrientationLabel,
  }) async {
    ui.Codec? codec;
    ui.Image? sourceImage;
    ui.Image? outputImage;
    ui.Picture? picture;
    codec = await ui.instantiateImageCodec(photoBytes);
    final frame = await codec.getNextFrame();
    sourceImage = frame.image;

    final sourceWidth = sourceImage.width.toDouble();
    final sourceHeight = sourceImage.height.toDouble();
    final quarterTurns = candidate.normalisedQuarterTurns;
    final swapsAxis = quarterTurns.isOdd;
    final outputWidth = swapsAxis ? sourceHeight : sourceWidth;
    final outputHeight = swapsAxis ? sourceWidth : sourceHeight;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outputWidth, outputHeight));
      canvas.translate(outputWidth / 2, outputHeight / 2);
      canvas.rotate(quarterTurns * math.pi / 2);
      if (candidate.mirror) {
        canvas.scale(-1, 1);
      }
      canvas.drawImageRect(
        sourceImage,
        Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
        Rect.fromCenter(center: Offset.zero, width: sourceWidth, height: sourceHeight),
        Paint()..filterQuality = FilterQuality.high,
      );
      picture = recorder.endRecording();
      outputImage = await picture.toImage(outputWidth.round(), outputHeight.round());
      final pngByteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      final rawByteData = await outputImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pngBytes = pngByteData!.buffer.asUint8List();
      final rgbaBytes = rawByteData!.buffer.asUint8List();
      final width = outputImage.width;
      final height = outputImage.height;

      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.androidStillPhotoBitmapCandidate.response',
        'input.filePath': sourcePath,
        'input.bytes.length': photoBytes.length,
        'input.decodedImage.width': sourceImage.width,
        'input.decodedImage.height': sourceImage.height,
        'source.jpeg.exifOrientation': exifOrientation,
        'source.jpeg.exifOrientationLabel': exifOrientationLabel,
        'candidate.label': candidate.label,
        'candidate.rotationQuarterTurns': quarterTurns,
        'candidate.rotationDegrees': quarterTurns * 90,
        'candidate.mirror': candidate.mirror,
        'output.format': 'rawRgba',
        'output.width': width,
        'output.height': height,
        'output.bytes.length': rgbaBytes.length,
        'previewPng.bytes.length': pngBytes.length,
      }));

      return _MlKitBitmapImage(
        rgbaBytes: rgbaBytes,
        pngBytes: pngBytes,
        frameSize: Size(width.toDouble(), height.toDouble()),
        width: width,
        height: height,
        candidate: candidate,
      );
    } finally {
      outputImage?.dispose();
      picture?.dispose();
      sourceImage?.dispose();
      codec?.dispose();
    }
  }

  Future<void> _deleteCaptureTempFiles(List<File> tempFiles) async {
    for (final file in tempFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }



  Future<_NormalisedImageFile?> _writeExifOrientationNormalisedPng({
    required Uint8List photoBytes,
    required int exifOrientation,
    required String sourcePath,
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    ui.Image? outputImage;
    try {
      codec = await ui.instantiateImageCodec(photoBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;

      final outputWidth = image.width;
      final outputHeight = image.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImage(image, Offset.zero, paint);
      final picture = recorder.endRecording();
      outputImage = await picture.toImage(outputWidth, outputHeight);
      picture.dispose();

      final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null || pngBytes.isEmpty) {
        AppDiagnostics.instance.addFaceScanTrace(_rawJson({
          'source': 'EastApp.exifOrientationNormalisedPng.response',
          'output.bytes.length': pngBytes?.length,
        }));
        return null;
      }

      final normalisedPath = '${File(sourcePath).parent.path}/mlkit_orientation_up_${DateTime.now().microsecondsSinceEpoch}.png';
      final normalisedFile = File(normalisedPath);
      await normalisedFile.writeAsBytes(pngBytes, flush: true);
      final frameSize = Size(outputWidth.toDouble(), outputHeight.toDouble());

      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.exifOrientationNormalisedPng.response',
        'input.filePath': sourcePath,
        'input.bytes.length': photoBytes.length,
        'input.decodedImage.width': image.width,
        'input.decodedImage.height': image.height,
        'jpeg.exifOrientation': exifOrientation,
        'jpeg.exifOrientationLabel': _jpegExifOrientationLabel(exifOrientation),
        'normalisation.method': 'decode_to_png_without_exif_orientation',
        'output.filePath': normalisedPath,
        'output.format': 'png',
        'output.width': outputWidth,
        'output.height': outputHeight,
        'output.bytes.length': pngBytes.length,
      }));

      return _NormalisedImageFile(
        file: normalisedFile,
        bytes: pngBytes,
        frameSize: frameSize,
      );
    } catch (error) {
      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.exifOrientationNormalisedPng.catch',
        'jpeg.exifOrientation': exifOrientation,
        'jpeg.exifOrientationLabel': _jpegExifOrientationLabel(exifOrientation),
        'error': _errorRaw(error),
      }));
      return null;
    } finally {
      outputImage?.dispose();
      image?.dispose();
    }
  }


  Future<_FaceScanResult?> _tryIosStillPhotoOrientationCandidates({
    required FaceDetector detector,
    required Uint8List photoBytes,
    required String sourcePath,
    required List<File> tempFiles,
    required int exifOrientation,
    required String? exifOrientationLabel,
  }) async {
    final candidates = <_IosStillPhotoCandidate>[
      const _IosStillPhotoCandidate(rotationQuarterTurns: 1, mirror: false),
      const _IosStillPhotoCandidate(rotationQuarterTurns: 3, mirror: false),
      const _IosStillPhotoCandidate(rotationQuarterTurns: 2, mirror: false),
      const _IosStillPhotoCandidate(rotationQuarterTurns: 0, mirror: true),
      const _IosStillPhotoCandidate(rotationQuarterTurns: 1, mirror: true),
      const _IosStillPhotoCandidate(rotationQuarterTurns: 3, mirror: true),
      const _IosStillPhotoCandidate(rotationQuarterTurns: 2, mirror: true),
    ];

    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'EastApp.iOSOrientationCandidateFallback.start',
      'reason': 'iOS InputImage.fromFilePath returned faces.length 0 after original JPEG and orientation-up PNG',
      'candidate.count': candidates.length,
      'source.filePath': sourcePath,
      'source.bytes.length': photoBytes.length,
      'source.jpeg.exifOrientation': exifOrientation,
      'source.jpeg.exifOrientationLabel': exifOrientationLabel,
    }));

    String? lastResponseRaw;
    for (final candidate in candidates) {
      try {
        final candidateBytes = await _buildIosOrientationCandidatePng(
          photoBytes: photoBytes,
          candidate: candidate,
          sourcePath: sourcePath,
          exifOrientation: exifOrientation,
          exifOrientationLabel: exifOrientationLabel,
        );
        if (candidateBytes == null || candidateBytes.isEmpty) {
          continue;
        }

        final candidateFile = File(
          '${File(sourcePath).parent.path}/mlkit_ios_candidate_${DateTime.now().microsecondsSinceEpoch}_${candidate.fileSuffix}.png',
        );
        await candidateFile.writeAsBytes(candidateBytes, flush: true);
        tempFiles.add(candidateFile);
        final candidateFrameSize = await _decodeImageSize(candidateBytes);

        AppDiagnostics.instance.addFaceScanTrace(_rawJson({
          'source': 'FaceDetector.processImage.request',
          'inputImage.constructor': 'InputImage.fromFilePath',
          'inputImage.filePath': candidateFile.path,
          'candidate.reason': 'ios_orientation_candidate',
          'candidate.rotationQuarterTurns': candidate.normalisedQuarterTurns,
          'candidate.rotationDegrees': candidate.normalisedQuarterTurns * 90,
          'candidate.mirror': candidate.mirror,
          'source.filePath': sourcePath,
          'source.jpeg.exifOrientation': exifOrientation,
          'source.jpeg.exifOrientationLabel': exifOrientationLabel,
          'file.lengthBytes': candidateBytes.length,
          'decodedImage.width': candidateFrameSize.width.round(),
          'decodedImage.height': candidateFrameSize.height.round(),
        }));

        final faces = await detector.processImage(InputImage.fromFilePath(candidateFile.path));
        final responseRaw = _rawJson({
          'source': 'FaceDetector.processImage.response',
          'inputImage.constructor': 'InputImage.fromFilePath',
          'inputImage.filePath': candidateFile.path,
          'candidate.reason': 'ios_orientation_candidate',
          'candidate.rotationQuarterTurns': candidate.normalisedQuarterTurns,
          'candidate.rotationDegrees': candidate.normalisedQuarterTurns * 90,
          'candidate.mirror': candidate.mirror,
          'source.filePath': sourcePath,
          'source.jpeg.exifOrientation': exifOrientation,
          'source.jpeg.exifOrientationLabel': exifOrientationLabel,
          'faces.length': faces.length,
          'faces': _facesRaw(faces),
        });
        lastResponseRaw = responseRaw;
        AppDiagnostics.instance.log(responseRaw);
        AppDiagnostics.instance.addFaceScanTrace(responseRaw);

        if (faces.isNotEmpty) {
          latestFrameSize = candidateFrameSize;
          lastCameraFrameInfo = 'ios_orientation_candidate, rotationQuarterTurns=${candidate.normalisedQuarterTurns}, mirror=${candidate.mirror}, size=${candidateFrameSize.width.round()}x${candidateFrameSize.height.round()}';
          return _FaceScanResult(
            faces: faces,
            frameSize: candidateFrameSize,
            photoBytes: candidateBytes,
            source: 'InputImage.fromFilePath.iOSOrientationCandidate',
            rawResponse: responseRaw,
          );
        }
      } catch (error) {
        final errorRaw = _rawJson({
          'source': 'EastApp.iOSOrientationCandidateFallback.catch',
          'candidate.rotationQuarterTurns': candidate.normalisedQuarterTurns,
          'candidate.rotationDegrees': candidate.normalisedQuarterTurns * 90,
          'candidate.mirror': candidate.mirror,
          'error': _errorRaw(error),
        });
        AppDiagnostics.instance.log(errorRaw);
        AppDiagnostics.instance.addFaceScanTrace(errorRaw);
        lastResponseRaw = errorRaw;
      }
    }

    AppDiagnostics.instance.addFaceScanTrace(_rawJson({
      'source': 'EastApp.iOSOrientationCandidateFallback.end',
      'candidate.count': candidates.length,
      'faces.length': 0,
      'lastResponse': lastResponseRaw,
    }));
    return null;
  }

  Future<Uint8List?> _buildIosOrientationCandidatePng({
    required Uint8List photoBytes,
    required _IosStillPhotoCandidate candidate,
    required String sourcePath,
    required int exifOrientation,
    required String? exifOrientationLabel,
  }) async {
    ui.Codec? codec;
    ui.Image? sourceImage;
    ui.Image? outputImage;
    ui.Picture? picture;
    try {
      codec = await ui.instantiateImageCodec(photoBytes);
      final frame = await codec.getNextFrame();
      sourceImage = frame.image;

      final sourceWidth = sourceImage.width.toDouble();
      final sourceHeight = sourceImage.height.toDouble();
      final quarterTurns = candidate.normalisedQuarterTurns;
      final swapsAxis = quarterTurns.isOdd;
      final outputWidth = swapsAxis ? sourceHeight : sourceWidth;
      final outputHeight = swapsAxis ? sourceWidth : sourceHeight;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outputWidth, outputHeight));
      canvas.translate(outputWidth / 2, outputHeight / 2);
      canvas.rotate(quarterTurns * math.pi / 2);
      if (candidate.mirror) {
        canvas.scale(-1, 1);
      }
      canvas.drawImageRect(
        sourceImage,
        Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
        Rect.fromCenter(center: Offset.zero, width: sourceWidth, height: sourceHeight),
        Paint()..filterQuality = FilterQuality.high,
      );

      picture = recorder.endRecording();
      outputImage = await picture.toImage(outputWidth.round(), outputHeight.round());
      final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.iOSOrientationCandidatePng.response',
        'input.filePath': sourcePath,
        'input.bytes.length': photoBytes.length,
        'input.decodedImage.width': sourceImage.width,
        'input.decodedImage.height': sourceImage.height,
        'source.jpeg.exifOrientation': exifOrientation,
        'source.jpeg.exifOrientationLabel': exifOrientationLabel,
        'candidate.rotationQuarterTurns': quarterTurns,
        'candidate.rotationDegrees': quarterTurns * 90,
        'candidate.mirror': candidate.mirror,
        'output.format': 'png',
        'output.width': outputWidth.round(),
        'output.height': outputHeight.round(),
        'output.bytes.length': pngBytes?.length,
      }));
      return pngBytes;
    } catch (error) {
      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.iOSOrientationCandidatePng.catch',
        'source.filePath': sourcePath,
        'source.jpeg.exifOrientation': exifOrientation,
        'source.jpeg.exifOrientationLabel': exifOrientationLabel,
        'candidate.rotationQuarterTurns': candidate.normalisedQuarterTurns,
        'candidate.rotationDegrees': candidate.normalisedQuarterTurns * 90,
        'candidate.mirror': candidate.mirror,
        'error': _errorRaw(error),
      }));
      return null;
    } finally {
      outputImage?.dispose();
      picture?.dispose();
      sourceImage?.dispose();
    }
  }

  Future<Uint8List?> _cropFaceThumbnailPng(Uint8List? photoBytes, Face face, Size frameSize) async {
    if (photoBytes == null || photoBytes.isEmpty || frameSize.width <= 0 || frameSize.height <= 0) {
      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.faceThumbnailCrop.skipped',
        'reason': 'photoBytes null/empty or frameSize invalid',
        'photoBytes.length': photoBytes?.length,
        'frame.width': frameSize.width.round(),
        'frame.height': frameSize.height.round(),
      }));
      return null;
    }

    ui.Codec? codec;
    ui.Image? image;
    ui.Image? outputImage;
    try {
      codec = await ui.instantiateImageCodec(photoBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;

      final scaleX = image.width / frameSize.width;
      final scaleY = image.height / frameSize.height;
      final faceBox = face.boundingBox;
      var sourceRect = Rect.fromLTRB(
        faceBox.left * scaleX,
        faceBox.top * scaleY,
        faceBox.right * scaleX,
        faceBox.bottom * scaleY,
      );

      final expandX = sourceRect.width * 0.35;
      final expandTop = sourceRect.height * 0.55;
      final expandBottom = sourceRect.height * 0.35;
      sourceRect = Rect.fromLTRB(
        sourceRect.left - expandX,
        sourceRect.top - expandTop,
        sourceRect.right + expandX,
        sourceRect.bottom + expandBottom,
      );

      final imageBounds = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final side = math.min(
        math.max(sourceRect.width, sourceRect.height),
        math.min(imageBounds.width, imageBounds.height),
      );
      final centre = sourceRect.center;
      sourceRect = Rect.fromCenter(center: centre, width: side, height: side);
      sourceRect = Rect.fromLTRB(
        sourceRect.left.clamp(imageBounds.left, imageBounds.right - side).toDouble(),
        sourceRect.top.clamp(imageBounds.top, imageBounds.bottom - side).toDouble(),
        sourceRect.left.clamp(imageBounds.left, imageBounds.right - side).toDouble() + side,
        sourceRect.top.clamp(imageBounds.top, imageBounds.bottom - side).toDouble() + side,
      );

      const outputSize = 512;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        image,
        sourceRect,
        Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
        paint,
      );
      final picture = recorder.endRecording();
      outputImage = await picture.toImage(outputSize, outputSize);
      picture.dispose();
      final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      final result = byteData?.buffer.asUint8List();

      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.faceThumbnailCrop.response',
        'input.photoBytes.length': photoBytes.length,
        'input.image.width': image.width,
        'input.image.height': image.height,
        'input.frame.width': frameSize.width.round(),
        'input.frame.height': frameSize.height.round(),
        'input.face.boundingBox.left': faceBox.left,
        'input.face.boundingBox.top': faceBox.top,
        'input.face.boundingBox.right': faceBox.right,
        'input.face.boundingBox.bottom': faceBox.bottom,
        'crop.sourceRect.left': sourceRect.left,
        'crop.sourceRect.top': sourceRect.top,
        'crop.sourceRect.right': sourceRect.right,
        'crop.sourceRect.bottom': sourceRect.bottom,
        'output.format': 'png',
        'output.width': outputSize,
        'output.height': outputSize,
        'output.bytes.length': result?.length,
      }));

      return result;
    } catch (error) {
      AppDiagnostics.instance.addFaceScanTrace(_rawJson({
        'source': 'EastApp.faceThumbnailCrop.catch',
        'error': _errorRaw(error),
      }));
      return null;
    } finally {
      outputImage?.dispose();
      image?.dispose();
    }
  }

  int? _jpegExifOrientation(Uint8List bytes) {
    try {
      if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
      var offset = 2;
      while (offset + 4 <= bytes.length) {
        if (bytes[offset] != 0xFF) return null;
        final marker = bytes[offset + 1];
        offset += 2;
        if (marker == 0xD9 || marker == 0xDA) return null;
        if (offset + 2 > bytes.length) return null;
        final segmentLength = (bytes[offset] << 8) + bytes[offset + 1];
        if (segmentLength < 2 || offset + segmentLength > bytes.length) return null;
        final segmentStart = offset + 2;
        final segmentEnd = offset + segmentLength;
        if (marker == 0xE1 && segmentEnd - segmentStart >= 14) {
          final isExif = bytes[segmentStart] == 0x45 &&
              bytes[segmentStart + 1] == 0x78 &&
              bytes[segmentStart + 2] == 0x69 &&
              bytes[segmentStart + 3] == 0x66 &&
              bytes[segmentStart + 4] == 0x00 &&
              bytes[segmentStart + 5] == 0x00;
          if (!isExif) return null;
          final tiffStart = segmentStart + 6;
          final littleEndian = bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49;
          final bigEndian = bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D;
          if (!littleEndian && !bigEndian) return null;

          int readUint16(int index) {
            if (littleEndian) return bytes[index] | (bytes[index + 1] << 8);
            return (bytes[index] << 8) | bytes[index + 1];
          }

          int readUint32(int index) {
            if (littleEndian) {
              return bytes[index] |
                  (bytes[index + 1] << 8) |
                  (bytes[index + 2] << 16) |
                  (bytes[index + 3] << 24);
            }
            return (bytes[index] << 24) |
                (bytes[index + 1] << 16) |
                (bytes[index + 2] << 8) |
                bytes[index + 3];
          }

          final magic = readUint16(tiffStart + 2);
          if (magic != 42) return null;
          final ifd0Offset = readUint32(tiffStart + 4);
          final ifd0 = tiffStart + ifd0Offset;
          if (ifd0 < tiffStart || ifd0 + 2 > segmentEnd) return null;
          final entryCount = readUint16(ifd0);
          for (var i = 0; i < entryCount; i++) {
            final entry = ifd0 + 2 + (i * 12);
            if (entry + 12 > segmentEnd) return null;
            final tag = readUint16(entry);
            if (tag == 0x0112) {
              return readUint16(entry + 8);
            }
          }
          return null;
        }
        offset += segmentLength;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _jpegExifOrientationLabel(int? value) {
    switch (value) {
      case 1:
        return 'top-left';
      case 2:
        return 'top-right-mirrored';
      case 3:
        return 'bottom-right';
      case 4:
        return 'bottom-left-mirrored';
      case 5:
        return 'left-top-mirrored';
      case 6:
        return 'right-top';
      case 7:
        return 'right-bottom-mirrored';
      case 8:
        return 'left-bottom';
    }
    return null;
  }

  Future<Size> _decodeImageSize(Uint8List bytes) {
    final completer = Completer<Size>();
    ui.decodeImageFromList(bytes, (image) {
      completer.complete(Size(image.width.toDouble(), image.height.toDouble()));
      image.dispose();
    });
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => latestFrameSize ?? const Size(480, 640),
    );
  }

  String _rawJson(Map<String, Object?> value) => jsonEncode(value);

  List<Map<String, Object?>> _camerasRaw(List<CameraDescription> cameras) {
    return cameras.map((camera) {
      return <String, Object?>{
        'name': camera.name,
        'lensDirection': camera.lensDirection.name,
        'sensorOrientation': camera.sensorOrientation,
      };
    }).toList();
  }

  Map<String, Object?> _mlKitSettingsRaw(String source) {
    return <String, Object?>{
      'source': source,
      'package': 'google_mlkit_face_detection',
      'detector': 'FaceDetector',
      'options.performanceMode': _mlKitPerformanceMode.name,
      'options.enableClassification': _mlKitEnableClassification,
      'options.enableLandmarks': _mlKitEnableLandmarks,
      'options.enableContours': _mlKitEnableContours,
      'options.minFaceSize': _mlKitMinFaceSize,
      'input.constructor': Platform.isAndroid ? 'InputImage.fromBitmap' : 'InputImage.fromFilePath',
      'camera.capture': 'CameraController.takePicture',
      'camera.resolutionPreset': 'medium',
      'camera.enableAudio': false,
      'platform.operatingSystem': Platform.operatingSystem,
      'defaultTargetPlatform': defaultTargetPlatform.name,
    };
  }

  Map<String, Object?> _errorRaw(Object error) {
    if (error is PlatformException) {
      return <String, Object?>{
        'runtimeType': error.runtimeType.toString(),
        'code': error.code,
        'message': error.message,
        'details': error.details?.toString(),
      };
    }
    if (error is CameraException) {
      return <String, Object?>{
        'runtimeType': error.runtimeType.toString(),
        'code': error.code,
        'description': error.description,
      };
    }
    return <String, Object?>{
      'runtimeType': error.runtimeType.toString(),
      'toString': error.toString(),
    };
  }

  List<Map<String, Object?>> _facesRaw(List<Face> faces) {
    return faces.asMap().entries.map((entry) {
      final face = entry.value;
      return <String, Object?>{
        'index': entry.key,
        'boundingBox.left': face.boundingBox.left,
        'boundingBox.top': face.boundingBox.top,
        'boundingBox.right': face.boundingBox.right,
        'boundingBox.bottom': face.boundingBox.bottom,
        'boundingBox.width': face.boundingBox.width,
        'boundingBox.height': face.boundingBox.height,
        'headEulerAngleX': face.headEulerAngleX,
        'headEulerAngleY': face.headEulerAngleY,
        'headEulerAngleZ': face.headEulerAngleZ,
        'trackingId': face.trackingId,
        'smilingProbability': face.smilingProbability,
        'leftEyeOpenProbability': face.leftEyeOpenProbability,
        'rightEyeOpenProbability': face.rightEyeOpenProbability,
        'landmarks.length': face.landmarks.length,
        'contours.length': face.contours.length,
      };
    }).toList();
  }

  Map<String, Object?> _faceRaw(Face face) {
    return <String, Object?>{
      'boundingBox.left': face.boundingBox.left,
      'boundingBox.top': face.boundingBox.top,
      'boundingBox.right': face.boundingBox.right,
      'boundingBox.bottom': face.boundingBox.bottom,
      'boundingBox.width': face.boundingBox.width,
      'boundingBox.height': face.boundingBox.height,
      'headEulerAngleX': face.headEulerAngleX,
      'headEulerAngleY': face.headEulerAngleY,
      'headEulerAngleZ': face.headEulerAngleZ,
      'trackingId': face.trackingId,
      'smilingProbability': face.smilingProbability,
      'leftEyeOpenProbability': face.leftEyeOpenProbability,
      'rightEyeOpenProbability': face.rightEyeOpenProbability,
      'landmarks.length': face.landmarks.length,
      'contours.length': face.contours.length,
    };
  }

  Rect _headGuideRectForFrame(double frameWidth, double frameHeight) {
    final isPortraitFrame = frameHeight >= frameWidth;
    final guideWidth = frameWidth * (isPortraitFrame ? _portraitGuideWidthFactor : _landscapeGuideWidthFactor);
    final guideHeight = frameHeight * (isPortraitFrame ? _portraitGuideHeightFactor : _landscapeGuideHeightFactor);
    return Rect.fromCenter(
      center: Offset(frameWidth / 2, frameHeight / 2),
      width: guideWidth,
      height: guideHeight,
    );
  }

  void captureQrCheckpoint() {
    if (verifying || submitting) return;
    AppFeedback.tap();
    final now = DateTime.now();
    setState(() {
      qrCaptured = true;
      qrCapturedAt = now;
      qrCheckpointText = '${widget.branchName} checkpoint QR';
      statusText = verificationReady
          ? 'QR captured. Review result, then submit.'
          : 'QR captured. Capture face, then submit.';
      errorText = null;
    });
  }

  void _failValidation(String message) {
    AppFeedback.warning();
    setState(() {
      verifying = false;
      verificationReady = false;
      statusText = 'Verification failed';
      errorText = message;
    });
  }

  Future<void> submitVerification() async {
    if (selectedMode == null) {
      AppFeedback.warning();
      setState(() => errorText = 'Select Clock In or Clock Out first.');
      return;
    }
    if (!verificationReady) {
      AppFeedback.warning();
      setState(() => errorText = 'Capture face first.');
      return;
    }
    if (!qrCaptured) {
      AppFeedback.warning();
      setState(() => errorText = 'Capture QR first.');
      return;
    }
    final locationResult = capturedLocation;
    final capturedAt = verifiedAt;
    if (locationResult == null || capturedAt == null) {
      AppFeedback.warning();
      setState(() => errorText = 'Capture GPS location first.');
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: selectedMode == 'Clock In'
          ? 'Proceed with Clock In?'
          : 'Proceed with Clock Out?',
      details: faceVerificationBypassed
          ? 'Face verification failed after three attempts. This will create an attendance record using the captured camera, QR and GPS information, with the face result flagged for audit.'
          : 'This will create an attendance record using the captured face, QR and GPS information.',
    );
    if (!confirmed || !mounted) return;

    AppFeedback.tap();
    final submissionData = _AttendanceSubmissionData(
      deviceCapturedAt: capturedAt,
      faceValid: !faceVerificationBypassed && singleFacePassed && faceSizePassed,
      faceCount: detectedFaceCount,
      faceAttemptCount: faceAttemptCount,
      faceVerificationBypassed: faceVerificationBypassed,
      faceBoxWidth: detectedFaceBoxWidth,
      faceBoxHeight: detectedFaceBoxHeight,
      faceYaw: detectedFaceYaw,
      faceRoll: detectedFaceRoll,
      facePitch: detectedFacePitch,
      devicePlatform: Platform.isIOS
          ? 'IOS'
          : Platform.isAndroid
              ? 'ANDROID'
              : Platform.operatingSystem.toUpperCase(),
      deviceOsVersion: Platform.operatingSystemVersion.replaceAll('\n', ' '),
    );

    setState(() {
      submitting = true;
      errorText = null;
      capturedFaceBytes = null;
      capturedStillPreviewBytes = null;
      statusText = 'Submitting attendance...';
    });

    try {
      await widget.onSubmit(selectedMode!, locationResult, submissionData);
    } on EastAppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        statusText = 'Submission failed';
        errorText = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        statusText = 'Submission failed';
        errorText = error.toString();
      });
    }
  }

  String _formatVerificationTime(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute:$second';
  }

  String _deviceInfoText() {
    final deviceType = Platform.isIOS
        ? 'iPhone / iOS'
        : Platform.isAndroid
            ? 'Android phone'
            : Platform.operatingSystem;
    final osText = Platform.operatingSystemVersion.replaceAll('\n', ' ');
    return '$deviceType · $osText';
  }

  Widget _buildUndistortedCameraPreview(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return CameraPreview(controller);
        }

        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }

  Widget _cameraPanel() {
    final controller = cameraController;
    final ready = cameraReady && controller != null && controller.value.isInitialized;

    return Container(
      height: 286,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColours.mutedBox,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColours.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (capturedStillPreviewBytes != null)
            Image.memory(
              capturedStillPreviewBytes!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            )
          else if (ready)
            _buildUndistortedCameraPreview(controller)
          else
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 210,
                height: 254,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(120),
                  border: Border.all(
                    color: verificationReady ? AppColours.green : Colors.white.withOpacity(0.86),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.48),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (verifying)
            Container(
              color: Colors.black.withOpacity(0.12),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        fontSize: AppTextSize.s13,
                        fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final canCaptureFace = cameraReady && !verifying && !submitting && faceAttemptCount < 3;
    final canSubmit = selectedMode != null && verificationReady && qrCaptured && !verifying && !submitting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColours.greenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.how_to_reg_outlined, color: AppColours.green),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Verification',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSize.s24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Complete all fields before submit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSize.s13,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: verifying || submitting ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _AttendanceActionChipSelector(
                  value: selectedMode,
                  enabled: !verifying && !submitting,
                  onChanged: (value) {
                    setState(() {
                      selectedMode = value;
                      errorText = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _cameraPanel(),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColours.redSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColours.red.withOpacity(0.18)),
                    ),
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                        fontSize: AppTextSize.s13,
                        color: AppColours.red,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _FaceCheckRow(
                  title: 'Face presence',
                  subtitle: faceVerificationBypassed
                      ? 'Failed after 3 attempts · attendance may continue'
                      : faceAttemptCount == 0
                          ? 'Exactly one full face required · up to 3 attempts'
                          : 'Exactly one full face required · attempt $faceAttemptCount of 3',
                  passed: facePresencePassed,
                  active: verifying && !facePresencePassed,
                ),
                _FaceCheckRow(
                  title: 'Single-face validation',
                  subtitle: 'Multiple faces are rejected',
                  passed: singleFacePassed,
                  active: facePresencePassed && !singleFacePassed,
                ),
                _FaceCheckRow(
                  title: 'Face size validation',
                  subtitle: 'Face clear enough',
                  passed: faceSizePassed,
                  active: singleFacePassed && !faceSizePassed,
                ),
                _FaceCheckRow(
                  title: 'Face framing guide',
                  subtitle: 'Visual guide only · not blocking',
                  passed: faceFramingPassed,
                  active: faceSizePassed && !faceFramingPassed,
                ),
                _FaceCheckRow(
                  title: 'Face angle guide',
                  subtitle: 'Advisory only · not blocking',
                  passed: faceAnglePassed,
                  active: faceFramingPassed && !faceAnglePassed,
                ),
                _FaceCheckRow(
                  title: 'GPS location',
                  subtitle: gpsAddressText,
                  passed: locationCaptured,
                  active: (faceAnglePassed || faceVerificationBypassed) && !locationCaptured,
                ),
                if (verificationReady || qrCaptured) ...[
                  const SizedBox(height: 4),
                  _FaceCaptureSummaryCard(
                    modeLabel: selectedMode ?? '-',
                    branchName: widget.branchName,
                    verifiedAt: _formatVerificationTime(verifiedAt),
                    qrCapturedAt: _formatVerificationTime(qrCapturedAt),
                    faceStatus: faceVerificationBypassed ? 'Failed · continued after 3 attempts' : 'Passed',
                    faceAttempts: '$faceAttemptCount of 3',
                    faceCount: detectedFaceCount.toString(),
                    faceBox: faceBoxText,
                    faceAngle: faceAngleText,
                    faceFraming: faceFramingText,
                    gpsAddress: gpsAddressText,
                    gpsCoordinates: gpsCoordinatesText,
                    gpsAccuracy: gpsAccuracyText,
                    distanceInfo: distanceStatusText,
                    deviceInfo: _deviceInfoText(),
                    cameraInfo: selectedCamera == null ? '-' : '${selectedCamera!.lensDirection.name} camera',
                    qrCheckpoint: qrCaptured ? qrCheckpointText : '-',
                    facePhotoBytes: capturedFaceBytes,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: faceVerificationBypassed
                      ? 'Face Bypassed'
                      : verificationReady && faceAttemptCount >= 3
                          ? 'Face Captured'
                          : verificationReady
                              ? 'Retake Face'
                              : 'Capture Face (${math.min(faceAttemptCount + 1, 3)}/3)',
                  icon: Icons.center_focus_strong_rounded,
                  outlined: verificationReady,
                  onPressed: canCaptureFace ? verifyFacePresence : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  text: qrCaptured ? 'QR Captured' : 'Capture QR',
                  icon: Icons.qr_code_scanner_rounded,
                  outlined: qrCaptured,
                  onPressed: verifying || submitting ? null : captureQrCheckpoint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            text: submitting ? 'Submitting...' : 'Submit',
            icon: Icons.check_circle_outline_rounded,
            onPressed: canSubmit ? submitVerification : null,
          ),
        ],
      ),
    );
  }
}

class _FaceCaptureSummaryCard extends StatelessWidget {
  final String modeLabel;
  final String branchName;
  final String verifiedAt;
  final String qrCapturedAt;
  final String faceStatus;
  final String faceAttempts;
  final String faceCount;
  final String faceBox;
  final String faceAngle;
  final String faceFraming;
  final String gpsAddress;
  final String gpsCoordinates;
  final String gpsAccuracy;
  final String distanceInfo;
  final String deviceInfo;
  final String cameraInfo;
  final String qrCheckpoint;
  final Uint8List? facePhotoBytes;

  const _FaceCaptureSummaryCard({
    required this.modeLabel,
    required this.branchName,
    required this.verifiedAt,
    required this.qrCapturedAt,
    required this.faceStatus,
    required this.faceAttempts,
    required this.faceCount,
    required this.faceBox,
    required this.faceAngle,
    required this.faceFraming,
    required this.gpsAddress,
    required this.gpsCoordinates,
    required this.gpsAccuracy,
    required this.distanceInfo,
    required this.deviceInfo,
    required this.cameraInfo,
    required this.qrCheckpoint,
    required this.facePhotoBytes,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = facePhotoBytes != null && facePhotoBytes!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColours.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.green.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.fact_check_outlined, color: AppColours.green, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification summary',
                      style: TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review details before submit',
                      style: TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SmallStatusPill(
                text: 'Ready',
                textColour: AppColours.green,
                backgroundColour: Colors.white,
              ),
            ],
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 118,
                width: double.infinity,
                color: Colors.white,
                child: Image.memory(
                  facePhotoBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _FaceInfoRow(label: 'Action', value: modeLabel),
          _FaceInfoRow(label: 'Outlet', value: branchName),
          _FaceInfoRow(label: 'Verified time', value: verifiedAt),
          _FaceInfoRow(label: 'QR time', value: qrCapturedAt),
          _FaceInfoRow(label: 'Face verification', value: faceStatus),
          _FaceInfoRow(label: 'Face attempts', value: faceAttempts),
          _FaceInfoRow(label: 'Face count', value: faceCount),
          _FaceInfoRow(label: 'Face frame', value: faceBox),
          _FaceInfoRow(label: 'Face angle', value: faceAngle),
          _FaceInfoRow(label: 'Face framing', value: faceFraming),
          _FaceInfoRow(label: 'Face quality', value: faceStatus),
          _FaceInfoRow(label: 'QR checkpoint', value: qrCheckpoint),
          _FaceInfoRow(label: 'Detected address', value: gpsAddress),
          _FaceInfoRow(label: 'GPS coordinates', value: gpsCoordinates),
          _FaceInfoRow(label: 'GPS accuracy', value: gpsAccuracy),
          _FaceInfoRow(label: 'Distance from office', value: distanceInfo),
          _FaceInfoRow(label: 'Device info', value: deviceInfo),
          _FaceInfoRow(label: 'Camera', value: cameraInfo),
          const _FaceInfoRow(label: 'Face photo storage', value: 'Not saved locally'),
          const _FaceInfoRow(label: 'Server time', value: 'Recorded on submit'),
        ],
      ),
    );
  }
}


class _AttendanceActionChipSelector extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _AttendanceActionChipSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['Clock In', 'Clock Out'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select action',
          style: TextStyle(
            fontSize: AppTextSize.s12,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              final selected = option == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Pressable(
                  onTap: enabled ? () => onChanged(option) : null,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColours.blue : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? AppColours.blue : AppColours.border),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColours.blue.withOpacity(0.16),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: AppTextSize.s13,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColours.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FaceInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _FaceInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: AppTextSize.s12,
                color: AppColours.textMain,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceCheckRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool passed;
  final bool active;

  const _FaceCheckRow({
    required this.title,
    required this.subtitle,
    required this.passed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: passed
              ? AppColours.green.withOpacity(0.28)
              : active
                  ? AppColours.blue.withOpacity(0.25)
                  : AppColours.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: passed
                  ? AppColours.greenSoft
                  : active
                      ? AppColours.blueSoft
                      : AppColours.mutedBox,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              passed
                  ? Icons.check_rounded
                  : active
                      ? Icons.more_horiz_rounded
                      : Icons.lock_outline_rounded,
              color: passed
                  ? AppColours.green
                  : active
                      ? AppColours.blue
                      : AppColours.textMuted,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSize.s15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
            text: passed
                ? 'Pass'
                : active
                    ? 'Scan'
                    : 'Wait',
            textColour: passed
                ? AppColours.green
                : active
                    ? AppColours.blue
                    : AppColours.textMuted,
            backgroundColour: passed
                ? AppColours.greenSoft
                : active
                    ? AppColours.blueSoft
                    : AppColours.mutedBox,
          ),
        ],
      ),
    );
  }
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
    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColours.blue, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppTextSize.s16,
              fontWeight: FontWeight.w700,
              color: AppColours.textMain,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
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


class _AttendanceProgressBadge extends StatelessWidget {
  final bool inDone;
  final bool outDone;

  const _AttendanceProgressBadge({
    required this.inDone,
    required this.outDone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AttendanceProgressPill(label: 'In', done: inDone),
        const SizedBox(width: 3),
        _AttendanceProgressPill(label: 'Out', done: outDone),
      ],
    );
  }
}

class _AttendanceProgressPill extends StatelessWidget {
  final String label;
  final bool done;

  const _AttendanceProgressPill({
    required this.label,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final colour = done ? AppColours.green : AppColours.orange;
    final background = done ? AppColours.greenSoft : AppColours.orangeSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 11,
            color: colour,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: colour,
              fontSize: AppTextSize.s12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;
  final Widget? badgeWidget;

  const _PeopleMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeText,
    this.badgeWidget,
  });

  @override
  Widget build(BuildContext context) {
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
                  if (badgeWidget != null)
                    badgeWidget!
                  else if (badgeText != null)
                    SmallStatusPill(
                      text: badgeText!,
                      textColour: AppColours.green,
                      backgroundColour: AppColours.greenSoft,
                    ),
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
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

class _PeopleSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _PeopleSearchBox({
    required this.controller,
    required this.resultCount,
    required this.totalCount,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return Row(
      children: [
        const Icon(Icons.search_rounded, color: AppColours.textMuted, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Search name, role, phone, date, status',
              hintStyle: TextStyle(
                color: AppColours.textMuted,
                fontSize: AppTextSize.s14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: const TextStyle(
              fontSize: AppTextSize.s15,
              fontWeight: FontWeight.w700,
              color: AppColours.textMain,
            ),
          ),
        ),
        if (hasText) ...[
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColours.textMuted),
          ),
        ],
        const SizedBox(width: 8),
        SmallStatusPill(
          text: '$resultCount/$totalCount',
          textColour: AppColours.blue,
          backgroundColour: AppColours.blueSoft,
        ),
      ],
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
    if (users.isEmpty) {
      return WhiteCard(
        padding: const EdgeInsets.all(18),
        child: const Text(
          'No user found',
          style: TextStyle(
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
    final lastWorkingText = user.lastWorkingDate == null
        ? ''
        : ' · Last: ${_formatPeopleDate(user.lastWorkingDate)}';

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
                    '${user.employeeId} · ${user.role} · ${user.phoneNumber}$lastWorkingText',
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
              text: user.active ? 'Active' : 'Inactive',
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
    final systemKey = role.systemKey;
    return systemKey != null && allowedKeys.contains(systemKey);
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
    final confirmed = await confirmDataChange(
      context,
      action: isEditing ? 'Update User?' : 'Create User?',
      details: selected.systemKey == 'OWNER' &&
              (!isEditing || widget.user?.roleSystemKey != 'OWNER')
          ? 'This will assign Owner access and a separate employee ID in every business.'
          : isEditing
              ? 'This will update the selected user account and access settings.'
              : 'This will create an employee ID only inside ${widget.tenant.businessName}.',
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
        isEditing
            ? 'User updated'
            : generatedEmployeeId == null
                ? 'User created'
                : 'User created · $generatedEmployeeId',
      );
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    isEditing ? 'Edit User' : 'Create User',
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
              const WhiteCard(
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, color: AppColours.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Employee ID will be generated automatically by this business.',
                        style: TextStyle(
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
                        const Text(
                          'Business',
                          style: TextStyle(
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
                const Text(
                  'When the phone number already belongs to an application login, the same profile and password are reused and only a new employee ID is created for this business.',
                  style: TextStyle(
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
              label: 'Phone Number',
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
            ),
            const SizedBox(height: 12),
            if (rolesLoading)
              const WhiteCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Loading roles for this business...'),
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
                      label: const Text('Retry'),
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
              text: saving
                  ? 'Saving...'
                  : isEditing
                      ? 'Save Changes'
                      : 'Save User',
              icon: Icons.save_outlined,
              onPressed: saving ? null : submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleDraft {
  final String name;
  final bool active;

  const _RoleDraft({required this.name, required this.active});
}

class _RoleFormSheet extends StatefulWidget {
  final _PeopleRole? role;
  final List<_PeopleRole> existingRoles;
  final int assignedCount;
  final Future<void> Function(_RoleDraft draft) onSaveRole;
  final VoidCallback? onDeleteRole;

  const _RoleFormSheet({
    this.role,
    required this.existingRoles,
    this.assignedCount = 0,
    required this.onSaveRole,
    this.onDeleteRole,
  });

  @override
  State<_RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<_RoleFormSheet> {
  final nameController = TextEditingController();
  bool active = true;
  bool showErrors = false;
  bool saving = false;

  bool get isEditing => widget.role != null;
  bool get isOwner => widget.role?.isOwner == true;
  bool get isHead => widget.role?.isHead == true;
  bool get isProtectedRole => isOwner || isHead;
  bool get isBuiltIn => widget.role?.isBuiltIn == true;

  String? get nameError {
    if (!showErrors) return null;
    final name = nameController.text.trim();
    if (name.isEmpty) return 'Role Name required';
    final duplicate = widget.existingRoles.any((role) {
      return role.id != widget.role?.id &&
          role.name.toLowerCase() == name.toLowerCase();
    });
    if (duplicate) return 'Role Name already exists';
    return null;
  }

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    if (role == null) return;
    nameController.text = role.name;
    active = role.active;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => showErrors = true);
    if (nameError != null) {
      AppFeedback.warning();
      return;
    }

    final confirmed = await confirmDataChange(
      context,
      action: isEditing ? 'Update Role?' : 'Create Role?',
      details: isEditing
          ? 'This will update the selected role and may affect assigned users.'
          : 'This will create a new role for this business.',
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      await widget.onSaveRole(
        _RoleDraft(
          name: nameController.text.trim(),
          active: isHead ? true : active,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(
        context,
        isEditing ? 'Role updated' : 'Role created',
      );
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignedText = widget.assignedCount == 1
        ? '1 user is assigned to this role.'
        : '${widget.assignedCount} users are assigned to this role.';

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
                    isEditing ? 'Edit Role' : 'Create Role',
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
            Text('Role Name', style: AppTextStyles.formLabel),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (showErrors) setState(() {});
              },
              decoration: AppInputStyle.decoration(
                'Example: Barista',
              ).copyWith(errorText: nameError),
              style: AppTextStyles.formValue,
            ),
            const SizedBox(height: 12),
            _ActiveStatusField(
              value: active,
              onChanged: isProtectedRole || saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      AppFeedback.select();
                      setState(() => active = value);
                    },
            ),
            if (isEditing) ...[
              const SizedBox(height: 10),
              Text(
                isOwner
                    ? 'Owner can be renamed but must remain active.'
                    : isHead
                        ? 'Head can be renamed but must remain active.'
                        : isBuiltIn
                        ? '$assignedText Built-in roles can be renamed or deactivated but cannot be deleted.'
                        : widget.assignedCount > 0
                            ? '$assignedText Assigned roles can be deactivated but cannot be deleted.'
                            : 'This custom role is not assigned and can be deleted.',
                style: const TextStyle(
                  fontSize: AppTextSize.s12,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            if (widget.onDeleteRole != null) ...[
              const SizedBox(height: 12),
              _DangerButton(
                text: 'Delete Role',
                icon: Icons.delete_outline_rounded,
                onPressed: saving ? null : widget.onDeleteRole,
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              text: saving
                  ? 'Saving...'
                  : isEditing
                      ? 'Save Changes'
                      : 'Save Role',
              icon: Icons.save_outlined,
              onPressed: saving ? null : submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteRoleSheet extends StatefulWidget {
  final _PeopleRole role;
  final Future<void> Function() onDeleteRole;

  const _DeleteRoleSheet({
    required this.role,
    required this.onDeleteRole,
  });

  @override
  State<_DeleteRoleSheet> createState() => _DeleteRoleSheetState();
}

class _DeleteRoleSheetState extends State<_DeleteRoleSheet> {
  bool deleting = false;

  Future<void> deleteRole() async {
    final confirmed = await confirmDataChange(
      context,
      action: 'Delete Role?',
      details: 'This will permanently delete the selected custom role.',
    );
    if (!confirmed || !mounted) return;

    setState(() => deleting = true);
    try {
      await widget.onDeleteRole();
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(context, 'Role deleted');
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PeopleSheetHandle(),
          const SizedBox(height: 12),
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
                  Icons.delete_outline_rounded,
                  color: AppColours.red,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Role',
                  style: TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: deleting ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Delete ${widget.role.name}? This cannot be undone.',
            style: const TextStyle(
              fontSize: AppTextSize.s16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          _DangerButton(
            text: deleting ? 'Deleting...' : 'Delete Role',
            icon: Icons.delete_forever_outlined,
            onPressed: deleting ? null : deleteRole,
          ),
        ],
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
    final confirmed = await confirmDataChange(
      context,
      action: 'Deactivate User?',
      details:
          'This will set the user to inactive using the selected last working date.',
    );
    if (!confirmed || !mounted) return;

    setState(() => saving = true);
    try {
      await widget.onDeactivateUser(lastWorkingDate);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(context, 'User set to inactive');
    } on EastAppApiException catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const Text(
                        'Deactivate User',
                        style: TextStyle(
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
                border: Border.all(color: AppColours.red.withOpacity(0.18)),
              ),
              child: const Text(
                'Status will be set to Inactive and all sessions will be revoked.',
                style: TextStyle(
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
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColours.redSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColours.red.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColours.red, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
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

class _PhotoCaptureTile extends StatelessWidget {
  final String title;
  final bool added;
  final VoidCallback onTap;
  final String? errorText;

  const _PhotoCaptureTile({
    required this.title,
    required this.added,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: added ? AppColours.greenSoft : AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  added ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                  color: added ? AppColours.green : AppColours.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 5),
                Text(
                  errorText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSize.s10,
                    fontWeight: FontWeight.w700,
                    color: AppColours.red,
                  ),
                ),
              ],
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.formLabel),
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
            hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ).copyWith(
            errorText: errorText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.formLabel),
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
                      value,
                      style: TextStyle(
                        fontSize: AppTextSize.s17,
                        fontWeight: FontWeight.w700,
                        color: errorText == null ? AppColours.textMain : AppColours.red,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                  const Icon(Icons.calendar_month_outlined, color: AppColours.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Text(
            errorText!,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active', style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        DropdownButtonFormField<bool>(
          value: value,
          items: const [
            DropdownMenuItem<bool>(
              value: true,
              child: Text('Active'),
            ),
            DropdownMenuItem<bool>(
              value: false,
              child: Text('Inactive'),
            ),
          ],
          onChanged: onChanged,
          decoration: AppInputStyle.decoration(
            'Select status',
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
    final hasCurrentValue = roles.any((role) => role.name == value);
    final options = hasCurrentValue
        ? roles
        : [
            _PeopleRole(
              id: 'CURRENT',
              systemKey: null,
              name: value,
              active: false,
            ),
            ...roles,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role', style: AppTextStyles.formLabel),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: options
              .map((role) => DropdownMenuItem<String>(
                    value: role.name,
                    child: Text(
                      role.active ? role.name : '${role.name} · Inactive',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: AppInputStyle.decoration(
            'Select role',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ).copyWith(errorText: errorText),
          style: const TextStyle(
            fontSize: AppTextSize.s17,
            fontWeight: FontWeight.w700,
            color: AppColours.textMain,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
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
  final String? systemKey;
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

  bool get isBuiltIn => systemKey != null;
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
