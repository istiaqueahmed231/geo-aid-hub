import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'tracking_screen.dart';
import '../main.dart' show showForegroundNotification;

class SosPortal extends StatefulWidget {
  const SosPortal({super.key});

  @override
  State<SosPortal> createState() => _SosPortalState();
}

class _SosPortalState extends State<SosPortal> {
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
  List<Map<String, dynamic>> _history = [];

  // Keeps the latest FCM token in SharedPreferences so _sendSosAlert can read it quickly.
  Future<void> _updateFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final storedRequestId = prefs.getInt('active_request_id');
    // Persist the latest token locally.
    await prefs.setString('fcm_token', token);
    // If there is an active request, push the refreshed token to the server.
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
    _loadHistory();

    // Log the FCM token so we can verify it is non-null during testing
    FirebaseMessaging.instance.getToken().then((token) {
      debugPrint("📲 FCM Token: $token");
    });

    // Keep the server in sync whenever Firebase rotates the FCM token.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint("FCM token refreshed: $newToken");
      _updateFcmToken(newToken);
    });

    // Show a real system notification while the app is open (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showForegroundNotification(message);
      }
    });

    // Optional: Handle tapping a notification when the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped! Opened from background.');
      // You can extract the requestId from message.data and navigate to TrackingScreen here
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyStrings = prefs.getStringList('sos_history') ?? [];
    if (mounted) {
      setState(() {
        _history = historyStrings.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _saveHistory(int requestId, String categoryName, int urgency, String message, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyStrings = prefs.getStringList('sos_history') ?? [];
    final newEntry = {
      'requestId': requestId,
      'category': categoryName,
      'date': DateTime.now().toIso8601String(),
      'urgency': urgency,
      'message': message,
      'name': name
    };
    historyStrings.insert(0, jsonEncode(newEntry));
    await prefs.setStringList('sos_history', historyStrings);
    _loadHistory();
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

      final Map<String, dynamic> sosData = {
        'RequestorName': _nameController.text,
        'CategoryID': _selectedCategory,
        'UrgencyScore': _urgencyScore.toInt(),
        'Latitude': position.latitude,
        'Longitude': position.longitude,
        'ShortMessage': _messageController.text,
        'FCMToken': fcmToken,
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
                    // Persist the active request ID so token refresh can update it on the server
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setInt('active_request_id', requestId);
                    });
                    _saveHistory(
                        requestId,
                        _categories[_selectedCategory] ?? 'Unknown',
                        _urgencyScore.toInt(),
                        _messageController.text,
                        _nameController.text
                    );
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(requestId: requestId)));
                  },
                  child: const Text('OK', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Failed to send SOS (Status: ${response.statusCode})');
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
        title: const Text('GEO-AID DISPATCH'),
      ),
      body: Container(
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
              // Glowing Warning Icon
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
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '${_urgencyScore.toInt()}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 20,
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

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final TextEditingController idController = TextEditingController();
                      showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Track Request', style: TextStyle(color: Colors.white)),
                            content: TextField(
                              controller: idController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Enter Request ID',
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                              ElevatedButton(
                                onPressed: () {
                                  if (idController.text.isNotEmpty) {
                                    Navigator.pop(ctx);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(requestId: int.parse(idController.text))));
                                  }
                                },
                                child: const Text('Track'),
                              )
                            ],
                          )
                      );
                    },
                    icon: const Icon(Icons.my_location, color: Colors.grey),
                    label: const Text('Manual ID', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (ctx) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Device SOS History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                if (_history.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text('No previous SOS requests from this device.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                                  )
                                else
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _history.length,
                                      itemBuilder: (ctx, i) {
                                        final item = _history[i];
                                        final dateStr = item['date'] != null ? item['date'].split('T').first : 'Unknown Date';
                                        IconData catIcon = Icons.help_outline;
                                        if (item['category'] == 'Emergency Medical Kits') catIcon = Icons.local_hospital;
                                        else if (item['category'] == 'Drinking Water') catIcon = Icons.water_drop;
                                        else if (item['category'] == 'Dry Food Rations') catIcon = Icons.fastfood;
                                        else if (item['category'] == 'Rescue Boats') catIcon = Icons.directions_boat;

                                        return ListTile(
                                          leading: Icon(catIcon, color: Colors.white),
                                          title: Text('Request #${item['requestId']} - ${item['category']}', style: const TextStyle(color: Colors.white)),
                                          subtitle: Text('Sent: $dateStr • Urgency: ${item['urgency'] ?? '?'}', style: const TextStyle(color: Colors.grey)),
                                          trailing: const Icon(Icons.info_outline, color: Colors.blueAccent),
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (dialogCtx) => AlertDialog(
                                                backgroundColor: Theme.of(context).colorScheme.surface,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                title: Text('Request #${item['requestId']} Details', style: const TextStyle(color: Colors.white)),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Name: ${item['name'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
                                                    Text('Category: ${item['category']}', style: const TextStyle(color: Colors.white70)),
                                                    Text('Urgency Level: ${item['urgency'] ?? 'N/A'}/10', style: const TextStyle(color: Colors.redAccent)),
                                                    const SizedBox(height: 10),
                                                    const Text('Message:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                                    Text(
                                                      item['message']?.isNotEmpty == true ? item['message'] : 'No message provided',
                                                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogCtx),
                                                    child: const Text('Close', style: TextStyle(color: Colors.grey)),
                                                  ),
                                                  ElevatedButton.icon(
                                                    icon: const Icon(Icons.my_location),
                                                    label: const Text('Live Tracking'),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                    onPressed: () {
                                                      Navigator.pop(dialogCtx); // close dialog
                                                      Navigator.pop(ctx); // close bottom sheet
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(requestId: item['requestId'])));
                                                    },
                                                  )
                                                ],
                                              )
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                      );
                    },
                    icon: const Icon(Icons.history, color: Colors.grey),
                    label: const Text('History', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
