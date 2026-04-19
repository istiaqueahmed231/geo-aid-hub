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

    final sosLat = _requestData?['Latitude'] != null ? double.tryParse(_requestData!['Latitude'].toString()) ?? 0.0 : 0.0;
    final sosLon = _requestData?['Longitude'] != null ? double.tryParse(_requestData!['Longitude'].toString()) ?? 0.0 : 0.0;

    final volLat = _requestData?['VolLat'] != null ? double.tryParse(_requestData!['VolLat'].toString()) : null;
    final volLon = _requestData?['VolLon'] != null ? double.tryParse(_requestData!['VolLon'].toString()) : null;

    final volName = _requestData?['VolunteerName'] ?? 'Unknown Rescuer';
    final resourceName = _requestData?['DispatchedCategoryName'] ?? 'Resources';
    final quantity = _requestData?['DispatchedQuantity'] ?? 0;
    final unit = _requestData?['UnitOfMeasure'] ?? 'units';

    return Scaffold(
        appBar: AppBar(title: Text('MISSION #${widget.requestId}')),
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
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(sosLat, sosLon),
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.my_location, color: Colors.redAccent, size: 40),
                      ),
                      if (volLat != null && volLon != null)
                        Marker(
                          point: LatLng(volLat, volLon),
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.navigation, color: Colors.orangeAccent, size: 40),
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
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, -5)
                        )
                      ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: isDispatched ? Colors.orangeAccent.withOpacity(0.1) : Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDispatched ? Colors.orangeAccent.withOpacity(0.3) : Colors.transparent)
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDispatched ? Icons.radar : Icons.satellite_alt,
                              color: isDispatched ? Colors.orangeAccent : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                isDispatched ? 'Rescue Unit En Route' : 'Broadcasting Signal...',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDispatched ? Colors.orangeAccent : Colors.white
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isDispatched) ...[
                        _buildDetailRow(Icons.badge, 'Dispatched Rescuer', volName),
                        const SizedBox(height: 16),
                        _buildDetailRow(Icons.inventory_2, 'Incoming Supplies', '$quantity $unit of $resourceName'),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('ESTABLISH COMMS'),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId)));
                          },
                        )
                      ] else ...[
                        const Expanded(
                            child: Center(
                                child: Text(
                                  'Awaiting confirmation from central command.',
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(icon, color: Colors.grey, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}
