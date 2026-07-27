import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VictimProfileScreen extends StatefulWidget {
  const VictimProfileScreen({super.key});

  @override
  State<VictimProfileScreen> createState() => _VictimProfileScreenState();
}

class _VictimProfileScreenState extends State<VictimProfileScreen> {
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

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _mobilityOptions = [
    'Fully Mobile',
    'Wheelchair',
    'Bedbound',
    'Requires Assistance',
  ];

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final res = await http.get(
        Uri.parse('https://geo-aid-hub.onrender.com/api/victims/me?uid=${user.uid}'),
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _fullNameController.text = data['FullName'] ?? '';
          _phoneController.text = data['PhoneNumber'] ?? '';
          _addressController.text = data['HomeAddress'] ?? '';
          _ageController.text = data['Age'] != null ? '${data['Age']}' : '';
          _gender = _genderOptions.contains(data['Gender']) ? data['Gender'] : 'Male';
          _householdCount = data['HouseholdCount'] ?? 1;
          _hasVulnerableDependents = (data['HasVulnerableDependents'] == 1 || data['HasVulnerableDependents'] == true);
          _mobilityStatus = _mobilityOptions.contains(data['MobilityStatus']) ? data['MobilityStatus'] : 'Fully Mobile';
          _medicalDependenciesController.text = data['MedicalDependencies'] ?? '';
          _languageController.text = data['PrimaryLanguage'] ?? 'Local';
          _petCount = data['PetCount'] ?? 0;
          _emergencyContactNameController.text = data['EmergencyContactName'] ?? '';
          _emergencyContactPhoneController.text = data['EmergencyContactPhone'] ?? '';
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = {
      'authUid': user.uid,
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
            content: Text('🎉 Victim Emergency Profile Updated Successfully!'),
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
        title: const Text('MY EMERGENCY PROFILE'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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

                      _buildSectionHeader('Personal Details', Icons.person_outline),
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
                      const SizedBox(height: 24),

                      _buildSectionHeader('Mobility & Vulnerability', Icons.wheelchair_pickup_outlined),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _mobilityStatus,
                        dropdownColor: const Color(0xFF151C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Mobility Status'),
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
                      const SizedBox(height: 24),

                      _buildSectionHeader('Emergency Contact', Icons.contact_phone_outlined),
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
                      const SizedBox(height: 28),

                      _isSaving
                          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('UPDATE PROFILE'),
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
        Icon(icon, color: Colors.redAccent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent),
        ),
      ],
    );
  }
}
