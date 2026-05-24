import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../core/data_mode.dart';
import '../core/app_config.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';

import 'package:http/http.dart' as http;

class QrShareScreen extends StatefulWidget {
  const QrShareScreen({super.key});

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> {
  String _qrData = '';
  String _abhaNumber = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _buildQrPayload();
  }

  Future<void> _buildQrPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userProfile;
    final bool isArjun = DataMode.activeUserId == DataMode.arjunId;

    // ── Gather data — Arjun gets Persona defaults, others get empty ──
    String name = user?['name']?.toString() ?? (isArjun ? Persona.name : 'User');
    String abha = user?['abha']?.toString() ?? (isArjun ? Persona.abhaNumber : '');
    String bloodGroup = isArjun ? Persona.bloodGroup : '';
    String allergies = isArjun ? Persona.allergiesShort : '';
    String emergencyName = isArjun ? Persona.emergencyRelation : '';
    String emergencyPhone = isArjun ? Persona.emergencyPhone : '';

    List<String> vitals = isArjun ? ['BP: 132/84 mmHg', 'HbA1c: 5.8%', 'Glucose: 102 mg/dL'] : [];
    List<String> conditions = isArjun ? List<String>.from(Persona.conditions) : [];
    
    String physician = isArjun ? '${Persona.primaryPhysician['name']}\n${Persona.primaryPhysician['specialty']}\n${Persona.primaryPhysician['phone']}' : '';

    // Override with user-editable profile if available
    final String? profileJson = prefs.getString(DataMode.storageKey('user_profile_data'));
    if (profileJson != null && profileJson.isNotEmpty) {
      final profile = Map<String, dynamic>.from(jsonDecode(profileJson));
      if (profile['bloodGroup']?.toString().isNotEmpty == true) bloodGroup = profile['bloodGroup'].toString();
      if (profile['allergies']?.toString().isNotEmpty == true) allergies = profile['allergies'].toString();
      if (profile['emergencyContact']?.toString().isNotEmpty == true) emergencyName = profile['emergencyContact'].toString();
      if (profile['emergencyPhone']?.toString().isNotEmpty == true) emergencyPhone = profile['emergencyPhone'].toString();
      if (profile['physician']?.toString().isNotEmpty == true) physician = profile['physician'].toString();
      if (profile['conditions']?.toString().isNotEmpty == true) {
        conditions = profile['conditions'].toString().split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      }
    }
    // Build medication list
    List<String> medications = [];
    if (isArjun) {
      medications = Persona.medications.map((m) => "${m['name']} ${m['dosage']}").toList();
    } else {
      final String? recordsJson = prefs.getString(DataMode.storageKey('health_records'));
      if (recordsJson != null) {
        final records = List<Map<String, dynamic>>.from(jsonDecode(recordsJson));
        for (var r in records) {
          if (r['category'] == 'Prescriptions') {
            final title = r['title']?.toString() ?? '';
            final summary = r['summary']?.toString() ?? '';
            medications.add(summary.isNotEmpty ? summary : title);
          }
        }
      }
      if (medications.isEmpty && isArjun) {
        medications = Persona.medications.map((m) => "${m['name']} ${m['dosage']}").toList();
      }
    }

    final payload = {
      'name': name,
      'age': isArjun ? Persona.age : '',
      'gender': isArjun ? Persona.gender : '',
      'abha': abha,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medications': medications,
      'conditions': conditions,
      'vitals': vitals,
      'physician': physician,
      'emergencyName': emergencyName,
      'emergencyPhone': emergencyPhone,
    };

    String qrId = '';
    try {
      // 1. Try to get a short shareId from backend
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/emergency/share'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        qrId = jsonDecode(response.body)['shareId'];
      }
    } catch (e) {
      debugPrint('QR Share Error: $e');
    }

    // 2. Fallback to base64 if backend fails or payload is small
    if (qrId.isEmpty) {
      qrId = base64Url.encode(utf8.encode(jsonEncode(payload)));
    }

    setState(() {
      _qrData = '${AppConfig.emergencyBaseUrl}/$qrId';
      _abhaNumber = abha;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFD8DDE6))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: TranslatedText("Share with Doctor",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 24),
                  onPressed: () async {
                    final ok = await VoiceHelper.speak(
                      "Share with Doctor. Your ABHA number is $_abhaNumber. Show this QR to the doctor to share your Emergency Health Card.",
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(VoiceHelper.lastError ?? 'Voice readout failed.'),
                          backgroundColor: const Color(0xFF0D2240),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A3A3)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // QR CODE
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 220,
                              gapless: false,
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D2240),
                              errorStateBuilder: (cxt, err) {
                                return const Center(
                                  child: Text(
                                    "Could not connect to backend.\nQR data too large.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            TranslatedText(_abhaNumber,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Color(0xFF0D2240),
                              ),
                            ),
                            const TranslatedText("@abdm",
                              style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            TranslatedText("How it works",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                            ),
                            SizedBox(height: 8),
                            TranslatedText(
                              "1. Doctor scans this QR code\n"
                              "2. Your Emergency Health Card opens\n"
                              "3. Doctor can save/print the card\n"
                              "4. No app required on their end",
                              style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF0D2240)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/emergency-snapshot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          minimumSize: const Size(double.infinity, 58),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emergency, color: Colors.white),
                            SizedBox(width: 10),
                            TranslatedText("View Emergency Snapshot",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/access-req'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D2240), width: 2),
                          minimumSize: const Size(double.infinity, 58),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const TranslatedText("Show Scan & Share QR",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}