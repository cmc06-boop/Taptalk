import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/choose_category_screen.dart';
import 'screens/choose_theme_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/my_child_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'screens/teacher_monitoring_screen.dart';
import 'screens/teacher_my_classes_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/welcome_screen.dart';

class TapTalkApp extends StatelessWidget {
  const TapTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, app, _) {
          final theme = app.theme;
          return MaterialApp(
            title: 'TapTalk',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: theme.colorScheme,
              scaffoldBackgroundColor: theme.bgLight,
              canvasColor: theme.bgLight,
              textTheme: GoogleFonts.poppinsTextTheme(),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              return ColoredBox(
                color: theme.bgLight,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: app.loading
                ? Scaffold(
                    backgroundColor: theme.bgLight,
                    body: Center(
                      child: CircularProgressIndicator(color: theme.bgAccent),
                    ),
                  )
                : _buildScreen(app.route),
          );
        },
      ),
    );
  }

  Widget _buildScreen(AppRoute route) {
    switch (route) {
      case AppRoute.welcome:
        return const WelcomeScreen();
      case AppRoute.login:
        return const LoginScreen();
      case AppRoute.register:
      case AppRoute.chooseRole:
        return const RegisterScreen();
      case AppRoute.chooseTheme:
        return const ChooseThemeScreen();
      case AppRoute.chooseCategory:
        return const ChooseCategoryScreen();
      case AppRoute.home:
        return const HomeScreen();
      case AppRoute.favorites:
        return const FavoritesScreen();
      case AppRoute.history:
        return const HistoryScreen();
      case AppRoute.settings:
        return const SettingsScreen();
      case AppRoute.profile:
        return const ProfileScreen();
      case AppRoute.myChild:
        return const MyChildScreen();
      case AppRoute.classes:
        return const ClassesScreen();
      case AppRoute.notifications:
        return const NotificationsScreen();
      case AppRoute.teacherDashboard:
        return const TeacherDashboardScreen();
      case AppRoute.teacherMyClasses:
        return const TeacherMyClassesScreen();
      case AppRoute.teacherMonitoring:
        return const TeacherMonitoringScreen();
    }
  }
}
