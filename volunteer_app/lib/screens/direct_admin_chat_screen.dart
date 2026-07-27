import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DirectAdminChatScreen extends StatefulWidget {
  final String uid;

  const DirectAdminChatScreen({super.key, required this.uid});

  @override
  State<DirectAdminChatScreen> createState() => _DirectAdminChatScreenState();
}

class _DirectAdminChatScreenState extends State<DirectAdminChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  int? _conversationId;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      final res = await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/conversations/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initiatorRole': 'Volunteer',
          'initiatorIdentifier': widget.uid,
          'targetRole': 'Admin',
          'targetIdentifier': 'admin@geo-aid.org',
          'title': 'Admin Support'
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _conversationId = data['conversationId'];
        await _fetchMessages();

        _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
      }
    } catch (e) {
      debugPrint("Error starting chat: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages() async {
    if (_conversationId == null) return;

    try {
      final res = await http.get(
        Uri.parse('https://geo-aid-hub.onrender.com/api/conversations/$_conversationId/messages'),
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _messages = data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _msgController.clear();

    try {
      await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/conversations/$_conversationId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderRole': 'Volunteer',
          'senderIdentifier': widget.uid,
          'senderName': 'Volunteer',
          'messageText': text
        }),
      );

      await _fetchMessages();
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN COMMAND SUPPORT'),
        backgroundColor: const Color(0xFF151C2C),
      ),
      body: Container(
        color: const Color(0xFF0B0F19),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF151C2C),
              child: Row(
                children: const [
                  Icon(Icons.verified_user, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Direct communication channel with Command Center',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Send a message to Command HQ.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['SenderID'] == widget.uid;

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blueAccent.withOpacity(0.25) : const Color(0xFF151C2C),
                                  border: Border.all(
                                    color: isMe ? Colors.blueAccent : Colors.white10,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMe ? 'You' : 'Admin Command',
                                      style: TextStyle(
                                        color: isMe ? Colors.blueAccent : Colors.amberAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      msg['MessageText'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF151C2C),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0B0F19),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
