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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B0F19), Color(0xFF111827)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Icon Effect
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 10,
                            )
                          ]
                      ),
                      child: const Icon(Icons.security_rounded, size: 80, color: Colors.greenAccent),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'VOLUNTEER PORTAL',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Authenticate to access missions',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 48),

                    TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.greenAccent),
                        )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pwController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.greenAccent),
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                          : ElevatedButton(
                        onPressed: _login,
                        child: const Text('SECURE LOGIN'),
                      ),
                    )
                  ],
                )
            ),
          ),
        )
    );
  }
}