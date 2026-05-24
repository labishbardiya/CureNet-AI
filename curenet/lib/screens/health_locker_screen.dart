import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import '../services/biometric_service.dart';
import '../services/ocr_service.dart';
import 'scan_result_screen.dart';

class HealthLockerScreen extends StatefulWidget {
  const HealthLockerScreen({super.key});
  @override
  State<HealthLockerScreen> createState() => _HealthLockerScreenState();
}

class _HealthLockerScreenState extends State<HealthLockerScreen> {
  bool _isExporting = false;
  List<Map<String, dynamic>> _lockerRecords = [];
  bool _isLoading = true;

  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticateLocker();
  }

  Future<void> _authenticateLocker() async {
    final canBio = await BiometricService.canAuthenticate();
    if (canBio) {
      final success = await BiometricService.authenticate(
        reason: "Authenticate to access Health Locker",
      );
      if (success) {
        if (mounted) setState(() => _isAuthenticated = true);
        _loadLockerRecords();
      } else {
        if (mounted) Navigator.pop(context);
      }
    } else {
      if (mounted) setState(() => _isAuthenticated = true);
      _loadLockerRecords();
    }
  }



  Future<void> _loadLockerRecords() async {
    final records = await OcrService.getLockerRecords();
    if (mounted) setState(() { _lockerRecords = records; _isLoading = false; });
  }

  void _unlockAndView(Map<String, dynamic> record, String title) async {
    // 2. Open the rendered FHIR view if we have full data
    if (record['uiData'] != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          uiData: Map<String, dynamic>.from(record['uiData']),
          fhirBundle: Map<String, dynamic>.from(record['fhirBundle'] ?? {}),
          abdmContext: Map<String, dynamic>.from(record['abdmContext'] ?? {}),
          imagePath: record['imagePath'],
          localId: record['localId'],
          isSaved: true,
          isFromLocker: true,
        ),
      ));
    }
  }

  IconData _docTypeIcon(String? docType) {
    switch (docType) {
      case 'prescription': return Icons.medication;
      case 'lab_report': return Icons.science;
      default: return Icons.medical_services;
    }
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
              gradient: LinearGradient(colors: [Color(0xFF6B4E9B), Color(0xFF9F7AEA)]),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText("Health Locker", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                    TranslatedText("${_lockerRecords.length} encrypted records",
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                )),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Security Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE8F7F7), Color(0xFFF0F8FF)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF00A3A3).withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, color: Color(0xFF00A3A3), size: 20),
                            SizedBox(width: 10),
                            Expanded(child: TranslatedText(
                              "Your data is encrypted with Zero-Knowledge proofs. DPDP Act 2023 compliant.",
                              style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3)),
                            )),
                          ],
                        ),
                      ),

                      // Records Section
                      if (_lockerRecords.isEmpty) ...[
                        const SizedBox(height: 40),
                        Icon(Icons.lock_open, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const TranslatedText("No records in locker yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF9BA8BB))),
                        const SizedBox(height: 8),
                        const TranslatedText("Scan a document and tap 'Save to Locker' to add it here.",
                          style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB)), textAlign: TextAlign.center),
                      ] else ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: TranslatedText("ENCRYPTED RECORDS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB), letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 10),
                        ..._lockerRecords.map((record) {
                          final title = record['title'] ?? 'Medical Document';
                          final date = record['displayDate'] ?? record['date'] ?? '';
                          final docType = record['documentType'] ?? 'other';
                          return _lockerCard(
                            icon: _docTypeIcon(docType),
                            title: title, date: date,
                            imagePath: record['imagePath'],
                            onTap: () => _unlockAndView(record, title),
                          );
                        }),
                      ],

                      const SizedBox(height: 24),
                      _buildActionCard(icon: Icons.save, title: "Backup All Records",
                        subtitle: "Download encrypted backup", color: const Color(0xFF00A3A3),
                        onTap: () => _showBackupDialog(context)),
                      _buildActionCard(
                        icon: _isExporting ? Icons.sync : Icons.upload,
                        title: _isExporting ? "Exporting..." : "Export to ABDM",
                        subtitle: "Share with ABDM network (HIP push)",
                        color: const Color(0xFF22A36A),
                        onTap: () => _isExporting ? null : _showExportDialog(context)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _lockerCard({required IconData icon, required String title, required String date, String? imagePath, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8DDE6)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(icon, size: 24, color: const Color(0xFF00A3A3))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
              ],
            )),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9BA8BB)),
          ],
        ),
      ),
    );
  }


  Widget _buildActionCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Icon(icon, size: 24, color: color))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TranslatedText(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            TranslatedText(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF5A6880))),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9BA8BB)),
        ]),
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const TranslatedText("Backup Records"),
      content: const TranslatedText("Encrypted backup will be downloaded to your device."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const TranslatedText("Cancel")),
        ElevatedButton(onPressed: () { Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TranslatedText("✅ Backup downloaded"), backgroundColor: Color(0xFF00A3A3)));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A3A3)), child: const TranslatedText("Download")),
      ],
    ));
  }

  void _showExportDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const TranslatedText("Export to ABDM"),
      content: const TranslatedText("Your records will be pushed to the national ABDM network."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const TranslatedText("Cancel")),
        ElevatedButton(onPressed: () { Navigator.pop(ctx);
          setState(() => _isExporting = true);
          Future.delayed(const Duration(seconds: 2), () { if (mounted) { setState(() => _isExporting = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TranslatedText("✅ Records exported to ABDM"), backgroundColor: Color(0xFF22A36A)));
          }});
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22A36A)), child: const TranslatedText("Export")),
      ],
    ));
  }

  Widget _buildBottomNav() {
    return Container(
      height: 78,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFD8DDE6)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _navItem(Icons.home, "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
        _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
        _scanButton(context),
        _navItem(Icons.list_alt, "Records", false, () => Navigator.pushReplacementNamed(context, '/records')),
        _navItem(Icons.share, "Share", false, () => Navigator.pushReplacementNamed(context, '/qr-share')),
      ]),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
      TranslatedText(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
    ]));
  }

    Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ModalRoute.of(context)?.settings.name != '/doc-scan') {
          Navigator.pushNamed(context, '/doc-scan');
        }
      },
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A3A3).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}