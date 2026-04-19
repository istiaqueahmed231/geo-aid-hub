import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dashboard_screen.dart';
import '../main.dart' show showVolunteerNotification;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  Future<void> _registerFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('📲 Volunteer FCM Token: $token');
      if (token == null) return;

      await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/volunteer/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'fcmToken': token}),
      );

      // Keep token fresh if Firebase rotates it
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await http.post(
          Uri.parse('https://geo-aid-hub.onrender.com/api/volunteer/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'uid': uid, 'fcmToken': newToken}),
        );
      });
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      const apiKey = 'AIzaSyDwnQj_7B2-cp7qz4wVLOW92AGMXBAuA9Q';
      final res = await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _pwController.text,
          'returnSecureToken': true,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(res.body);
      if (data['error'] != null) {
        throw Exception(data['error']['message']);
      }

      final uid = data['localId'] as String;

      // Handle remember-me persistence
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_uid', uid);
      } else {
        await prefs.remove('remember_me');
        await prefs.remove('saved_uid');
      }

      // Register FCM token so server can push mission notifications
      await _registerFcmToken(uid);

      // Set up foreground notification listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          showVolunteerNotification(message);
        }
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(uid: uid)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F19), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: const Icon(Icons.security_rounded,
                      size: 80, color: Colors.greenAccent),
                ),
                const SizedBox(height: 32),
                const Text(
                  'VOLUNTEER PORTAL',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authenticate to access missions',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 48),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon:
                        Icon(Icons.email_outlined, color: Colors.greenAccent),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pwController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: Colors.greenAccent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Remember Me row
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) =>
                          setState(() => _rememberMe = val ?? false),
                      activeColor: Colors.greenAccent,
                      checkColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                    ),
                    const Text('Remember Me',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.greenAccent))
                      : ElevatedButton(
                          onPressed: _login,
                          child: const Text('SECURE LOGIN'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
