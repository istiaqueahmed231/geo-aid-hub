import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VictimRequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;

  const VictimRequestDetailScreen({super.key, required this.request});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orangeAccent;
      case 'Dispatched':
        return Colors.blueAccent;
      case 'Completed':
        return Colors.greenAccent;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = request['Status'] ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final volunteerName = request['VolunteerName'];
    final volunteerPhone = request['VolunteerPhone'];
    final categoryName = request['CategoryName'] ?? 'General SOS';
    final urgencyScore = request['UrgencyScore'] ?? 5;
    final message = request['ShortMessage'];

    final dispatchedItem = request['DispatchedItemName'];
    final dispatchedQty = request['DispatchedQuantity'];

    final rating = request['Rating'];
    final isSafe = request['IsSafe'];
    final note = request['FeedbackNote'];

    return Scaffold(
      appBar: AppBar(
        title: Text('OPERATION #${request['RequestID']} DETAILS'),
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
                          'REQUEST #${request['RequestID']}',
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

              // SHORT MESSAGE
              if (message != null && message.toString().trim().isNotEmpty) ...[
                _buildSectionHeader('Emergency Message'),
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
                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // DISPATCHED VOLUNTEER & SUPPLIES
              if (volunteerName != null) ...[
                _buildSectionHeader('Assigned Rescue Responder'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151C2C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  volunteerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (volunteerPhone != null)
                                  Text(
                                    volunteerPhone,
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                          if (volunteerPhone != null)
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.greenAccent),
                              onPressed: () => _makePhoneCall(volunteerPhone),
                            ),
                        ],
                      ),
                      if (dispatchedItem != null) ...[
                        const Divider(color: Colors.white10, height: 24),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 13),
                                  children: [
                                    const TextSpan(text: 'Dispatched Supply: ', style: TextStyle(color: Colors.grey)),
                                    TextSpan(
                                      text: '${dispatchedQty ?? 1} unit of $dispatchedItem',
                                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // TIMELINE STAMPS
              _buildSectionHeader('Operation Timeline'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151C2C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildTimelineRow('Broadcast Created', request['CreatedAt']),
                    if (request['DispatchedAt'] != null)
                      _buildTimelineRow('Volunteer Dispatched', request['DispatchedAt']),
                    if (request['CompletedAt'] != null)
                      _buildTimelineRow('Mission Completed', request['CompletedAt']),
                    if (request['ResolvedAt'] != null)
                      _buildTimelineRow('Dispatch Resolved', request['ResolvedAt']),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // FEEDBACK & RATING (IF RESOLVED/COMPLETED)
              if (rating != null || isSafe != null) ...[
                _buildSectionHeader('Your Response Rating & Feedback'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSafe == 1 ? '🛡️ Confirmed Safe' : '⚠️ Needed Assistance',
                            style: const TextStyle(
                              color: Colors.greenAccent,
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
                          style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
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
        color: Colors.redAccent,
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
