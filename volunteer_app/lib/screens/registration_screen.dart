import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedRole = 'First Responder';
  bool _isLoading = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _roleOptions = [
    'First Responder',
    'Medical Aid',
    'Logistics',
    'Rescue Driver',
    'Supply Coordinator',
    'General'
  ];

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      const apiKey = 'AIzaSyDwnQj_7B2-cp7qz4wVLOW92AGMXBAuA9Q';
      // 1. Create Firebase Auth user
      final authRes = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _pwController.text,
          'returnSecureToken': true,
        }),
      );

      final authData = jsonDecode(authRes.body);
      if (authData['error'] != null) {
        throw Exception(authData['error']['message']);
      }

      final uid = authData['localId'] as String;

      // 2. Post profile to backend database with IsVerified = 0
      final profileRes = await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/volunteers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'homeAddress': _addressController.text.trim(),
          'location': _locationController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 25,
          'gender': _selectedGender,
          'role': _selectedRole,
          'status': 'Pending',
        }),
      );

      if (profileRes.statusCode != 200 && profileRes.statusCode != 201) {
        final errBody = jsonDecode(profileRes.body);
        throw Exception(errBody['error'] ?? 'Failed to save volunteer profile.');
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.amberAccent),
                SizedBox(width: 10),
                Text('Registration Submitted', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: const Text(
              'Your profile has been created successfully!\n\nAn Admin will review your phone number and credentials. You can log in once verified.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Return to LoginScreen
                },
                child: const Text('OK', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEW VOLUNTEER REGISTRATION'),
        backgroundColor: const Color(0xFF0B0F19),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F19), Color(0xFF111827)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Join the Emergency Response Fleet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Provide your contact and personal details for admin verification.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline, color: Colors.greenAccent),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Valid Email is required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.greenAccent),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pwController,
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.greenAccent),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone Number is required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone_outlined, color: Colors.greenAccent),
                    hintText: '+8801700000000',
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Home Address is required' : null,
                  decoration: const InputDecoration(
                    labelText: 'Home Address *',
                    prefixIcon: Icon(Icons.home_outlined, color: Colors.greenAccent),
                    hintText: 'Full residential street address',
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Area/City required' : null,
                        decoration: const InputDecoration(
                          labelText: 'City / Area *',
                          prefixIcon: Icon(Icons.location_city, color: Colors.greenAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Age required' : null,
                        decoration: const InputDecoration(
                          labelText: 'Age *',
                          prefixIcon: Icon(Icons.cake_outlined, color: Colors.greenAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  items: _genderOptions
                      .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val!),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc, color: Colors.greenAccent),
                  ),
                  dropdownColor: const Color(0xFF111827),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: _roleOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedRole = val!),
                  decoration: const InputDecoration(
                    labelText: 'Specialization Role',
                    prefixIcon: Icon(Icons.medical_services_outlined, color: Colors.greenAccent),
                  ),
                  dropdownColor: const Color(0xFF111827),
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                    : ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'SUBMIT FOR VERIFICATION',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
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
