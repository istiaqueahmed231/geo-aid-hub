import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'volunteer_mission_detail_screen.dart';

class VolunteerMissionsHistoryScreen extends StatefulWidget {
  final String uid;

  const VolunteerMissionsHistoryScreen({super.key, required this.uid});

  @override
  State<VolunteerMissionsHistoryScreen> createState() => _VolunteerMissionsHistoryScreenState();
}

class _VolunteerMissionsHistoryScreenState extends State<VolunteerMissionsHistoryScreen> {
  List<dynamic> _missions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMissions();
  }

  Future<void> _fetchMissions() async {
    try {
      final res = await http.get(
        Uri.parse('https://geo-aid-hub.onrender.com/api/volunteers/missions?uid=${widget.uid}'),
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _missions = data;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load completed missions';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error fetching missions';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COMPLETED MISSIONS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchMissions();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchMissions();
                        },
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                )
              : _missions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No Completed Missions Yet',
                            style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Missions assigned and completed by you will be archived here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchMissions,
                      color: Colors.blueAccent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _missions.length,
                        itemBuilder: (context, index) {
                          final mission = _missions[index];
                          final status = mission['Status'] ?? 'Completed';
                          final victimName = mission['VictimFullName'] ?? mission['RequestorName'] ?? 'Victim';
                          final rating = mission['Rating'];
                          final completedAt = mission['CompletedAt'] != null
                              ? mission['CompletedAt'].toString().replaceAll('T', ' ').split('.')[0]
                              : (mission['DispatchedAt'] != null
                                  ? mission['DispatchedAt'].toString().replaceAll('T', ' ').split('.')[0]
                                  : 'Recently');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151C2C),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '#${mission['RequestID']} • $victimName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.greenAccent, width: 1),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    'Supply: ${mission['DispatchedQuantity'] ?? 1} unit of ${mission['DispatchedItemName'] ?? mission['CategoryName'] ?? 'Supplies'}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Completed: $completedAt',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      const Spacer(),
                                      if (rating != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 16),
                                            const SizedBox(width: 2),
                                            Text(
                                              '$rating/5',
                                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VolunteerMissionDetailScreen(mission: mission),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
