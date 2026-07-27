import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'screens/sos_portal.dart';
import 'screens/victim_login_screen.dart';
import 'screens/victim_profile_setup_screen.dart';

// The global plugin instance — accessible from anywhere in the app
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Must be top-level and annotated for background isolate
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

// Called from the onMessage listener — shows a visible notification while app is open
void showForegroundNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'Rescue Alerts',
    channelDescription:
        'Critical alerts when a rescue unit is dispatched to your SOS request.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    notificationDetails,
  );
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must be registered before runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Initialize local notifications so foreground FCM messages show as banners
  await _initLocalNotifications();

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
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep modern slate
        primaryColor: Colors.redAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.orangeAccent,
          surface: Color(0xFF151C2C), // Elevated card color
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0F19),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.white
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151C2C),
          labelStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white, // Text color
            elevation: 4,
            shadowColor: Colors.redAccent.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
          ),
        ),
      ),
      home: const VictimAuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VictimAuthWrapper extends StatelessWidget {
  const VictimAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const VictimLoginScreen();
        }

        return VictimCheckState(user: user);
      },
    );
  }
}

class VictimCheckState extends StatefulWidget {
  final User user;
  const VictimCheckState({super.key, required this.user});

  @override
  State<VictimCheckState> createState() => _VictimCheckStateState();
}

class _VictimCheckStateState extends State<VictimCheckState> {
  bool _isLoading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkVictimProfile();
  }

  Future<void> _checkVictimProfile() async {
    try {
      final res = await http.get(
        Uri.parse('https://geo-aid-hub.onrender.com/api/victims/me?uid=${widget.user.uid}'),
      );
      if (mounted) {
        setState(() {
          _hasProfile = (res.statusCode == 200);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasProfile = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.redAccent),
              SizedBox(height: 16),
              Text('Checking Emergency Profile...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_hasProfile) {
      return const SosPortal();
    } else {
      return VictimProfileSetupScreen(
        authUid: widget.user.uid,
        email: widget.user.email,
      );
    }
  }
}
