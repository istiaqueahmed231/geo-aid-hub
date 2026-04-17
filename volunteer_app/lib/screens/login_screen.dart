import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      const apiKey = "AIzaSyDwnQj_7B2-cp7qz4wVLOW92AGMXBAuA9Q";
      final res = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
        body: jsonEncode({
          'email': _emailController.text,
          'password': _pwController.text,
          'returnSecureToken': true
        }),
        headers: {'Content-Type': 'application/json'}
      );

      final data = jsonDecode(res.body);
      if (data['error'] != null) {
        throw Exception(data['error']['message']);
      }
      
      // Successfully logged in, navigate
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(uid: data['localId'])),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Volunteer Login')),
        // 1. Wrap the Padding in a Center and SingleChildScrollView
        body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.greenAccent),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email')
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _pwController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.greenAccent)
                      : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)
                    ),
                    child: const Text('LOGIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
                ],
              )
          ),
        )
    );
  }
}
