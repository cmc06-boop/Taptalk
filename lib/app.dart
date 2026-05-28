import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/choose_category_screen.dart';
import 'screens/choose_theme_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
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
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: theme.colorScheme,
              scaffoldBackgroundColor: theme.bgLight,
              textTheme: GoogleFonts.poppinsTextTheme(),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            home: app.loading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
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
    }
  }
}
