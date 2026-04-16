import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // Production URL on Render
  static const String _sosUrl = 'https://geo-aid-hub.onrender.com/api/sos';

  static Future<http.Response> sendSosAlert(Map<String, dynamic> data) async {
    return await http.post(
      Uri.parse(_sosUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }
}
