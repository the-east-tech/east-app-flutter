import 'dart:async';

import 'package:flutter/material.dart';

import 'localization/app_language.dart';
import 'localization/app_text_scope.dart';
import 'models/auth_models.dart';
import 'models/people_models.dart';
import 'screens/initial_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_configuration.dart';
import 'services/east_app_api.dart';
import 'services/session_store.dart';
import 'theme/app_theme.dart';
import 'utils/app_diagnostics.dart';
import 'widgets/app_components.dart';

class TheEastApp extends StatefulWidget {
  const TheEastApp({super.key});

  @override
  State<TheEastApp> createState() => _TheEastAppState();
}

class _TheEastAppState extends State<TheEastApp> {
  final EastAppApi api = EastAppApi();
  final SessionStore sessionStore = SessionStore();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  EastAppSession? session;
  AppLanguage language = AppLanguage.english;
  bool restoringSession = true;
  bool checkingSetup = true;
  bool setupRequired = false;
  String? initialSetupCode;
  DateTime? initialSetupCodeExpiresAt;
  String? startupError;
  bool apiErrorDialogOpen = false;
  bool processingRequest = false;

  @override
  void initState() {
    super.initState();
    api.onSessionInvalidated = handleSessionInvalidated;
    api.onApiError = handleApiError;
    api.onProcessingChanged = handleProcessingChanged;

    final configurationError = ApiConfiguration.startupError;
    if (configurationError != null) {
      checkingSetup = false;
      restoringSession = false;
      startupError = configurationError;
      AppDiagnostics.instance.log(configurationError);
      return;
    }

    initialiseApp();
  }

  void handleApiError(EastAppApiException error) {
    if (error.invalidatesSession || apiErrorDialogOpen) return;
    apiErrorDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      if (!mounted || context == null) {
        apiErrorDialogOpen = false;
        return;
      }
      try {
        await showApiErrorDialog(context, error);
      } finally {
        apiErrorDialogOpen = false;
      }
    });
  }

  void handleProcessingChanged(bool value) {
    if (!mounted || processingRequest == value) return;
    setState(() => processingRequest = value);
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> initialiseApp() async {
    if (!mounted) return;
    setState(() {
      checkingSetup = true;
      restoringSession = true;
      startupError = null;
      initialSetupCode = null;
      initialSetupCodeExpiresAt = null;
    });

    try {
      final status = await api.setupStatus();
      if (!mounted) return;
      if (status.setupRequired) {
        try {
          await sessionStore.clearToken();
        } catch (error) {
          AppDiagnostics.instance.log(
            'Failed to clear stale session before initial setup: $error',
          );
        }
        api.useToken(null);
        setState(() {
          checkingSetup = false;
          restoringSession = false;
          setupRequired = true;
          initialSetupCode = status.setupCode;
          initialSetupCodeExpiresAt = status.setupCodeExpiresAt;
          session = null;
        });
        return;
      }

      setState(() {
        checkingSetup = false;
        setupRequired = false;
        initialSetupCode = null;
        initialSetupCodeExpiresAt = null;
      });
      await restoreSession();
    } on EastAppApiException catch (error) {
      AppDiagnostics.instance.log(
        'Initial setup status failed: ${error.code} ${error.message}',
      );
      if (!mounted) return;
      setState(() {
        checkingSetup = false;
        restoringSession = false;
        startupError = error.message;
      });
    }
  }

  void handleInitialSetupCompleted() {
    setState(() {
      setupRequired = false;
      initialSetupCode = null;
      initialSetupCodeExpiresAt = null;
      startupError = null;
      session = null;
    });
  }

  Future<void> restoreSession() async {
    setState(() {
      restoringSession = true;
      startupError = null;
    });

    String? token;
    try {
      token = await sessionStore.readToken();
    } catch (error) {
      AppDiagnostics.instance.log(
        'Failed to read secure session token: $error',
      );
      if (!mounted) return;
      setState(() {
        startupError = 'Secure session storage is unavailable on this device.';
        restoringSession = false;
      });
      return;
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        restoringSession = false;
        session = null;
      });
      return;
    }

    try {
      final restored = await api.currentSession(token);
      if (!mounted) return;
      setState(() {
        session = restored;
        restoringSession = false;
      });
    } on EastAppApiException catch (error) {
      if (error.invalidatesSession) {
        api.useToken(null);
        await handleSessionInvalidated();
        return;
      }

      AppDiagnostics.instance.log(
        'Session restore failed: ${error.code} ${error.message}',
      );
      if (!mounted) return;
      setState(() {
        startupError = error.message;
        restoringSession = false;
      });
    }
  }

  Future<void> handleSessionInvalidated() async {
    try {
      await sessionStore.clearToken();
    } catch (error) {
      AppDiagnostics.instance.log(
        'Failed to clear invalid local session token: $error',
      );
    }
    try {
      await api.clearFeatureCaches();
    } catch (error) {
      AppDiagnostics.instance.log('Failed to clear cached business data: $error');
    }
    if (!mounted) return;
    setState(() {
      session = null;
      startupError = null;
      restoringSession = false;
    });
  }

  Future<void> handleSignedIn(EastAppSession signedInSession) async {
    try {
      await sessionStore.writeToken(signedInSession.token);
    } catch (error) {
      api.useToken(null);
      AppDiagnostics.instance.log(
        'Failed to store secure session token: $error',
      );
      throw const EastAppApiException(
        statusCode: null,
        code: 'SECURE_STORAGE_UNAVAILABLE',
        message: 'Cannot securely store the login session on this device.',
      );
    }
    if (!mounted) return;
    setState(() {
      session = signedInSession;
      startupError = null;
    });
  }

  void handleCurrentUserChanged(EastAppUser user) {
    final current = session;
    if (current == null) return;
    final roleChanged = current.user.role.systemKey != user.role.systemKey;
    setState(() {
      session = current.copyWith(
        user: user,
        permissions: roleChanged
            ? const <EastAppPermission>{}
            : current.permissions,
      );
    });
    if (roleChanged) {
      unawaited(refreshPermissionsAfterRoleChange(current.token, user.id));
    }
  }

  Future<void> refreshPermissionsAfterRoleChange(
    String token,
    String userId,
  ) async {
    try {
      await api.clearFeatureCaches();
    } catch (error) {
      AppDiagnostics.instance.log(
        'Failed to clear feature caches after role change: $error',
      );
    }
    try {
      final refreshed = await api.currentSession(token);
      if (!mounted ||
          session?.token != token ||
          session?.user.id != userId) {
        return;
      }
      setState(() => session = refreshed);
    } on EastAppApiException catch (error) {
      AppDiagnostics.instance.log(
        'Permission refresh failed after role change: '
        '${error.code} ${error.message}',
      );
    }
  }

  void handleSessionChanged(EastAppSession nextSession) {
    setState(() {
      session = nextSession;
      startupError = null;
    });
  }


  void handleLanguageChanged(AppLanguage value) {
    if (language == value) return;
    setState(() => language = value);
  }

  Future<void> handleLogout() async {
    try {
      await api.logout();
    } on EastAppApiException catch (error) {
      AppDiagnostics.instance.log(
        'Server logout failed; clearing local session: ${error.code} ${error.message}',
      );
    } finally {
      try {
        await sessionStore.clearToken();
      } catch (error) {
        AppDiagnostics.instance.log(
          'Failed to clear local session token during logout: $error',
        );
      }
      try {
        await api.clearFeatureCaches();
      } catch (error) {
        AppDiagnostics.instance.log('Failed to clear cached business data: $error');
      }
      api.useToken(null);
    }

    if (!mounted) return;
    setState(() => session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: "Nic's Kitchen",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => AppTextScope(
        language: language,
        child: AppProcessingOverlay(
          isProcessing: processingRequest,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (checkingSetup || restoringSession) {
      return const _StartupScreen();
    }

    if (startupError != null) {
      return _StartupErrorScreen(
        message: startupError!,
        onRetry: initialiseApp,
        onClearSession: () async {
          try {
            await sessionStore.clearToken();
          } catch (error) {
            AppDiagnostics.instance.log(
              'Failed to clear local session token: $error',
            );
          }
          api.useToken(null);
          if (!mounted) return;
          await initialiseApp();
        },
      );
    }

    if (setupRequired) {
      return InitialSetupScreen(
        api: api,
        setupCode: initialSetupCode,
        setupCodeExpiresAt: initialSetupCodeExpiresAt,
        onCompleted: handleInitialSetupCompleted,
      );
    }

    final currentSession = session;
    if (currentSession == null) {
      return LoginScreen(
        api: api,
        onSignedIn: handleSignedIn,
        initialLanguage: language,
        onLanguageChanged: handleLanguageChanged,
      );
    }

    final permissionKey = currentSession.permissions
        .map((permission) => permission.apiValue)
        .toList(growable: false)
      ..sort();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: MainShell(
        key: ValueKey(
          '${currentSession.tenant.id}:${currentSession.user.id}:'
          '${currentSession.user.role.systemKey}:${permissionKey.join(',')}',
        ),
        role: currentSession.user.role.appRole,
        session: currentSession,
        api: api,
        onLogout: handleLogout,
        onSessionChanged: handleSessionChanged,
        onCurrentUserChanged: handleCurrentUserChanged,
        initialLanguage: language,
        onLanguageChanged: handleLanguageChanged,
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColours.blue,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClearSession;

  const _StartupErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onClearSession,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Scaffold(
      backgroundColor: AppColours.blue,
      body: Center(
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 44,
                color: AppColours.red,
              ),
              const SizedBox(height: 12),
              Text(
                text.t('Backend unavailable'),
                style: const TextStyle(
                  fontSize: AppTextSize.s24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  child: Text(text.t('Retry')),
                ),
              ),
              TextButton(
                onPressed: onClearSession,
                child: Text(text.t('Return to login')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
