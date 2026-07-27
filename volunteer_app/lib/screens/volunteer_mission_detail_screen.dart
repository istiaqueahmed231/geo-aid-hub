import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VolunteerMissionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> mission;

  const VolunteerMissionDetailScreen({super.key, required this.mission});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.emeraldAccent.shade400;
      case 'Resolved':
        return Colors.greenAccent.shade700;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = mission['Status'] ?? 'Completed';
    final statusColor = _getStatusColor(status);
    final victimName = mission['VictimFullName'] ?? mission['RequestorName'] ?? 'Victim';
    final victimPhone = mission['VictimPhone'];
    final victimAddress = mission['VictimAddress'] ?? mission['AreaName'] ?? 'Rescue Location';
    final mobilityStatus = mission['MobilityStatus'] ?? 'Fully Mobile';
    final emergencyContactName = mission['EmergencyContactName'];
    final emergencyContactPhone = mission['EmergencyContactPhone'];

    final categoryName = mission['CategoryName'] ?? 'General Emergency';
    final urgencyScore = mission['UrgencyScore'] ?? 5;
    final message = mission['ShortMessage'];

    final dispatchedItem = mission['DispatchedItemName'];
    final dispatchedQty = mission['DispatchedQuantity'];

    final rating = mission['Rating'];
    final isSafe = mission['IsSafe'];
    final note = mission['FeedbackNote'];

    return Scaffold(
      appBar: AppBar(
        title: Text('MISSION #${mission['RequestID']} REPORT'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STATUS & URGENCY CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF151C2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MISSION #${mission['RequestID']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.category_outlined, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(categoryName, style: const TextStyle(color: Colors.white70)),
                        const Spacer(),
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Urgency: $urgencyScore/10',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // VICTIM & RESCUE LOCATION
              _buildSectionHeader('Victim & Location Information'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151C2C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                victimName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (victimPhone != null)
                                Text(
                                  victimPhone,
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        if (victimPhone != null)
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.greenAccent),
                            onPressed: () => _makePhoneCall(victimPhone),
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            victimAddress,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.accessible, color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Mobility: $mobilityStatus',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (emergencyContactName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.contact_phone_outlined, color: Colors.blueAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Emergency Contact: $emergencyContactName (${emergencyContactPhone ?? "N/A"})',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SHORT MESSAGE
              if (message != null && message.toString().trim().isNotEmpty) ...[
                _buildSectionHeader('Emergency Request Note'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"$message"',
                    style: const TextStyle(color: Colors.white70, italic: true),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // DISPATCHED ITEM DETAILS
              if (dispatchedItem != null) ...[
                _buildSectionHeader('Dispatched Supplies'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151C2C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${dispatchedQty ?? 1} unit of $dispatchedItem',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // TIMELINE
              _buildSectionHeader('Mission Timeline'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151C2C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildTimelineRow('Assigned & Dispatched', mission['DispatchedAt']),
                    if (mission['CompletedAt'] != null)
                      _buildTimelineRow('Mission Completed', mission['CompletedAt']),
                    if (mission['ResolvedAt'] != null)
                      _buildTimelineRow('Dispatch Resolved', mission['ResolvedAt']),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // VICTIM RATING & FEEDBACK
              if (rating != null || isSafe != null) ...[
                _buildSectionHeader('Victim Safety Confirmation & Rating'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.emerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.emeraldAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSafe == 1 ? '🛡️ Victim Confirmed Safe' : '⚠️ Needed Extra Aid',
                            style: const TextStyle(
                              color: Colors.emeraldAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (rating != null)
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < (rating as int) ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (note != null && note.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '"$note"',
                          style: const TextStyle(color: Colors.white70, italic: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      ),
    );
  }

  Widget _buildTimelineRow(String label, dynamic timestamp) {
    String formattedTime = timestamp != null ? timestamp.toString().replaceAll('T', ' ').split('.')[0] : 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
