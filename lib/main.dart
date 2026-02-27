import 'package:camera/camera.dart';
import 'package:wingbase/Screens/CameraScreen.dart';
import 'package:wingbase/Screens/HomeScreen.dart';
import 'package:flutter/material.dart';
import 'package:wingbase/utils/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  runApp(const MyChatApp());
}

class MyChatApp extends StatelessWidget {
  const MyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // For System Theme
      themeMode: ThemeMode.system,
      // Light Theme
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: WingBaseColors.lightScaffoldBg,
        colorScheme: ColorScheme.light(
          primary: WingBaseColors.primary,
          secondary: WingBaseColors.primary,
          surface: WingBaseColors.lightCardBg,
        ),
        appBarTheme: AppBarThemeData(
          backgroundColor: WingBaseColors.lightAppBar,
          foregroundColor: WingBaseColors.lightTextPrimary,
          iconTheme: IconThemeData(color: WingBaseColors.lightTextPrimary),
          elevation: 0.5,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: WingBaseColors.primary,
          unselectedLabelColor: WingBaseColors.lightTextSecondary,
          indicatorColor: WingBaseColors.primary,
          dividerColor: Colors.transparent,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: WingBaseColors.primary,
          foregroundColor: Colors.white,
          shape: CircleBorder(),
        ),
        dividerColor: WingBaseColors.lightDivider,
      ),

      // Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: WingBaseColors.darkScaffoldBg,
        colorScheme: ColorScheme.dark(
          primary: WingBaseColors.primary,
          secondary: WingBaseColors.primary,
          surface: WingBaseColors.darkCardBg,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: WingBaseColors.darkAppBar,
          foregroundColor: WingBaseColors.darkTextPrimary,
          iconTheme: IconThemeData(color: WingBaseColors.darkTextPrimary),
          elevation: 0,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: WingBaseColors.primary,
          unselectedLabelColor: WingBaseColors.darkTextSecondary,
          indicatorColor: WingBaseColors.primary,
          dividerColor: Colors.transparent,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: WingBaseColors.primary,
          foregroundColor: Colors.white,
          shape: CircleBorder(),
        ),
        dividerColor: WingBaseColors.darkDivider,
      ),
      home: HomeScreen(),
    );
  }
}
