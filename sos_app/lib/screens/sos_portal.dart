import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class SosPortal extends StatefulWidget {
  const SosPortal({super.key});

  @override
  State<SosPortal> createState() => _SosPortalState();
}

class _SosPortalState extends State<SosPortal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  int _selectedCategory = 1;

  final Map<int, String> _categories = {
    1: 'Medical Emergency',
    2: 'Flood/Water Rescue',
    3: 'Food/Water Supplies',
    4: 'Fire/Hazardous',
    5: 'Other Assistance',
  };

  bool _isSending = false;
  double _urgencyScore = 5.0;

  Future<void> _sendSosAlert() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      // 1. Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 2. Prepare the data
      final Map<String, dynamic> sosData = {
        'RequestorName': _nameController.text,
        'CategoryID': _selectedCategory,
        'UrgencyScore': _urgencyScore.toInt(),
        'Latitude': position.latitude,
        'Longitude': position.longitude,
        'ShortMessage': _messageController.text,
      };

      // 3. Send to backend via ApiService
      final response = await ApiService.sendSosAlert(sosData);

      if (response.statusCode == 201) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('SOS Sent Successfully'),
              content: const Text('Help is on the way. Please stay where you are.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _nameController.clear();
                    _messageController.clear();
                    setState(() => _selectedCategory = 1);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Failed to send SOS (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo-Aid SOS Portal'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 100,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'EMERGENCY SOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill this form to alert and dispatch nearest team.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              // Name Field
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your Full Name',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.person, color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 20),
              
              // Category Field
              DropdownButtonFormField<int>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Type of Emergency',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.category, color: Colors.redAccent),
                ),
                items: _categories.entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
              const SizedBox(height: 20),
              
              // Message Field
              TextField(
                controller: _messageController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Short Message (Optional)',
                  hintText: 'Describe your situation briefly...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60), 
                    child: Icon(Icons.message, color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Urgency Score Slider
              const Text(
                'Urgency Level',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _urgencyScore,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.white10,
                      label: 'Urgency: ${_urgencyScore.toInt()}',
                      onChanged: (double value) {
                        setState(() {
                          _urgencyScore = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${_urgencyScore.toInt()}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Send Button
              _isSending
                  ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                  : ElevatedButton(
                      onPressed: _sendSosAlert,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: Colors.redAccent.withOpacity(0.4),
                      ),
                      child: const Text(
                        'SEND SOS ALERT',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
