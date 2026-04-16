import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const GeoAidApp());
}

class GeoAidApp extends StatelessWidget {
  const GeoAidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo-Aid SOS',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.green,
        ),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
