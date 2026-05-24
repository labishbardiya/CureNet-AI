import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../core/auth_provider.dart';
import '../core/data_mode.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Arjun gets Persona defaults. All other users start with a clean profile.
  Map<String, String> userData = DataMode.activeUserId == DataMode.arjunId
      ? Map<String, String>.from(Persona.profileMap)
      : {
          'name': '',
          'abha': '',
          'dob': '',
          'mobile': '',
          'bloodGroup': '',
          'allergies': '',
          'emergencyContact': '',
          'conditions': '',
          'physician': '',
        };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString(DataMode.storageKey('user_profile_data'));
    if (savedData != null) {
      setState(() {
        userData = Map<String, String>.from(jsonDecode(savedData));
      });
    }
    
    // Now override with auth provider data if available
    if (mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.userProfile;
      if (user != null) {
        setState(() {
          if (user['name'] != null) userData['name'] = user['name'].toString();
          if (user['abha'] != null) userData['abha'] = user['abha'].toString();
          if (user['mobile'] != null) userData['mobile'] = user['mobile'].toString();
        });
      }
    }
    // Force default name for demo consistency — only for Arjun
    if (DataMode.activeUserId == DataMode.arjunId && (userData['name'] == 'New User' || userData['name']?.trim().isEmpty == true)) {
      userData['name'] = Persona.name;
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(DataMode.storageKey('user_profile_data'), jsonEncode(userData));
    
    // Also update common keys used by AI/Snapshot
    await prefs.setString('user_name', userData['name']!);
    await prefs.setString('abha_address', userData['abha']!);

    // Update AuthProvider for instant UI reaction
    if (mounted) {
      Provider.of<AuthProvider>(context, listen: false).updateProfile(Map<String, dynamic>.from(userData));
    }
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: userData['name']);
    final mobileCtrl = TextEditingController(text: userData['mobile']);
    final bloodCtrl = TextEditingController(text: userData['bloodGroup']);
    final allergiesCtrl = TextEditingController(text: userData['allergies']);
    final emergencyCtrl = TextEditingController(text: userData['emergencyContact']);
    final physicianCtrl = TextEditingController(text: userData['physician']);
    final conditionsCtrl = TextEditingController(text: userData['conditions']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD8DDE6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Edit Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(color: Color(0xFF9BA8BB))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            userData['name'] = nameCtrl.text;
                            userData['mobile'] = mobileCtrl.text;
                            userData['bloodGroup'] = bloodCtrl.text;
                            userData['allergies'] = allergiesCtrl.text;
                            userData['emergencyContact'] = emergencyCtrl.text;
                            userData['physician'] = physicianCtrl.text;
                            userData['conditions'] = conditionsCtrl.text;
                          });
                          _saveUserData();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Profile updated"), backgroundColor: Color(0xFF00A3A3)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A3A3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8ECF0)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _editField("Full Name", nameCtrl, Icons.person_outline),
                    _editField("Mobile Number", mobileCtrl, Icons.phone_outlined),
                    _editField("Blood Group", bloodCtrl, Icons.bloodtype_outlined),
                    _editField("Allergies", allergiesCtrl, Icons.warning_amber_rounded),
                    _editField("Emergency Contact", emergencyCtrl, Icons.emergency_outlined),
                    _editField("Primary Physician", physicianCtrl, Icons.local_hospital_outlined),
                    _editField("Medical Conditions", conditionsCtrl, Icons.medical_information_outlined, maxLines: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0D2240)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF00A3A3)),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00A3A3), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Navy Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0D2240), Color(0xFF1A3A5C)]),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const TranslatedText("My Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const Spacer(),
                IconButton(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ],
            ),
          ),

          // Profile Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(color: Color(0xFF00A3A3), shape: BoxShape.circle),
                  child: Center(
                    child: Text(userData['name']?.isNotEmpty == true ? userData['name']![0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(userData['name']?.isNotEmpty == true ? userData['name']! : 'Set Your Name', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
                      Text("ABHA: ${userData['abha']?.isNotEmpty == true ? userData['abha']! : '—'}", style: const TextStyle(fontSize: 13, color: Color(0xFF00C4C4))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildCard(
                    title: "HEALTH INFORMATION",
                    children: [
                      _infoRow("Date of Birth", userData['dob']!),
                      _infoRow("Mobile", userData['mobile']!),
                      _infoRow("Blood Group", userData['bloodGroup']!),
                      _infoRow("Allergies", userData['allergies']!),
                      _infoRow("Emergency Contact", userData['emergencyContact']!),
                      _infoRow("Conditions", userData['conditions']!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    title: "DOCTOR ACCESS LOG",
                    children: [
                      _accessRow("Dr. Suresh Kumar", "Apollo Spectra · Today 11:41 AM", "Active"),
                      const Divider(height: 1, color: Color(0xFFD8DDE6)),
                      _accessRow("Dr. Meena Kapoor", "Apollo Spectra · 22 Feb 2026", "Expired"),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TranslatedText(label, style: const TextStyle(fontSize: 14, color: Color(0xFF5A6880))),
          Flexible(child: TranslatedText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _accessRow(String doctor, String subtitle, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(doctor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                TranslatedText(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: status == "Active" ? const Color(0xFFE6F7EF) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TranslatedText(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status == "Active" ? const Color(0xFF22A36A) : const Color(0xFF9BA8BB))),
          ),
        ],
      ),
    );
  }
}