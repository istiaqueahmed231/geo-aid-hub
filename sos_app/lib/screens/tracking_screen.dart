import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:async';
import 'chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final status = _requestData?['Status'] ?? 'Pending';
    final isDispatched = status == 'Dispatched';
    
    final sosLat = _requestData?['Latitude'] != null ? (_requestData!['Latitude'] as num).toDouble() : 0.0;
    final sosLon = _requestData?['Longitude'] != null ? (_requestData!['Longitude'] as num).toDouble() : 0.0;

    final volLat = _requestData?['VolLat'] != null ? (_requestData!['VolLat'] as num).toDouble() : null;
    final volLon = _requestData?['VolLon'] != null ? (_requestData!['VolLon'] as num).toDouble() : null;

    final volName = _requestData?['VolunteerName'] ?? 'Unknown Rescuer';
    final resourceName = _requestData?['DispatchedCategoryName'] ?? 'Resources';
    final quantity = _requestData?['DispatchedQuantity'] ?? 0;
    final unit = _requestData?['UnitOfMeasure'] ?? 'units';

    return Scaffold(
      appBar: AppBar(title: Text('Request #${widget.requestId}')),
      body: _requestData == null
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              children: [
                Expanded(
                  flex: 5,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: volLat != null && volLon != null ? LatLng(volLat, volLon) : LatLng(sosLat, sosLon),
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          // SOS Location
                          Marker(
                            point: LatLng(sosLat, sosLon),
                            width: 80,
                            height: 80,
                            child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                          ),
                          // Volunteer Location
                          if (volLat != null && volLon != null)
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
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -5))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDispatched ? Icons.check_circle : Icons.hourglass_empty,
                              color: isDispatched ? Colors.greenAccent : Colors.orangeAccent,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isDispatched ? 'Rescue En Route' : 'Finding Nearest Help...',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const Divider(height: 32, color: Colors.white24),
                        if (isDispatched) ...[
                          _buildDetailRow(Icons.person, 'Volunteer', volName),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.medical_services, 'Deploying', '$quantity $unit of $resourceName'),
                          const Spacer(),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.chat),
                            label: const Text('Contact Volunteer', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId)));
                            },
                          )
                        ] else ...[
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Awaiting Command Center Dispatch',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              )
                            )
                          )
                        ]
                      ],
                    ),
                  )
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
