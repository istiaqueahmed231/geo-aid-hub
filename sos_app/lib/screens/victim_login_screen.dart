import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'victim_profile_setup_screen.dart';
import 'sos_portal.dart';

class VictimLoginScreen extends StatefulWidget {
  const VictimLoginScreen({super.key});

  @override
  State<VictimLoginScreen> createState() => _VictimLoginScreenState();
}

class _VictimLoginScreenState extends State<VictimLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _checkProfileAndNavigate(User user) async {
    try {
      final res = await http.get(
        Uri.parse('https://geo-aid-hub.onrender.com/api/victims/me?uid=${user.uid}'),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // Profile exists, proceed to SOS Portal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SosPortal()),
        );
      } else {
        // Profile doesn't exist, go to profile setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VictimProfileSetupScreen(authUid: user.uid, email: user.email),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // On network error fallback to profile setup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VictimProfileSetupScreen(authUid: user.uid, email: user.email),
        ),
      );
    }
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential creds;
      if (_isSignUp) {
        creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (creds.user != null) {
        await _checkProfileAndNavigate(creds.user!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Authentication failed.');
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 72,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'GEO-AID SOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? 'Create a Victim Emergency Account' : 'Sign in to Emergency Dispatch Portal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 36),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 24),

                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                    : ElevatedButton(
                        onPressed: _submitAuth,
                        child: Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN'),
                      ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Register Now",
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
