import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'sos_portal.dart';

class VictimProfileSetupScreen extends StatefulWidget {
  final String authUid;
  final String? email;

  const VictimProfileSetupScreen({
    super.key,
    required this.authUid,
    this.email,
  });

  @override
  State<VictimProfileSetupScreen> createState() => _VictimProfileSetupScreenState();
}

class _VictimProfileSetupScreenState extends State<VictimProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Male';

  int _householdCount = 1;
  bool _hasVulnerableDependents = false;
  String _mobilityStatus = 'Fully Mobile';
  final _medicalDependenciesController = TextEditingController();
  final _languageController = TextEditingController(text: 'Local');
  int _petCount = 0;

  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _mobilityOptions = [
    'Fully Mobile',
    'Wheelchair',
    'Bedbound',
    'Requires Assistance',
  ];

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = {
      'authUid': widget.authUid,
      'fullName': _fullNameController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'homeAddress': _addressController.text.trim(),
      'age': _ageController.text.trim(),
      'gender': _gender,
      'householdCount': _householdCount,
      'hasVulnerableDependents': _hasVulnerableDependents,
      'mobilityStatus': _mobilityStatus,
      'medicalDependencies': _medicalDependenciesController.text.trim(),
      'primaryLanguage': _languageController.text.trim(),
      'petCount': _petCount,
      'emergencyContactName': _emergencyContactNameController.text.trim(),
      'emergencyContactPhone': _emergencyContactPhoneController.text.trim(),
    };

    try {
      final res = await http.post(
        Uri.parse('https://geo-aid-hub.onrender.com/api/victims'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Victim Emergency Profile Saved Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SosPortal()),
        );
      } else {
        setState(() => _errorMessage = 'Failed to save profile: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Network error saving profile. Please check connection.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VICTIM EMERGENCY PROFILE'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.redAccent, size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Your emergency profile is used by Central Command & First Responders to prioritize rescue aid during disaster situations.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
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

                // --- SECTION 1: PERSONAL DETAILS ---
                _buildSectionHeader('1. Personal Details', Icons.person_outline),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _fullNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Full Name is required' : null,
                ),
                const SizedBox(height: 14),

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
                const SizedBox(height: 28),

                // --- SECTION 2: MOBILITY & HOUSEHOLD SAFETY ---
                _buildSectionHeader('2. Mobility & Vulnerability', Icons.wheelchair_pickup_outlined),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _mobilityStatus,
                  dropdownColor: const Color(0xFF151C2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Mobility Status *'),
                  items: _mobilityOptions
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setState(() => _mobilityStatus = val!),
                ),
                const SizedBox(height: 14),

                SwitchListTile(
                  title: const Text('Has Vulnerable Dependents?', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Infants, elderly, or bedbound family members', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: _hasVulnerableDependents,
                  activeColor: Colors.redAccent,
                  onChanged: (val) => setState(() => _hasVulnerableDependents = val),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Household Size:', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _householdCount,
                            dropdownColor: const Color(0xFF151C2C),
                            items: List.generate(15, (i) => i + 1)
                                .map((cnt) => DropdownMenuItem(value: cnt, child: Text('$cnt')))
                                .toList(),
                            onChanged: (val) => setState(() => _householdCount = val!),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Pets:', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _petCount,
                            dropdownColor: const Color(0xFF151C2C),
                            items: List.generate(10, (i) => i)
                                .map((cnt) => DropdownMenuItem(value: cnt, child: Text('$cnt')))
                                .toList(),
                            onChanged: (val) => setState(() => _petCount = val!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _medicalDependenciesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Medical Dependencies / Allergies',
                    hintText: 'e.g. Oxygen, Insulin, Asthma inhaler...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 28),

                // --- SECTION 3: EMERGENCY CONTACT ---
                _buildSectionHeader('3. Emergency Contact', Icons.contact_phone_outlined),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emergencyContactNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Emergency Contact Name'),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emergencyContactPhoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Emergency Contact Phone'),
                ),
                const SizedBox(height: 32),

                _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('SAVE VICTIM PROFILE'),
                        onPressed: _saveProfile,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.redAccent, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
        ),
      ],
    );
  }
}
