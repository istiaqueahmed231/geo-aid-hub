import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling $phoneNumber')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching dialer: $e');
    }
  }

  void _openFeedbackBottomSheet() {
    bool isSafe = true;
    int rating = 5;
    final TextEditingController noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Safety & Response Feedback',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Central Command has resolved this dispatch. Please confirm your safety status and rate the response team.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Safety Choice
              const Text('Are you and your family safe?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Yes, We are Safe')),
                      selected: isSafe,
                      selectedColor: Colors.green.withOpacity(0.3),
                      labelStyle: TextStyle(color: isSafe ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold),
                      onSelected: (val) => setModalState(() => isSafe = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Need More Help')),
                      selected: !isSafe,
                      selectedColor: Colors.red.withOpacity(0.3),
                      labelStyle: TextStyle(color: !isSafe ? Colors.redAccent : Colors.grey, fontWeight: FontWeight.bold),
                      onSelected: (val) => setModalState(() => isSafe = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Star Rating
              const Text('Rate Emergency Response Quality', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    iconSize: 36,
                    icon: Icon(
                      starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () => setModalState(() => rating = starIndex),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Notes Input
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Feedback Notes (Optional)',
                  hintText: 'e.g. Rescue team arrived quickly with supplies...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  prefixIcon: Icon(Icons.comment_outlined, color: Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 24),

              isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('SUBMIT SAFETY FEEDBACK', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          final res = await http.post(
                            Uri.parse('https://geo-aid-hub.onrender.com/api/requests/${widget.requestId}/feedback'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'isSafe': isSafe,
                              'rating': rating,
                              'note': noteController.text.trim(),
                            }),
                          );
                          if (res.statusCode == 200) {
                            if (mounted) {
                              Navigator.pop(ctx); // Close modal
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Feedback Submitted! Thank you.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchStatus(); // Refresh local state
                            }
                          }
                        } catch (e) {
                          debugPrint('Error submitting feedback: $e');
                        } finally {
                          if (mounted) setModalState(() => isSubmitting = false);
                        }
                      },
                    ),
            ],
          ),
        ),
      ),
    ),
  );
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
    final volPhone = _requestData?['VolunteerPhone'] ?? 'Not provided';
    final volAddress = _requestData?['VolunteerAddress'] ?? 'Base Station';
    final volRole = _requestData?['VolunteerRole'] ?? 'First Responder';
    final volAge = _requestData?['VolunteerAge'] ?? '';
    final volGender = _requestData?['VolunteerGender'] ?? '';

    final resourceName = _requestData?['DispatchedCategoryName'] ?? 'Resources';
    final quantity = _requestData?['DispatchedQuantity'] ?? 0;
    final unit = _requestData?['UnitOfMeasure'] ?? 'units';

    final isCompleted = status == 'Completed';
    final isResolved = status == 'Resolved';
    final hasFeedback = _requestData?['Rating'] != null || _requestData?['FeedbackNote'] != null;

    return Scaffold(
        appBar: AppBar(title: Text('MISSION #${widget.requestId}')),
        body: _requestData == null
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : Column(
          children: [
            Expanded(
              flex: 4,
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
                        child: Icon(
                          isCompleted || isResolved ? Icons.check_circle : Icons.my_location,
                          color: isCompleted || isResolved ? Colors.greenAccent : Colors.redAccent,
                          size: 40,
                        ),
                      ),
                      if (volLat != null && volLon != null && !isCompleted && !isResolved)
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
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: isCompleted || isResolved
                                  ? Colors.greenAccent.withOpacity(0.15)
                                  : isDispatched
                                      ? Colors.orangeAccent.withOpacity(0.1)
                                      : Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isCompleted || isResolved
                                      ? Colors.greenAccent.withOpacity(0.4)
                                      : isDispatched
                                          ? Colors.orangeAccent.withOpacity(0.3)
                                          : Colors.transparent)
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCompleted || isResolved
                                    ? Icons.task_alt
                                    : isDispatched
                                        ? Icons.radar
                                        : Icons.satellite_alt,
                                color: isCompleted || isResolved
                                    ? Colors.greenAccent
                                    : isDispatched
                                        ? Colors.orangeAccent
                                        : Colors.grey,
                                size: 30,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  isResolved
                                      ? 'DISPATCH RESOLVED & SAFE'
                                      : isCompleted
                                          ? 'RESCUE COMPLETED - YOU ARE SAFE'
                                          : isDispatched
                                              ? 'Rescue Unit En Route'
                                              : 'Broadcasting Signal...',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted || isResolved
                                          ? Colors.greenAccent
                                          : isDispatched
                                              ? Colors.orangeAccent
                                              : Colors.white
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isResolved) ...[
                          _buildDetailRow(
                            Icons.verified_user,
                            'Status',
                            'Resolved by Central Command',
                            subtitle: 'Safety verification active',
                          ),
                          const SizedBox(height: 12),
                          if (hasFeedback) ...[
                            _buildDetailRow(
                              Icons.star,
                              'Response Rating',
                              '${_requestData!['Rating']} / 5 Stars',
                              subtitle: _requestData!['FeedbackNote'] != null && _requestData!['FeedbackNote'].toString().isNotEmpty
                                  ? 'Note: ${_requestData!['FeedbackNote']}'
                                  : 'Safety Status: Confirmed Safe',
                            ),
                          ] else ...[
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.rate_review, size: 22),
                              label: const Text('CONFIRM SAFETY & RATE RESPONSE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => _openFeedbackBottomSheet(),
                            ),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('CLOSE TRACKING'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
                          )
                        ] else if (isCompleted) ...[
                          _buildDetailRow(
                            Icons.verified,
                            'Assigned Rescuer',
                            '$volName ($volRole)',
                            subtitle: 'Status: Mission Accomplished',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.inventory_2_outlined,
                            'Delivered Payload',
                            '$quantity $unit of $resourceName',
                          ),
                          if (hasFeedback) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.star,
                              'Response Rating',
                              '${_requestData!['Rating']} / 5 Stars',
                              subtitle: _requestData!['FeedbackNote'] != null && _requestData!['FeedbackNote'].toString().isNotEmpty
                                  ? 'Note: ${_requestData!['FeedbackNote']}'
                                  : 'Safety Status: Confirmed Safe',
                            ),
                          ] else ...[
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.rate_review),
                              label: const Text('LEAVE FEEDBACK FOR RESCUERS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => _openFeedbackBottomSheet(),
                            ),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('CLOSE MISSION'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
                          )
                        ] else if (isDispatched) ...[
                          _buildDetailRow(
                            Icons.badge_outlined,
                            'Assigned Rescuer',
                            '$volName ($volRole)',
                            subtitle: volAge.toString().isNotEmpty ? '$volAge y/o • $volGender' : null,
                          ),
                          const SizedBox(height: 12),

                          _buildDetailRow(
                            Icons.phone_in_talk_outlined,
                            'Rescuer Phone',
                            volPhone,
                            actionWidget: volPhone != 'Not provided'
                                ? IconButton(
                                    icon: const Icon(Icons.call, color: Colors.greenAccent),
                                    onPressed: () => _makePhoneCall(volPhone),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),

                          _buildDetailRow(
                            Icons.home_outlined,
                            'Rescuer Home Base / Address',
                            volAddress,
                          ),
                          const SizedBox(height: 12),

                          _buildDetailRow(
                            Icons.inventory_2_outlined,
                            'Incoming Supplies',
                            '$quantity $unit of $resourceName',
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('ESTABLISH CHAT COMMS'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId)));
                            },
                          )
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Center(
                              child: Text(
                                'Awaiting confirmation from central command.',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                )
            )
          ],
        )
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {String? subtitle, Widget? actionWidget}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(icon, color: Colors.orangeAccent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        if (actionWidget != null) actionWidget,
      ],
    );
  }
}
