import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/translated_text.dart';
import '../services/ocr_service.dart';
import '../services/biometric_service.dart';

class ScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> uiData;
  final Map<String, dynamic> fhirBundle;
  final Map<String, dynamic> abdmContext;
  final String? imagePath;
  final String? localId;
  final bool isSaved;
  final bool isFromLocker;

  const ScanResultScreen({
    super.key,
    required this.uiData,
    required this.fhirBundle,
    required this.abdmContext,
    this.imagePath,
    this.localId,
    this.isSaved = false,
    this.isFromLocker = false,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _isSaving = false;
  bool _showFhirJson = false;
  bool _hasSaved = false;
  bool _savedToLocker = false;
  String? _currentLocalId;

  @override
  void initState() {
    super.initState();
    _hasSaved = widget.isSaved;
    _savedToLocker = widget.isFromLocker;
    _currentLocalId = widget.localId;

    if (!widget.isSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSaveRecord();
      });
    }
  }

  void _autoSaveRecord() async {
    if (_hasSaved) return;
    setState(() => _isSaving = true);
    
    // Save to SharedPreferences (records + health_records)
    final savedId = await OcrService.saveRecordLocally({
      'uiData': widget.uiData,
      'fhirBundle': widget.fhirBundle,
      'abdmContext': widget.abdmContext,
      'imagePath': widget.imagePath,
    });
    
    _currentLocalId = savedId;

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Record saved to your records."),
          backgroundColor: Color(0xFF00A3A3),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveToLocker() async {
    if (_savedToLocker || _currentLocalId == null) return;
    setState(() => _isSaving = true);
    
    await OcrService.saveToLocker(_currentLocalId!);
    
    if (mounted) {
      setState(() {
        _isSaving = false;
        _savedToLocker = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Saved to Health Locker! 🔒"),
            ],
          ),
          backgroundColor: Color(0xFF6B4E9B),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _removeFromLocker() async {
    if (!_savedToLocker || _currentLocalId == null) return;
    
    // Authenticate before removal, with a 30-second grace period
    final canBio = await BiometricService.canAuthenticate();
    if (canBio) {
      final success = await BiometricService.authenticate(
        reason: "Verify identity to remove from Health Locker",
        useGracePeriod: true,
      );
      if (!success) return;
    }

    setState(() => _isSaving = true);
    
    await OcrService.removeFromLocker(_currentLocalId!);
    
    if (mounted) {
      setState(() {
        _isSaving = false;
        _savedToLocker = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from Health Locker"),
          backgroundColor: Color(0xFFD63B3B),
        ),
      );
    }
  }

  void _goToRecords() {
    Navigator.pushReplacementNamed(context, '/records');
  }

  void _scanAnother() {
    Navigator.pushReplacementNamed(context, '/doc-scan');
  }

  void _showOriginalImage() {
    if (widget.imagePath == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.imagePath!.startsWith('http') 
                    ? Image.network(widget.imagePath!) 
                    : Image.file(File(widget.imagePath!)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String docType = widget.uiData['document_type'] ?? 'unknown';
    final isPrescription = docType == 'prescription';
    final isLabReport = docType == 'lab_report';
    
    final summary = widget.uiData['summary'] ?? {};
    final medications = widget.uiData['medications'] ?? [];
    final labResults = widget.uiData['lab_results'] ?? [];
    final followUp = widget.uiData['follow_up'] ?? {};
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2240),
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const TranslatedText(
              "Clinical Record",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
            ),
            Text(
              docType.toUpperCase().replaceAll('_', ' '),
              style: const TextStyle(fontSize: 10, color: Color(0xFF00A3A3), fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ],
        ),
        actions: [
          if (widget.imagePath != null)
            IconButton(
              icon: const Icon(Icons.image_outlined, color: Colors.white),
              tooltip: "View Original Scan",
              onPressed: () => _showOriginalImage(),
            ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Banner
                _buildPatientBanner(summary),
                const SizedBox(height: 24),

                // Vitals & Diagnosis Section (High Priority)
                if (summary['vitals'] != null || summary['diagnosis'] != null) ...[
                  _buildSectionTitle("Clinical Observations"),
                  _buildInfoCard([
                    if (summary['diagnosis'] != null)
                      _buildSummaryRow(Icons.biotech, "Diagnosis", summary['diagnosis']),
                    if (summary['vitals']?['bp'] != null)
                      _buildSummaryRow(Icons.monitor_heart_outlined, "Blood Pressure", summary['vitals']['bp']),
                    if (summary['vitals']?['pulse'] != null)
                      _buildSummaryRow(Icons.favorite_outline, "Pulse Rate", summary['vitals']['pulse']),
                    if (summary['vitals']?['temperature'] != null)
                      _buildSummaryRow(Icons.thermostat, "Temperature", summary['vitals']['temperature']),
                  ]),
                  const SizedBox(height: 24),
                ],

                // Clinical Summary Card
                _buildSectionTitle("Visit Summary"),
                _buildInfoCard([
                  _buildSummaryRow(Icons.person_outline, "Patient", summary['patient'] ?? "Unclear"),
                  _buildSummaryRow(Icons.medical_information_outlined, "Doctor", summary['doctor'] ?? "Unclear"),
                  _buildSummaryRow(Icons.calendar_month_outlined, "Visit Date", summary['date'] ?? "Unclear"),
                  if (summary['facility'] != null)
                    _buildSummaryRow(Icons.apartment_outlined, "Facility", summary['facility']),
                  if (summary['chief_complaint'] != null)
                    _buildSummaryRow(Icons.assignment_outlined, "Clinical Notes", summary['chief_complaint']),
                ]),
                const SizedBox(height: 24),

                // Prescriptions Section
                if (isPrescription && medications.isNotEmpty) ...[
                  _buildSectionTitle("Prescribed Medications"),
                  ...medications.map((med) => _buildMedicationCard(med)).toList(),
                ],

                // Lab Reports Section
                if (isLabReport && labResults.isNotEmpty) ...[
                  _buildSectionTitle("Laboratory Observations"),
                  ...labResults.map((test) => _buildLabResultCard(test)).toList(),
                ],

                // Investigations
                if (summary['investigations'] != null && summary['investigations'].toString().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle("Recommended Investigations"),
                  _buildGenericContentCard(summary['investigations'], Icons.biotech_outlined),
                ],

                // Follow Up
                if (followUp['date'] != null || (followUp['advice'] != null && followUp['advice'].isNotEmpty)) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle("Follow-up & Advice"),
                  _buildFollowUpCard(followUp),
                ],

                const SizedBox(height: 32),
                
                // ABDM Compliance Section
                _buildComplianceBadge(),
                const SizedBox(height: 16),
                
                // FHIR Bundle View (Expandable)
                _buildFhirExpansionTile(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          // Bottom Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientBanner(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2240), Color(0xFF1B3B5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D2240).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF00A3A3).withOpacity(0.2),
            child: const Icon(Icons.person, color: Color(0xFF00A3A3), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary['patient']?.toUpperCase() ?? "UNKNOWN PATIENT",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF00A3A3), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "ABDM Validated ID: ${widget.abdmContext['patientId'] ?? 'PENDING'}",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: TranslatedText(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget child = entry.value;
          return Column(
            children: [
              child,
              if (idx < children.length - 1)
                const Divider(height: 1, indent: 50, endIndent: 20, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    String displayValue = (value.isEmpty || value.toLowerCase() == 'unclear') 
        ? "NOT SPECIFIED" 
        : value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00A3A3)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                TranslatedText(
                  displayValue,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07B39).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication_liquid_outlined, color: Color(0xFFE07B39), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['name'] ?? "Unknown Medication",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        med['form']?.toUpperCase() ?? "MEDICINE",
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMedMetric(Icons.scale_outlined, "DOSAGE", med['dosage']),
                _buildMedMetric(Icons.event_repeat_outlined, "FREQUENCY", med['frequency']),
                _buildMedMetric(Icons.timer_outlined, "DURATION", med['duration']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedMetric(IconData icon, String label, String? value) {
    String displayValue = (value == null || value.isEmpty || value.toLowerCase() == 'unclear') 
        ? "NOT SPECIFIED" 
        : value.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF00A3A3)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          displayValue,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildLabResultCard(Map<String, dynamic> test) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.biotech, color: Color(0xFF00A3A3), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  test['test_name'] ?? "Unknown Test",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("MEASURED VALUE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        test['value']?.toString() ?? "--",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        test['unit'] ?? "",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (test['reference_range'] != null && test['reference_range'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("NORMAL RANGE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        test['reference_range'],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenericContentCard(String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00A3A3), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(Map<String, dynamic> followUp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (followUp['date'] != null)
            Row(
              children: [
                const Icon(Icons.event_available, color: Color(0xFF00A3A3), size: 20),
                const SizedBox(width: 12),
                Text("RE-VISIT DATE:", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(followUp['date'], style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
              ],
            ),
          if (followUp['advice'] != null && followUp['advice'].isNotEmpty) ...[
            if (followUp['date'] != null) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            ...List<String>.from(followUp['advice']).map((advice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF00A3A3), size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(advice, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildComplianceBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00A3A3).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00A3A3).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_outlined, color: Color(0xFF00A3A3), size: 24),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ABDM FHIR R4 COMPLIANT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF00A3A3), letterSpacing: 0.5)),
                SizedBox(height: 2),
                Text("Clinical data has been mapped to SNOMED CT / LOINC standards for secure health exchange.", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFhirExpansionTile() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const TranslatedText("Technical FHIR Bundle", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
        tilePadding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            width: double.infinity,
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(widget.fhirBundle),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // Save/Remove from Locker button
          Expanded(
            flex: widget.isFromLocker ? 5 : 3,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : (_savedToLocker ? _removeFromLocker : _saveToLocker),
              icon: Icon(
                _savedToLocker ? Icons.lock_open : Icons.lock_outline,
                size: 18,
                color: Colors.white,
              ),
              label: TranslatedText(
                _savedToLocker ? "REMOVE FROM LOCKER" : "SAVE TO LOCKER",
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _savedToLocker ? const Color(0xFFD63B3B) : const Color(0xFF6B4E9B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD63B3B).withOpacity(0.5),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          if (!widget.isFromLocker) ...[
            const SizedBox(width: 12),
            // Scan Another button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _scanAnother,
                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                label: const TranslatedText(
                  "SCAN",
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2240),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
