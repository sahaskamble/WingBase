import 'package:camera/camera.dart';
import 'package:wingbase/Screens/CameraScreen.dart';
import 'package:wingbase/Screens/HomeScreen.dart';
import 'package:flutter/material.dart';

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
      theme: ThemeData(
        // useMaterial3: false,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF075E54),
          primary: Color(0xFF075E54),
          secondary: Color(0xFF128C7E),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF075E54),
          foregroundColor: Colors.white,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white30,
          indicatorColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF075E54),
          foregroundColor: Colors.white,
        ),
      ),
      home: HomeScreen(),
    );
  }
}
