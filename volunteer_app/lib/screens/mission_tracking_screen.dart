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
                      child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                    ),
                    // Volunteer Location (Self)
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
                      const Icon(
                        Icons.track_changes,
                        color: Colors.greenAccent,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        status == 'Dispatched' ? 'Mission Active' : 'Mission Status: $status',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white24),
                  _buildDetailRow(Icons.person, 'Stranded Victim', requestorName),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.inventory, 'Transporting Payload', '$quantity $unit of $resourceName'),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text('Contact Victim', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId)));
                    },
                  )
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
