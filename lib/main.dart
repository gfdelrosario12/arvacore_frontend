import 'package:flutter/material.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/widgets.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/shell/presentation/app_shell.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AquaFlowApp());
}

class AquaFlowApp extends StatefulWidget {
  final AuthNotifier? authNotifier;

  const AquaFlowApp({
    super.key,
    this.authNotifier,
  });

  @override
  State<AquaFlowApp> createState() => _AquaFlowAppState();
}

class _AquaFlowAppState extends State<AquaFlowApp> {
  AuthNotifier get _notifier => widget.authNotifier ?? globalAuthNotifier;

  @override
  void initState() {
    super.initState();
    if (widget.authNotifier == null) {
      globalAuthNotifier.checkAuthStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: ValueListenableBuilder<AuthState>(
            valueListenable: _notifier,
            builder: (context, authState, _) {
              if (authState.status == AuthStatus.initial ||
                  (authState.status == AuthStatus.authenticating &&
                      authState.session == null)) {
                return const Scaffold(
                  body: Center(
                    child: LoadingStateWidget(
                      message: 'Verifying ArvaCore Operator Credentials...',
                    ),
                  ),
                );
              }

              if (authState.isAuthenticated) {
                return const AppShell();
              }

              return LoginScreen(authNotifier: _notifier);
            },
          ),
        );
      },
    );
  }
}

typedef ArvaCoreApp = AquaFlowApp;
