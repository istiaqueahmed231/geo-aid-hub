import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'mission_tracking_screen.dart';

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
          Uri.parse('http://localhost:3000/api/volunteer/location'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': widget.uid,
            'status': 'Unavailable' // Assume API ignores missing lat/lon to just update status
          })
        );
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer Dashboard')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available for Dispatch?', style: TextStyle(fontSize: 16)),
                Switch(
                  activeThumbColor: Colors.greenAccent,
                  value: _isAvailable,
                  onChanged: _toggleAvailability,
                )
              ],
            )
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sosRequests.length,
              itemBuilder: (ctx, index) {
                final req = _sosRequests[index];
                final isDispatched = req['Status'] == 'Dispatched';
                return Card(
                  color: isDispatched ? Colors.white10 : const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('SOS: ${req['RequestorName']}'),
                    subtitle: Text('${req['CategoryName']} - Urgency: ${req['UrgencyScore']}'),
                    trailing: isDispatched 
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => MissionTrackingScreen(requestId: req['RequestID'])));
                            },
                            child: const Text('Open Mission', style: TextStyle(color: Colors.black)),
                          )
                        : const Text('Pending...', style: TextStyle(color: Colors.redAccent)),
                  )
                );
              }
            )
          )
        ],
      )
    );
  }
}
