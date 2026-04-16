import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final int requestId;

  const ChatScreen({super.key, required this.requestId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // Fallback polling since flutter package socket.io-client might not be installed
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:3000/api/messages/${widget.requestId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _messages = data;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch messages: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    
    // As a workaround since we don't have socket.io client easily in standard flutter http, 
    // we would actually need a POST /api/messages route. I will add one on the backend, 
    // or just simulate it here.
    // Assuming backend will have a POST /api/messages route
    try {
      await http.post(
        Uri.parse('http://localhost:3000/api/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestId': widget.requestId,
          'senderRole': 'Volunteer',
          'senderId': 'Vol', // using 'Vol' as placeholder
          'text': _msgController.text
        })
      );
      _msgController.clear();
      _fetchMessages();
    } catch (e) {
      debugPrint("Failed to send: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mission Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isMe = msg['SenderRole'] == 'Volunteer';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.green[800] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['SenderRole'], style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(msg['MessageText'], style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  )
                );
              }
            )
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(hintText: 'Type message...'),
                  )
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: _sendMessage,
                )
              ],
            )
          )
        ],
      )
    );
  }
}
