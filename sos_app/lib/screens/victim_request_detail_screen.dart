import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_screen.dart';

class VictimRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const VictimRequestDetailScreen({super.key, required this.request});

  @override
  State<VictimRequestDetailScreen> createState() => _VictimRequestDetailScreenState();
}

class _VictimRequestDetailScreenState extends State<VictimRequestDetailScreen> {
  late Map<String, dynamic> _requestData;
  bool _isSubmittingFeedback = false;

  @override
  void initState() {
    super.initState();
    _requestData = Map<String, dynamic>.from(widget.request);
  }

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

  Future<void> _openFeedbackDialog() async {
    int selectedRating = 5;
    bool isSafeConfirmed = true;
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rate Rescue Response',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please confirm your safety status and rate the rescue team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(
                          starVal <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setModalState(() {
                            selectedRating = starVal;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Safety Checkbox
                  SwitchListTile(
                    activeColor: Colors.greenAccent,
                    title: const Text('I am in a safe location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    value: isSafeConfirmed,
                    onChanged: (val) {
                      setModalState(() {
                        isSafeConfirmed = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Feedback Note
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Feedback Note (Optional)',
                      hintText: 'Share any notes for the dispatch team...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.rate_review, color: Colors.greenAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      await _submitFeedback(selectedRating, isSafeConfirmed, noteController.text.trim());
                    },
                    child: const Text('SUBMIT FEEDBACK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitFeedback(int rating, bool isSafe, String note) async {
    final requestId = _requestData['RequestID'];
    setState(() => _isSubmittingFeedback = true);

    try {
      final res = await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/requests/$requestId/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'isSafe': isSafe ? 1 : 0,
          'rating': rating,
          'note': note,
        }),
      );

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _requestData['Rating'] = rating;
          _requestData['IsSafe'] = isSafe ? 1 : 0;
          _requestData['FeedbackNote'] = note;
          _isSubmittingFeedback = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Feedback submitted successfully! Thank you.')),
        );
      } else if (mounted) {
        setState(() => _isSubmittingFeedback = false);
        final err = jsonDecode(res.body)['error'] ?? 'Submission failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $err')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _requestData;
    final status = req['Status'] ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final volunteerName = req['VolunteerName'];
    final volunteerPhone = req['VolunteerPhone'];
    final categoryName = req['CategoryName'] ?? 'General SOS';
    final urgencyScore = req['UrgencyScore'] ?? 5;
    final message = req['ShortMessage'];

    final dispatchedItem = req['DispatchedItemName'];
    final dispatchedQty = req['DispatchedQuantity'];

    final rating = req['Rating'];
    final isSafe = req['IsSafe'];
    final note = req['FeedbackNote'];

    final isAssigned = volunteerName != null || status == 'Dispatched' || status == 'Completed' || status == 'Resolved';

    return Scaffold(
      appBar: AppBar(
        title: Text('OPERATION #${req['RequestID']} DETAILS'),
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
                          'REQUEST #${req['RequestID']}',
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
                        Expanded(
                          child: Text(
                            categoryName,
                            style: const TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
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

              // DISPATCHED VOLUNTEER & CHAT / CALL BUTTONS
              if (isAssigned) ...[
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
                                  volunteerName ?? 'Rescue Responder Assigned',
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
                          // Chat Button
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                            tooltip: 'Chat with Volunteer',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(requestId: req['RequestID']),
                                ),
                              );
                            },
                          ),
                          if (volunteerPhone != null)
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.greenAccent),
                              tooltip: 'Call Volunteer',
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
                    _buildTimelineRow('Broadcast Created', req['CreatedAt']),
                    if (req['DispatchedAt'] != null)
                      _buildTimelineRow('Volunteer Dispatched', req['DispatchedAt']),
                    if (req['CompletedAt'] != null)
                      _buildTimelineRow('Mission Completed', req['CompletedAt']),
                    if (req['ResolvedAt'] != null)
                      _buildTimelineRow('Dispatch Resolved', req['ResolvedAt']),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // FEEDBACK & RATING (IF RESOLVED/COMPLETED)
              if (status == 'Completed' || status == 'Resolved') ...[
                _buildSectionHeader('Response Rating & Safety Status'),
                const SizedBox(height: 8),
                if (rating != null || isSafe != null) ...[
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
                ] else ...[
                  // Show Rate Button
                  _isSubmittingFeedback
                      ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.rate_review),
                          label: const Text('RATE RESPONSE & CONFIRM SAFETY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _openFeedbackDialog,
                        ),
                ],
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
