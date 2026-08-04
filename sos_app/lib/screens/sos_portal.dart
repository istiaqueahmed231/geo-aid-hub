import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'tracking_screen.dart';
import 'victim_profile_screen.dart';
import 'victim_request_history_screen.dart';
import 'direct_admin_chat_screen.dart';
import '../main.dart' show showForegroundNotification;

class SosPortal extends StatefulWidget {
  const SosPortal({super.key});

  @override
  State<SosPortal> createState() => _SosPortalState();
}

class _SosPortalState extends State<SosPortal> {
  int _currentIndex = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  int _selectedCategory = 1;

  final Map<int, String> _categories = {
    1: 'Emergency Medical Kits',
    2: 'Drinking Water',
    3: 'Dry Food Rations',
    4: 'Rescue Boats',
  };

  bool _isSending = false;
  double _urgencyScore = 5.0;

  // Keeps the latest FCM token in SharedPreferences so _sendSosAlert can read it quickly.
  Future<void> _updateFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final storedRequestId = prefs.getInt('active_request_id');
    await prefs.setString('fcm_token', token);
    if (storedRequestId != null) {
      try {
        await http.post(
          Uri.parse('https://geo-aid-hub.onrender.com/api/update-fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'requestId': storedRequestId, 'fcmToken': token}),
        );
        debugPrint("FCM token refreshed on server for request #$storedRequestId");
      } catch (e) {
        debugPrint("Failed to push refreshed FCM token: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.instance.getToken().then((token) {
      debugPrint("📲 FCM Token: $token");
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint("FCM token refreshed: $newToken");
      _updateFcmToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showForegroundNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped! Opened from background.');
    });
  }

  Future<void> _sendSosAlert() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("FCM error: $e");
      }

      final user = FirebaseAuth.instance.currentUser;
      final Map<String, dynamic> sosData = {
        'RequestorName': _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim() 
            : (user?.displayName ?? 'Registered Victim'),
        'CategoryID': _selectedCategory,
        'UrgencyScore': _urgencyScore.toInt(),
        'Latitude': position.latitude,
        'Longitude': position.longitude,
        'ShortMessage': _messageController.text,
        'FCMToken': fcmToken,
        'authUid': user?.uid,
      };

      final response = await ApiService.sendSosAlert(sosData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('SOS Sent Successfully', style: TextStyle(color: Colors.redAccent)),
              content: const Text('Help is on the way. Please stay where you are.', style: TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _nameController.clear();
                    _messageController.clear();
                    setState(() => _selectedCategory = 1);

                    final responseData = jsonDecode(response.body);
                    final requestId = responseData['requestId'];
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setInt('active_request_id', requestId);
                    });
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(requestId: requestId)));
                  },
                  child: const Text('OK', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
        }
      } else {
        String serverError = 'Status ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody.containsKey('error')) {
            serverError = errBody['error'];
          } else {
            serverError = response.body;
          }
        } catch (_) {
          serverError = response.body;
        }
        throw Exception(serverError);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'GEO-AID DISPATCH' : _currentIndex == 1 ? 'MY REQUESTS HISTORY' : 'VICTIM PROFILE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.blueAccent),
            tooltip: 'Chat with Admin',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectAdminChatScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildSosForm(context),
          const VictimRequestHistoryScreen(),
          const VictimProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF151C2C),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Emergency SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            label: 'My Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSosForm(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0F19), Color(0xFF111827)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'EMERGENCY SOS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alert the nearest dispatch team immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 48),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Your Full Name',
                prefixIcon: Icon(Icons.person, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              initialValue: _selectedCategory,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Required Resources',
                prefixIcon: Icon(Icons.category, color: Colors.redAccent),
              ),
              items: _categories.entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _messageController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Short Message (Optional)',
                hintText: 'Describe your situation briefly...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.message, color: Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Urgency Level',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackShape: const RoundedRectSliderTrackShape(),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                          ),
                          child: Slider(
                            value: _urgencyScore,
                            min: 1.0,
                            max: 10.0,
                            divisions: 9,
                            activeColor: Colors.redAccent,
                            inactiveColor: Colors.white10,
                            onChanged: (double value) {
                              setState(() {
                                _urgencyScore = value;
                              });
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: 32,
                        alignment: Alignment.center,
                        child: Text(
                          '${_urgencyScore.toInt()}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            _isSending
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : ElevatedButton(
              onPressed: _sendSosAlert,
              child: const Text('BROADCAST SOS ALERT'),
            ),
          ],
        ),
      ),
    );
  }
}
