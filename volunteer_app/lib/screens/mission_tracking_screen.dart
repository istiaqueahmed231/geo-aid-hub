import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:async';
import 'chat_screen.dart';

class MissionTrackingScreen extends StatefulWidget {
  final int requestId;

  const MissionTrackingScreen({super.key, required this.requestId});

  @override
  State<MissionTrackingScreen> createState() => _MissionTrackingScreenState();
}

class _MissionTrackingScreenState extends State<MissionTrackingScreen> {
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
      final res = await http.get(Uri.parse('https://geo-aid-hub.onrender.com/api/requests/${widget.requestId}')); 
      if (res.statusCode == 200) {
        setState(() {
          _requestData = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch status: $e");
    }
  }

  bool _isSubmitting = false;

  Future<void> _completeMission() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text('Complete Mission?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Confirm that you have reached the spot and successfully delivered rescue assistance to the victim.\n\nThis will mark the request as Completed and set your status back to Available.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, MARK COMPLETED', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/requests/${widget.requestId}/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': widget.requestId}),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Mission Marked as Completed! You are now Available.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(res.body)['error'] ?? 'Failed to complete mission.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $err'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requestData == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Mission #${widget.requestId}')),
        body: const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
      );
    }

    final sosLat = _requestData?['Latitude'] != null ? double.tryParse(_requestData!['Latitude'].toString()) ?? 0.0 : 0.0;
    final sosLon = _requestData?['Longitude'] != null ? double.tryParse(_requestData!['Longitude'].toString()) ?? 0.0 : 0.0;

    final volLat = _requestData?['VolLat'] != null ? double.tryParse(_requestData!['VolLat'].toString()) : null;
    final volLon = _requestData?['VolLon'] != null ? double.tryParse(_requestData!['VolLon'].toString()) : null;

    final requestorName = _requestData?['RequestorName'] ?? 'Unknown Victim';
    final resourceName = _requestData?['DispatchedCategoryName'] ?? 'Resources';
    final quantity = _requestData?['DispatchedQuantity'] ?? 0;
    final unit = _requestData?['UnitOfMeasure'] ?? 'units';
    final status = _requestData?['Status'] ?? 'Unknown';
    final isCompleted = status == 'Completed';

    return Scaffold(
      appBar: AppBar(title: Text('Mission #${widget.requestId}')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(sosLat, sosLon),
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    // SOS Location (Victim)
                    Marker(
                      point: LatLng(sosLat, sosLon),
                      width: 80,
                      height: 80,
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.location_on,
                        color: isCompleted ? Colors.greenAccent : Colors.redAccent,
                        size: 40,
                      ),
                    ),
                    // Volunteer Location (Self)
                    if (volLat != null && volLon != null && !isCompleted)
                      Marker(
                        point: LatLng(volLat, volLon),
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.directions_run, color: Colors.greenAccent, size: 40),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -5))]
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.task_alt : Icons.track_changes,
                          color: isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isCompleted ? 'Mission Completed' : (status == 'Dispatched' ? 'Mission Active' : 'Status: $status'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white24),
                    _buildDetailRow(Icons.person, 'Stranded Victim', requestorName),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.inventory, 'Transporting Payload', '$quantity $unit of $resourceName'),
                    const SizedBox(height: 24),

                    if (!isCompleted) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.chat),
                              label: const Text('Contact Victim'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.greenAccent,
                                side: const BorderSide(color: Colors.greenAccent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 22),
                              label: const Text(
                                'MARK MISSION AS COMPLETED',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _completeMission,
                            ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.greenAccent, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Mission accomplished! Relief supplies delivered and logged in central command.',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          )
        ],
      )
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }
}
