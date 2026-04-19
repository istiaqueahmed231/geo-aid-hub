import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'mission_tracking_screen.dart';
import 'login_screen.dart';
import '../main.dart' show showVolunteerNotification;

class DashboardScreen extends StatefulWidget {
  final String uid;

  const DashboardScreen({super.key, required this.uid});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isAvailable = false;
  List<dynamic> _sosRequests = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchRequests());

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        showVolunteerNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['requestId'] != null) {
        final requestId = int.parse(message.data['requestId'].toString());
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MissionTrackingScreen(requestId: requestId),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    try {
      final res = await http.get(Uri.parse('https://geo-aid-hub.onrender.com/api/requests'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _sosRequests = data;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch requests: $e");
    }
  }

  Future<void> _toggleAvailability(bool val) async {
    setState(() => _isAvailable = val);

    if (val) {
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await http.post(
            Uri.parse('https://geo-aid-hub.onrender.com/api/volunteer/location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': widget.uid,
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'status': 'Available'
            })
        );
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Available. Location tracking active.')));
      } catch (e) {
        setState(() => _isAvailable = false);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not obtain location: $e')));
      }
    } else {
      try {
        await http.post(
            Uri.parse('https://geo-aid-hub.onrender.com/api/volunteer/location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': widget.uid,
              'status': 'Unavailable'
            })
        );
      } catch (e) {}
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_me');
    await prefs.remove('saved_uid');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('DISPATCH DASHBOARD'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _logout,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.greenAccent),
              onPressed: _fetchRequests,
            )
          ],
        ),
        body: Column(
          children: [
            // Sleek Availability Banner
            Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isAvailable ? Colors.greenAccent.withOpacity(0.5) : Colors.white10),
                    boxShadow: [
                      BoxShadow(
                          color: _isAvailable ? Colors.greenAccent.withOpacity(0.05) : Colors.transparent,
                          blurRadius: 20,
                          spreadRadius: 2
                      )
                    ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                            _isAvailable ? Icons.sensors : Icons.sensors_off,
                            color: _isAvailable ? Colors.greenAccent : Colors.grey
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dispatch Status', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            Text(
                                _isAvailable ? 'ACTIVE & TRACKING' : 'OFF DUTY',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isAvailable ? Colors.greenAccent : Colors.white
                                )
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      activeColor: Colors.black,
                      activeTrackColor: Colors.greenAccent,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white10,
                      value: _isAvailable,
                      onChanged: _toggleAvailability,
                    )
                  ],
                )
            ),

            // Mission List
            Expanded(
                child: _sosRequests.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.done_all, size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('No Active SOS Requests', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
                    : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _sosRequests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final req = _sosRequests[index];
                      final isDispatched = req['Status'] == 'Dispatched';

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDispatched ? Colors.greenAccent.withOpacity(0.3) : Colors.white10,
                              width: 1
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Category Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text(
                                      req['CategoryName'].toString().toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                                    ),
                                  ),
                                  // Urgency Badge
                                  Row(
                                    children: [
                                      const Icon(Icons.local_fire_department, size: 16, color: Colors.orangeAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'URGENCY: ${req['UrgencyScore']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.white10,
                                    radius: 20,
                                    child: const Icon(Icons.person, color: Colors.white70),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req['RequestorName'],
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mission ID: #${req['RequestID']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Action Area
                              SizedBox(
                                width: double.infinity,
                                child: isDispatched
                                    ? ElevatedButton.icon(
                                  icon: const Icon(Icons.navigation),
                                  label: const Text('OPEN MISSION'),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => MissionTrackingScreen(requestId: req['RequestID'])));
                                  },
                                )
                                    : OutlinedButton.icon(
                                  icon: const Icon(Icons.hourglass_empty, color: Colors.grey),
                                  label: const Text('AWAITING DISPATCH', style: TextStyle(color: Colors.grey)),
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 14)
                                  ),
                                  onPressed: null,
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    }
                )
            )
          ],
        )
    );
  }
}
```

Here's a summary of every change made, exactly as specified:

1. **New imports** (lines 6–9) — Added `shared_preferences`, `firebase_messaging`, `login_screen.dart`, and the `showVolunteerNotification` show-import from `main.dart`.

2. **`initState()` FCM listeners** (lines 32–48):
   - `FirebaseMessaging.onMessage` — fires `showVolunteerNotification(message)` when the incoming message carries a notification payload (i.e. app is in foreground).
   - `FirebaseMessaging.onMessageOpenedApp` — when the user taps a notification that opened the app from background, it parses `message.data['requestId']` as an `int` and pushes `MissionTrackingScreen`.

3. **`_logout()` method** (lines 99–109) — Awaits `SharedPreferences.getInstance()`, removes both `remember_me` and `saved_uid`, then calls `Navigator.pushAndRemoveUntil` with `LoginScreen`, clearing the entire back-stack via the `(route) => false` predicate.

4. **AppBar `actions`** (lines 114–121) — The logout `IconButton` (`Icons.logout`, `Colors.redAccent`, calls `_logout`) is placed **before** the existing refresh button, exactly as requested.
