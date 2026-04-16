import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'chat_screen.dart'; // We'll create this next

class TrackingScreen extends StatefulWidget {
  final int requestId;

  const TrackingScreen({super.key, required this.requestId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _requestData;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await http.get(Uri.parse('https://geo-aid-hub.onrender.com/api/requests/${widget.requestId}')); // Assuming production URL
      if (res.statusCode == 200) {
        setState(() {
          _requestData = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _requestData?['Status'] ?? 'Pending';
    final isDispatched = status == 'Dispatched';

    return Scaffold(
      appBar: AppBar(title: const Text('SOS Status')),
      body: Center(
        child: _requestData == null
            ? const CircularProgressIndicator(color: Colors.redAccent)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDispatched ? Icons.check_circle : Icons.hourglass_empty,
                    size: 80,
                    color: isDispatched ? Colors.greenAccent : Colors.orangeAccent
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isDispatched ? 'Rescue En Route!' : 'Finding Nearest Help...',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 20),
                  if (isDispatched) ...[
                    Text('Volunteer: ${_requestData?['VolunteerName'] ?? 'Unknown'}', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chat),
                      label: const Text('Contact Volunteer'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId)));
                      },
                    )
                  ]
                ],
              )
      )
    );
  }
}
