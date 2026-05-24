import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import '../core/data_mode.dart';
import '../core/persona.dart';
import '../services/ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'scan_result_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int activeTab = 0;
  final List<String> tabs = ["All", "Trends", "Prescriptions", "Labs", "Reports"];
  List<Map<String, dynamic>> allRecords = [];
  bool _isLoading = true;
  final Map<String, Timer> _deleteTimers = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
    DataMode.isDemo.addListener(_loadRecords);
  }

  @override
  void dispose() {
    DataMode.isDemo.removeListener(_loadRecords);
    for (var timer in _deleteTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _loadRecords() async {
    if (DataMode.activeUserId == DataMode.arjunId) {
      allRecords = _demoRecords();
    } else {
      // LIVE MODE: Load merged records (Local + Backend)
      allRecords = await OcrService.getLiveMergedRecords();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _categoryToType(String? cat) {
    switch (cat) {
      case 'Prescriptions': return 'medication';
      case 'Labs': return 'science';
      default: return 'medical_services';
    }
  }

  String _categoryToColor(String? cat) {
    switch (cat) {
      case 'Prescriptions': return '#E07B39';
      case 'Labs': return '#00A3A3';
      default: return '#6B4E9B';
    }
  }

  void _openRecord(Map<String, dynamic> record) {
    if (record['hasFullData'] == true && record['uiData'] != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          uiData: Map<String, dynamic>.from(record['uiData']),
          fhirBundle: Map<String, dynamic>.from(record['fhirBundle'] ?? {}),
          abdmContext: Map<String, dynamic>.from(record['abdmContext'] ?? {}),
          imagePath: record['imagePath'],
          localId: record['localId'],
          isSaved: true,
          isFromLocker: record['savedToLocker'] == true,
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opened ${record['title']}"), backgroundColor: const Color(0xFF00A3A3)),
      );
    }
  }

  Future<void> _deleteRecord(int index) async {
    final record = allRecords[index];
    final recordId = record['localId']?.toString() ?? record.hashCode.toString();
    
    setState(() {
      allRecords.removeAt(index);
    });

    // Start 5-second undo timer
    _deleteTimers[recordId] = Timer(const Duration(seconds: 5), () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Delete from health_records (display key, namespaced)
      final healthKey = DataMode.storageKey('health_records');
      final String? savedRecords = prefs.getString(healthKey);
      if (savedRecords != null) {
        final List<dynamic> recordsList = jsonDecode(savedRecords);
        final updatedList = recordsList.where((r) {
          final id = r['localId']?.toString() ?? r.hashCode.toString();
          return id != recordId;
        }).toList();
        await prefs.setString(healthKey, jsonEncode(updatedList));
      }

      // Delete from curenet_saved_records (full data key, namespaced)
      final savedKey = DataMode.storageKey('curenet_saved_records');
      List<String> fullRecords = prefs.getStringList(savedKey) ?? [];
      fullRecords.removeWhere((str) {
        try {
          final r = jsonDecode(str);
          return r['localId']?.toString() == recordId;
        } catch (_) { return false; }
      });
      await prefs.setStringList(savedKey, fullRecords);

      // NOTE: Cloud copy in MongoDB is intentionally retained.
      // Per ABDM, the cloud serves as the longitudinal health locker.
      // Phone-delete = remove from "downloads", not from locker.

      _deleteTimers.remove(recordId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const TranslatedText("Record deleted permanently in 5s"),
          duration: const Duration(seconds: 5), 
          backgroundColor: const Color(0xFFD63B3B),
          action: SnackBarAction(
            label: "UNDO",
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                allRecords.insert(index, record);
              });
              _deleteTimers[recordId]?.cancel();
              _deleteTimers.remove(recordId);
            },
          ),
        ),
      );
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'science': return Icons.science;
      case 'medication': return Icons.medication;
      case 'medical_services': return Icons.medical_services;
      case 'favorite': return Icons.favorite;
      default: return Icons.description;
    }
  }

  String _getMonth(int month) {
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return months[month - 1];
  }
  // ─── Trends View (selection-based, user picks which biomarkers to graph) ──

  // Track which markers the user has selected
  final Set<String> _selectedMarkers = {};

  Widget _buildTrendsView() {
    // Gather all available trends
    final Map<String, List<Map<String, dynamic>>> trends = _gatherTrends();

    if (trends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const TranslatedText("No lab data yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF9BA8BB))),
              const SizedBox(height: 8),
              const TranslatedText("Scan a lab report to see your health trends here.",
                style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final orderedKeys = _orderByImportance(trends.keys.toList());
    
    // Auto-select top 2 markers on first load if nothing selected
    if (_selectedMarkers.isEmpty && orderedKeys.isNotEmpty) {
      _selectedMarkers.add(orderedKeys.first);
      if (orderedKeys.length > 1) _selectedMarkers.add(orderedKeys[1]);
    }

    return StatefulBuilder(
      builder: (context, setTrendsState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Banner ──
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00A3A3).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights, color: Color(0xFF00A3A3), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${trends.length} biomarker${trends.length > 1 ? 's' : ''} available · ${_selectedMarkers.length} selected",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D2240)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Biomarker Selector Chips ──
              const Text("Select biomarkers to graph:", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9BA8BB))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: orderedKeys.map((key) {
                  final isSelected = _selectedMarkers.contains(key);
                  final dataPoints = trends[key]!.length;
                  return GestureDetector(
                    onTap: () {
                      setTrendsState(() {
                        if (isSelected) {
                          _selectedMarkers.remove(key);
                        } else {
                          _selectedMarkers.add(key);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00A3A3) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: const Color(0xFF00A3A3).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
                        ] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_circle, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF0D2240),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$dataPoints',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF9BA8BB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Selected Charts ──
              if (_selectedMarkers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.touch_app, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text("Tap a biomarker above to see its trend", 
                        style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB))),
                    ],
                  ),
                )
              else
                ...orderedKeys.where((k) => _selectedMarkers.contains(k)).map((key) {
                  final data = trends[key]!;
                  final values = data.map((e) => e['value'] as double).toList();
                  final labels = data.map((e) {
                    final d = e['date'].toString();
                    if (d.contains(' ')) return d.split(' ').take(2).join(' ');
                    if (d.contains('-')) return d.split('-').last;
                    return d;
                  }).toList();
                  final unit = _getUnitForMarker(key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildChartCard(key, unit, values, labels),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Gather trends from all records (used by both demo and live)
  Map<String, List<Map<String, dynamic>>> _gatherTrends() {
    final Map<String, List<Map<String, dynamic>>> trends = {};
    final bool isArjun = DataMode.activeUserId == DataMode.arjunId;
    
    // For Arjun demo mode, use the demo records
    final records = isArjun ? _demoRecords() : allRecords;

    for (final record in records) {
      final date = record['date']?.toString() ?? '';
      
      // 1. Extract from labValues map
      final labValues = record['labValues'] as Map<String, dynamic>? ?? {};
      labValues.forEach((marker, value) {
        if (value != null && value is num) {
          trends.putIfAbsent(marker, () => []);
          if (!trends[marker]!.any((e) => e['date'] == date && e['value'] == value.toDouble())) {
            trends[marker]!.add({'value': value.toDouble(), 'date': date});
          }
        }
      });

      // 2. Extract from uiData.lab_results (richer source)
      final uiData = record['uiData'] as Map<String, dynamic>? ?? {};
      final labResults = uiData['lab_results'] as List? ?? [];
      for (var lab in labResults) {
        final name = _normalizeMarkerName(lab['test_name']?.toString() ?? '');
        final rawVal = lab['value'];
        if (rawVal == null || name.isEmpty) continue;
        final numVal = rawVal is num ? rawVal.toDouble() : double.tryParse(rawVal.toString());
        if (numVal == null) continue;
        
        trends.putIfAbsent(name, () => []);
        if (!trends[name]!.any((e) => e['date'] == date && e['value'] == numVal)) {
          trends[name]!.add({'value': numVal, 'date': date});
        }
      }

      // 3. Extract vitals from summary text
      final summary = record['summary']?.toString() ?? '';
      _extractVitalsFromText(summary, date, trends);
    }

    // Sort each trend by date
    for (var key in trends.keys) {
      trends[key]!.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    }

    // Keep even single data points (user might want to see current value)
    return trends;
  }

  /// Normalize common lab test names to standard markers
  String _normalizeMarkerName(String name) {
    final n = name.toLowerCase().trim();
    if (n.contains('hba1c') || n.contains('glycated')) return 'HbA1c';
    if (n.contains('fasting') && n.contains('glucose')) return 'Fasting Glucose';
    if (n.contains('glucose') || n.contains('sugar') || n.contains('rbs') || n.contains('fbs')) return 'Blood Glucose';
    if (n.contains('tsh') || n.contains('thyroid stim')) return 'TSH';
    if (n.contains('total cholesterol')) return 'Total Cholesterol';
    if (n.contains('ldl')) return 'LDL';
    if (n.contains('hdl')) return 'HDL';
    if (n.contains('triglyceride')) return 'Triglycerides';
    if (n.contains('haemoglobin') || n.contains('hemoglobin') || n == 'hb') return 'Hemoglobin';
    if (n.contains('creatinine')) return 'Creatinine';
    if (n.contains('sgpt') || n.contains('alt')) return 'SGPT/ALT';
    if (n.contains('sgot') || n.contains('ast')) return 'SGOT/AST';
    if (n.contains('uric acid')) return 'Uric Acid';
    if (n.contains('vitamin d') || n.contains('vit d')) return 'Vitamin D';
    if (n.contains('vitamin b12') || n.contains('vit b12')) return 'Vitamin B12';
    if (n.contains('calcium')) return 'Calcium';
    if (n.contains('iron') || n.contains('ferritin')) return 'Iron/Ferritin';
    if (n.contains('platelet')) return 'Platelets';
    if (n.contains('wbc') || n.contains('white blood')) return 'WBC';
    if (n.contains('rbc') || n.contains('red blood')) return 'RBC';
    if (n.contains('bilirubin')) return 'Bilirubin';
    if (n.contains('albumin')) return 'Albumin';
    if (n.contains('weight')) return 'Weight';
    if (n.contains('systolic') || n == 'bp') return 'BP (Systolic)';
    if (n.contains('diastolic')) return 'BP (Diastolic)';
    if (n.contains('bmi')) return 'BMI';
    if (n.contains('immunoglobulin') || n.contains('ige')) return 'IgE';
    return name.isNotEmpty ? name[0].toUpperCase() + name.substring(1) : name;
  }

  /// Extract vitals mentioned in clinical summaries
  void _extractVitalsFromText(String text, String date, Map<String, List<Map<String, dynamic>>> trends) {
    final bpMatch = RegExp(r'BP\s*(\d{2,3})/(\d{2,3})').firstMatch(text);
    if (bpMatch != null) {
      final systolic = double.tryParse(bpMatch.group(1)!);
      final diastolic = double.tryParse(bpMatch.group(2)!);
      if (systolic != null) {
        trends.putIfAbsent('BP (Systolic)', () => []);
        trends['BP (Systolic)']!.add({'value': systolic, 'date': date});
      }
      if (diastolic != null) {
        trends.putIfAbsent('BP (Diastolic)', () => []);
        trends['BP (Diastolic)']!.add({'value': diastolic, 'date': date});
      }
    }
  }

  /// Order markers by clinical priority
  List<String> _orderByImportance(List<String> keys) {
    const order = [
      'HbA1c', 'Fasting Glucose', 'Blood Glucose',
      'BP (Systolic)', 'BP (Diastolic)',
      'Total Cholesterol', 'LDL', 'HDL', 'Triglycerides',
      'Hemoglobin', 'TSH', 'Creatinine',
      'SGPT/ALT', 'SGOT/AST', 'Bilirubin',
      'Weight', 'BMI',
      'Vitamin D', 'Vitamin B12', 'Iron/Ferritin', 'Calcium',
      'Uric Acid', 'Platelets', 'WBC', 'RBC', 'Albumin', 'IgE',
    ];
    final sorted = <String>[];
    for (var m in order) {
      if (keys.contains(m)) sorted.add(m);
    }
    for (var k in keys) {
      if (!sorted.contains(k)) sorted.add(k);
    }
    return sorted;
  }

  String _getUnitForMarker(String marker) {
    final m = marker.toLowerCase();
    if (m.contains('hba1c')) return '%';
    if (m.contains('glucose') || m.contains('sugar')) return 'mg/dL';
    if (m.contains('tsh')) return 'µIU/mL';
    if (m.contains('cholesterol') || m.contains('ldl') || m.contains('hdl') || m.contains('triglyceride')) return 'mg/dL';
    if (m.contains('hemoglobin')) return 'g/dL';
    if (m.contains('creatinine')) return 'mg/dL';
    if (m.contains('sgpt') || m.contains('sgot') || m.contains('alt') || m.contains('ast')) return 'U/L';
    if (m.contains('bilirubin')) return 'mg/dL';
    if (m.contains('albumin')) return 'g/dL';
    if (m.contains('vitamin d')) return 'ng/mL';
    if (m.contains('vitamin b12')) return 'pg/mL';
    if (m.contains('iron') || m.contains('ferritin')) return 'ng/mL';
    if (m.contains('calcium')) return 'mg/dL';
    if (m.contains('uric')) return 'mg/dL';
    if (m.contains('platelet')) return '×10³/µL';
    if (m.contains('wbc') || m.contains('rbc')) return '×10⁶/µL';
    if (m.contains('bp')) return 'mmHg';
    if (m.contains('weight')) return 'kg';
    if (m.contains('bmi')) return 'kg/m²';
    if (m.contains('ige')) return 'IU/mL';
    return '';
  }

  Widget _buildChartCard(String title, String unit, List<double> values, List<String> labels) {
    final trendDown = values.length >= 2 && values.last < values.first;
    final trendColor = trendDown ? const Color(0xFF22A36A) : const Color(0xFFE07B39);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: TranslatedText(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendDown ? Icons.trending_down : Icons.trending_up, size: 16, color: trendColor),
                    const SizedBox(width: 4),
                    Text("${values.last} $unit", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: trendColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true, color: const Color(0xFF00A3A3), barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF00A3A3).withValues(alpha: 0.1)),
                ),
              ],
            )),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((l) => Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)))).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Demo Data ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _demoRecords() => [
    {"title": "Cardiology Review", "date": "25 Apr 2026", "doctor": "Dr. Rajesh Mehta", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "BP 132/84. Continue all meds. May reduce Metformin if HbA1c stays below 5.7%."},
    {"title": "Quarterly Review — HbA1c 5.8%", "date": "20 Apr 2026", "doctor": "SRL Diagnostics", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"HbA1c": 5.8, "Glucose": 102, "Cholesterol": 210, "Creatinine": 0.9}, "summary": "Excellent improvement. HbA1c down to 5.8% from 7.2%."},
    {"title": "Liver Function Test", "date": "10 Mar 2026", "doctor": "Dr. Vikram Shah", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"SGPT/ALT": 52}, "summary": "SGPT mildly elevated. Grade 1 Fatty Liver on USG."},
    {"title": "Diabetes Management — Metformin Started", "date": "20 Feb 2026", "doctor": "Dr. Kavita Rao", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "Metformin 500mg BD started. Ecosprin stopped (GI discomfort)."},
    {"title": "Post-Diwali Blood Work — HbA1c 7.2%", "date": "15 Jan 2026", "doctor": "SRL Diagnostics", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"HbA1c": 7.2, "Glucose": 148, "Cholesterol": 225}, "summary": "HbA1c spiked to 7.2%. Dietary lapse during festivals."},
    {"title": "TMT Report — Negative", "date": "25 Aug 2025", "doctor": "Dr. Rajesh Mehta", "type": "medical_services", "color": "#6B4E9B", "category": "Reports", "summary": "TMT Negative for ischemia. Exercise capacity good."},
    {"title": "Cardiology Follow-up — Atorvastatin Increased", "date": "10 Aug 2025", "doctor": "Dr. Rajesh Mehta", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "BP 142/92. Atorvastatin increased to 20mg. Fish Oil added."},
    {"title": "Baseline Blood Work — HbA1c 6.8%", "date": "20 Jun 2025", "doctor": "SRL Diagnostics", "type": "science", "color": "#00A3A3", "category": "Labs", "labValues": {"HbA1c": 6.8, "Glucose": 126, "Cholesterol": 245, "Hemoglobin": 14.2, "TSH": 3.2}, "summary": "HbA1c 6.8% (Pre-diabetic). High cholesterol. High triglycerides."},
    {"title": "Initial Prescription — Telmisartan + Atorvastatin", "date": "15 May 2025", "doctor": "Dr. Kavita Rao", "type": "medication", "color": "#E07B39", "category": "Prescriptions", "summary": "Telmisartan 40mg, Atorvastatin 10mg, Ecosprin 75mg started."},
  ];

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String currentTab = tabs[activeTab];
    final filteredRecords = currentTab == "All"
        ? allRecords
        : allRecords.where((r) => r['category'] == currentTab).toList();

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
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240)))),
                const SizedBox(width: 12),
                const TranslatedText("Health Records", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D2240))),
                const Spacer(),
                Text("${allRecords.length}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3))),
                const SizedBox(width: 4),
                const Text("records", style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
              ],
            ),
          ),
          // Tab Bar
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final isActive = index == activeTab;
                return GestureDetector(
                  onTap: () => setState(() => activeTab = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)] : [],
                    ),
                    alignment: Alignment.center,
                    child: TranslatedText(tabs[index],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
                  ),
                );
              },
            ),
          ),
          // Records List
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : currentTab == "Trends"
                ? _buildTrendsView()
                : filteredRecords.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        final originalIndex = allRecords.indexOf(record);
                        // Use localId for real records, or hashCode for demo/unsaved records to guarantee uniqueness
                        final uniqueKey = record['localId']?.toString() ?? record.hashCode.toString();
                        return Dismissible(
                          key: Key(uniqueKey),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: const Color(0xFFD63B3B), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteRecord(originalIndex),
                          child: _buildRecordCard(record),
                        );
                      },
                    ),
          ),
          // Scan button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/doc-scan'),
              icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              label: const TranslatedText("Scan New Document", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A3A3),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const TranslatedText("No records found", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          const TranslatedText("Scan a document to get started", style: TextStyle(fontSize: 13, color: Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final hasData = record['hasFullData'] == true;
    return GestureDetector(
      onTap: () => _openRecord(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8DDE6)),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Color(int.parse((record['color'] ?? '#00A3A3').replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(_getIcon(record['type'] ?? 'description'), size: 24, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(record['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(record['doctor'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(record['date'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                const SizedBox(height: 4),
                Icon(hasData ? Icons.visibility : Icons.arrow_forward_ios,
                  size: 16, color: hasData ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 78,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFD8DDE6)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
          _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
          _scanButton(context),
          _navItem(Icons.list_alt, "Records", true, null),
          _navItem(Icons.share, "Share", false, () => Navigator.pushNamed(context, '/qr-share')),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
        TranslatedText(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
      ]),
    );
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