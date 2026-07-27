import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VolunteerProfileScreen extends StatefulWidget {
  final String uid;

  const VolunteerProfileScreen({super.key, required this.uid});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Male';
  String _role = 'First Responder';
  String? _email;
  bool _isVerified = false;
  String? _verifiedByAdmin;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _roleOptions = [
    'First Responder',
    'Medical Aid',
    'Logistics',
    'Search & Rescue',
    'Supply Coordinator'
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await http.get(
        Uri.parse('https://geo-aid-hub.onrender.com/api/me?uid=${widget.uid}'),
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _nameController.text = data['Name'] ?? '';
          _phoneController.text = data['PhoneNumber'] ?? '';
          _addressController.text = data['HomeAddress'] ?? '';
          _ageController.text = data['Age'] != null ? '${data['Age']}' : '';
          _email = data['Email'];
          _gender = _genderOptions.contains(data['Gender']) ? data['Gender'] : 'Male';
          _role = _roleOptions.contains(data['Role']) ? data['Role'] : 'First Responder';
          _isVerified = (data['IsVerified'] == 1 || data['IsVerified'] == true);
          _verifiedByAdmin = data['VerifiedByAdminName'];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = {
      'uid': widget.uid,
      'name': _nameController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'homeAddress': _addressController.text.trim(),
      'age': _ageController.text.trim(),
      'gender': _gender,
      'role': _role,
    };

    try {
      final res = await http.put(
        Uri.parse('https://geo-aid-hub.onrender.com/api/volunteers/me'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Volunteer Profile Updated Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _errorMessage = 'Failed to update profile: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Network error. Please check connection.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOLUNTEER PROFILE'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // VERIFICATION STATUS BADGE
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isVerified ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isVerified ? Colors.greenAccent.withOpacity(0.4) : Colors.amberAccent.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isVerified ? Icons.verified_user : Icons.pending_actions,
                              color: _isVerified ? Colors.greenAccent : Colors.amberAccent,
                              size: 32,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isVerified ? 'VERIFIED VOLUNTEER' : 'PENDING VERIFICATION',
                                    style: TextStyle(
                                      color: _isVerified ? Colors.greenAccent : Colors.amberAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isVerified
                                        ? 'Approved by Central Command${_verifiedByAdmin != null ? " ($_verifiedByAdmin)" : ""}'
                                        : 'Awaiting Admin Account Verification',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Full Name *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Full Name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      if (_email != null) ...[
                        TextFormField(
                          initialValue: _email,
                          enabled: false,
                          style: const TextStyle(color: Colors.grey),
                          decoration: const InputDecoration(labelText: 'Email Address (Account ID)'),
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Phone Number *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Phone Number is required' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Home Address *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Home Address is required' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'Age'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              dropdownColor: const Color(0xFF151C2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'Gender'),
                              items: _genderOptions
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (val) => setState(() => _gender = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _role,
                        dropdownColor: const Color(0xFF151C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Primary Skill / Role'),
                        items: _roleOptions
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (val) => setState(() => _role = val!),
                      ),
                      const SizedBox(height: 28),

                      _isSaving
                          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('UPDATE PROFILE'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                              onPressed: _saveProfile,
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
