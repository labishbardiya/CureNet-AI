import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/persona.dart';
import '../core/translated_text.dart';
import '../core/data_mode.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../services/ocr_service.dart';

class EmergencySnapshotScreen extends StatefulWidget {
  const EmergencySnapshotScreen({super.key});

  @override
  State<EmergencySnapshotScreen> createState() => _EmergencySnapshotScreenState();
}

class _EmergencySnapshotScreenState extends State<EmergencySnapshotScreen>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late AnimationController _pulseController;

  // Dynamic data
  List<String> _activeMedications = [];
  List<String> _conditions = [];
  List<String> _keyVitals = [];
  bool _dataLoaded = false;
  
  String _allergies = "";
  String _emergencyContactName = "";
  String _emergencyContactPhone = "";
  String _bloodGroup = "";
  String _physician = "";

  DateTime? _lastUpdated;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(DataMode.storageKey('emergency_snapshot_last_sync'));
    
    bool needsAutoRefresh = false;
    if (lastSyncStr != null) {
      final lastSync = DateTime.parse(lastSyncStr);
      if (DateTime.now().difference(lastSync).inHours >= 12) {
        needsAutoRefresh = true;
      }
      setState(() => _lastUpdated = lastSync);
    } else {
      needsAutoRefresh = true;
    }

    if (needsAutoRefresh) {
      await _loadDynamicData(isAuto: true);
    } else {
      await _loadDynamicData();
    }
  }

  Future<void> _loadDynamicData({bool isAuto = false}) async {
    if (mounted) setState(() => _isSyncing = true);
    
    final prefs = await SharedPreferences.getInstance();
    final bool isArjun = DataMode.activeUserId == DataMode.arjunId;
    
    // ── 1. Load Profile Data (User-editable) ──
    final String? profileJson = prefs.getString(DataMode.storageKey('user_profile_data'));
    if (profileJson != null && profileJson.isNotEmpty) {
      final profile = Map<String, dynamic>.from(jsonDecode(profileJson));
      _allergies = profile['allergies']?.toString() ?? (isArjun ? Persona.allergiesShort : '');
      _bloodGroup = profile['bloodGroup']?.toString() ?? (isArjun ? Persona.bloodGroup : '');
      _physician = profile['physician']?.toString() ?? (isArjun ? "${Persona.primaryPhysician['name']}\n${Persona.primaryPhysician['specialty']}" : '');
      
      // Parse merged emergency contact field
      final ec = profile['emergencyContact']?.toString() ?? '';
      if (ec.contains('—')) {
        final parts = ec.split('—');
        _emergencyContactName = parts[0].trim();
        _emergencyContactPhone = parts.length > 1 ? parts[1].trim() : '';
      } else if (ec.isNotEmpty) {
        _emergencyContactName = ec;
        _emergencyContactPhone = '';
      } else {
        _emergencyContactName = isArjun ? Persona.emergencyRelation : '';
        _emergencyContactPhone = isArjun ? Persona.emergencyPhone : '';
      }
    } else {
      // No profile saved — use Persona defaults ONLY for Arjun
      _allergies = isArjun ? Persona.allergiesShort : '';
      _emergencyContactName = isArjun ? Persona.emergencyRelation : '';
      _emergencyContactPhone = isArjun ? Persona.emergencyPhone : '';
      _bloodGroup = isArjun ? Persona.bloodGroup : '';
      _physician = isArjun ? "${Persona.primaryPhysician['name']}\n${Persona.primaryPhysician['specialty']}" : '';
    }
    
    // ── 2. Load Medical Records (Medications, Vitals from local storage) ──
    final localRecords = await OcrService.getLocalRecords();
    
    // Also check health_records key for backward compatibility
    final String? recordsJson = prefs.getString(DataMode.storageKey('health_records'));
    List<Map<String, dynamic>> displayRecords = [];
    if (recordsJson != null && recordsJson.isNotEmpty) {
      displayRecords = List<Map<String, dynamic>>.from(jsonDecode(recordsJson));
    }

    // Simulating a slightly longer fetch for UI feedback if manually triggered
    if (!isAuto) await Future.delayed(const Duration(milliseconds: 800));

    // Demo mode fallback — ONLY for Arjun when he has no records
    if (localRecords.isEmpty && displayRecords.isEmpty && isArjun) {
      setState(() {
        _activeMedications = Persona.medications
            .map((m) => "${m['name']} ${m['dosage']}")
            .toList();
        _conditions = List<String>.from(Persona.conditions);
        _keyVitals = ['BP: 132/84 mmHg', 'HbA1c: 5.8%', 'Glucose: 102 mg/dL'];
        _dataLoaded = true;
        _isSyncing = false;
        _lastUpdated = DateTime.now();
      });
      return;
    }
    
    // Non-Arjun with no records → show empty state
    if (localRecords.isEmpty && displayRecords.isEmpty) {
      setState(() {
        _activeMedications = [];
        _conditions = [];
        _keyVitals = [];
        _dataLoaded = true;
        _isSyncing = false;
        _lastUpdated = DateTime.now();
      });
      return;
    }

    // ── Parse records for dynamic data ──
    final Set<String> medSet = {};
    final Set<String> condSet = {};
    final Map<String, String> latestVitals = {};

    // Extract from local records (rich data with uiData)
    for (var record in localRecords) {
      final uiData = record['uiData'] as Map<String, dynamic>? ?? {};
      
      // Extract medications from uiData.medications (the parsed OCR data)
      final medications = uiData['medications'] as List? ?? [];
      for (var med in medications) {
        final name = med['name']?.toString() ?? '';
        final dosage = med['dosage']?.toString() ?? '';
        if (name.isNotEmpty && name.length > 2) {
          medSet.add(dosage.isNotEmpty ? '$name $dosage' : name);
        }
      }

      // Extract lab values
      final labResults = uiData['lab_results'] as List? ?? [];
      for (var lab in labResults) {
        final testName = lab['test_name']?.toString() ?? '';
        final value = lab['value']?.toString() ?? '';
        final unit = lab['unit']?.toString() ?? '';
        if (testName.isNotEmpty && value.isNotEmpty) {
          latestVitals[testName] = '$value $unit'.trim();
        }
      }

      // Also check labValues map
      final labValues = record['labValues'] as Map<String, dynamic>? ?? {};
      labValues.forEach((key, value) {
        if (key == 'HbA1c') latestVitals['HbA1c'] = '$value%';
        if (key == 'Glucose') latestVitals['Glucose'] = '$value mg/dL';
      });
    }

    // Fallback: Also extract from display records if no medications found
    if (medSet.isEmpty) {
      for (var record in displayRecords) {
        final category = record['category']?.toString() ?? '';
        if (category == 'Prescriptions') {
          final title = record['title']?.toString() ?? '';
          if (title.isNotEmpty && !title.contains('Processed by')) {
            // Extract meaningful medication name from title
            final cleaned = title
                .replaceFirst('Prescription: ', '')
                .replaceFirst('Prescription for ', '');
            if (cleaned.length > 2) medSet.add(cleaned);
          }
        }
      }
    }

    // Extract BP from summaries
    for (var record in displayRecords) {
      final summary = record['summary']?.toString() ?? '';
      final bpMatch = RegExp(r'BP\s*(\d{2,3}/\d{2,3})').firstMatch(summary);
      if (bpMatch != null) {
        latestVitals['BP'] = '${bpMatch.group(1)} mmHg';
      }
    }

    await prefs.setString(DataMode.storageKey('emergency_snapshot_last_sync'), DateTime.now().toIso8601String());

    if (mounted) {
      setState(() {
        _activeMedications = medSet.isNotEmpty ? medSet.toList() : ['No active meds reported'];
        _conditions = condSet.isNotEmpty ? condSet.toList() : (DataMode.activeUserId == DataMode.arjunId ? List<String>.from(Persona.conditions) : ['No conditions on record']);
        _keyVitals = latestVitals.isNotEmpty
            ? latestVitals.entries.map((e) => '${e.key}: ${e.value}').toList()
            : ['No recent vitals found'];
        _dataLoaded = true;
        _isSyncing = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _captureAndSave() async {
    final Uint8List? image = await _screenshotController.capture();
    if (image != null) {
      await ImageGallerySaverPlus.saveImage(image, name: "CureNet_Emergency_Snapshot");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText("✅ Snapshot saved to gallery!"),
            backgroundColor: Color(0xFF22A36A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userProfile;
    final String userName = (user != null && user['name'] != null && user['name'].toString().trim().isNotEmpty)
        ? user['name'].toString()
        : (DataMode.activeUserId == DataMode.arjunId ? Persona.name : 'User');
    final String abha = (user != null && user['abha'] != null && user['abha'].toString().trim().isNotEmpty)
        ? user['abha'].toString()
        : (DataMode.activeUserId == DataMode.arjunId ? Persona.abhaNumber : '');

    return Scaffold(
      backgroundColor: const Color(0xFF0A121E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "DIGITAL EMERGENCY PASS",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF9BA8BB), letterSpacing: 2),
            ),
            if (_lastUpdated != null)
              Text(
                "UPDATED: ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')} · ${_lastUpdated!.day}/${_lastUpdated!.month}",
                style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w700),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _isSyncing ? null : () => _loadDynamicData(),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
            onPressed: _captureAndSave,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Screenshot(
            controller: _screenshotController,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Header: Name & Status ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D2240),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFD32F2F), width: 2),
                              ),
                              child: const Center(child: Icon(Icons.emergency, color: Color(0xFFD32F2F), size: 32)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userName.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text("ABHA: $abha", style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB), fontWeight: FontWeight.w700, letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _pillLabel("AGE: ${DataMode.activeUserId == DataMode.arjunId ? Persona.age : '—'}", Colors.white24),
                            _pillLabel("GENDER: ${DataMode.activeUserId == DataMode.arjunId ? Persona.gender : '—'}", Colors.white24),
                            _pillLabel("BLOOD: $_bloodGroup", const Color(0xFFD32F2F)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── Critical Alerts Section ───
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("⚠️ CRITICAL ALLERGIES"),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFFDE8E8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3))),
                          child: Text(_allergies.isEmpty ? "None Reported" : _allergies, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFD32F2F))),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        _sectionTitle("💊 ACTIVE MEDICATIONS"),
                        const SizedBox(height: 12),
                        ..._activeMedications.map((m) => _listBullet(m, const Color(0xFFE07B39))),

                        const SizedBox(height: 24),

                        _sectionTitle("🫀 CHRONIC CONDITIONS"),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _conditions.map((c) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3))),
                            child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                          )).toList(),
                        ),

                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE8ECF0), thickness: 1),
                        const SizedBox(height: 24),

                        // ─── Vitals & Physician ───
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle("❤️ LATEST VITALS"),
                                const SizedBox(height: 12),
                                ..._keyVitals.map((v) => Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0D2240), height: 1.6))),
                              ],
                            )),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle("🩺 PHYSICIAN"),
                                const SizedBox(height: 12),
                                ..._physician.split('\n').map((l) => Text(l, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5A6880), height: 1.4))),
                              ],
                            )),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ─── Emergency Footer ───
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFE6F7EF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF22A36A).withOpacity(0.3))),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF22A36A), size: 28),
                              const SizedBox(width: 16),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("EMERGENCY CONTACT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF22A36A), letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(_emergencyContactName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0D2240))),
                                  Text(_emergencyContactPhone, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF22A36A))),
                                ],
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF9BA8BB), letterSpacing: 1));
  }

  Widget _listBullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)))),
        ],
      ),
    );
  }

  Widget _pillLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
    );
  }
}
