/// ─── CureNet Demo Persona ──────────────────────────────────────────────────
/// Single source of truth for Arjun Mishra's clinical profile.
/// Used by: HomeScreen, ProfileScreen, RecordsScreen, EmergencySnapshotScreen,
///          AiService, ChatScreen.
///
/// In production this class would be populated from ABDM profile API + local vault.

class Persona {
  // ─── IDENTITY ──────────────────────────────────────────────────────────────
  static const String name = 'Arjun Mishra';
  static const String abhaNumber = '91-4567-8901-2345';
  static const String abhaAddress = 'arjun.mishra@abdm';
  static const String dob = '12 Aug 1979';
  static const int age = 45;
  static const String gender = 'Male';
  static const String bloodGroup = 'O+';
  static const String mobile = '+91 95099 58988';
  static const String email = 'arjun.kumar@gmail.com';
  static const String address = 'Flat 402, Sunshine Apts, HSR Layout, Bengaluru 560102';

  // ─── EMERGENCY INFO ────────────────────────────────────────────────────────
  static const String emergencyContact = '+91 95099 58989 (Sneha Kumar - Wife)';
  static const String emergencyPhone = '+91 95099 58989';
  static const String emergencyRelation = 'Sneha Kumar (Wife)';
  static const String insuranceId = 'PMJAY-KA-20240092';

  // ─── MEDICAL CONDITIONS ────────────────────────────────────────────────────
  static const List<String> conditions = [
    'Essential Hypertension (Since May 2025)',
    'Dyslipidemia (High Cholesterol) (Since May 2025)',
    'Type 2 Diabetes Mellitus (Since Feb 2026)',
    'Mild Fatty Liver (Grade 1)',
  ];
  static const String conditionsShort = 'Hypertension, Diabetes, High Cholesterol';

  // ─── ALLERGIES ─────────────────────────────────────────────────────────────
  static const List<String> allergies = ['Sulfa Drugs', 'Dust Mites'];
  static const String allergiesShort = 'Sulfa Drugs, Dust';

  // ─── ACTIVE MEDICATIONS ────────────────────────────────────────────────────
  static const List<Map<String, String>> medications = [
    {'name': 'Metformin', 'dosage': '500mg', 'frequency': 'Twice daily (after meals)', 'for': 'Type 2 Diabetes'},
    {'name': 'Telmisartan', 'dosage': '40mg', 'frequency': 'Once daily (morning)', 'for': 'Hypertension'},
    {'name': 'Atorvastatin', 'dosage': '20mg', 'frequency': 'Once daily (night)', 'for': 'Cholesterol'},
    {'name': 'Fish Oil', 'dosage': '1000mg', 'frequency': 'Once daily', 'for': 'Heart Health'},
  ];

  // ─── LATEST VITALS ─────────────────────────────────────────────────────────
  static const Map<String, String> vitals = {
    'Blood Pressure': '132/84 mmHg',
    'Total Cholesterol': '210 mg/dL',
    'LDL': '145 mg/dL (High)',
    'HDL': '42 mg/dL',
    'Triglycerides': '180 mg/dL',
    'HbA1c': '5.8% (Normal)',
    'BMI': '27.2 (Overweight)',
    'Weight': '82 kg',
    'Height': '174 cm',
  };

  // ─── PHYSICIANS ────────────────────────────────────────────────────────────
  static const Map<String, String> primaryPhysician = {
    'name': 'Dr. Rajesh Mehta',
    'specialty': 'Cardiologist',
    'hospital': 'Manipal Hospital, Bengaluru',
    'phone': '+91 80234 56789',
  };

  static const List<Map<String, String>> doctors = [
    {'name': 'Dr. Rajesh Mehta', 'specialty': 'Cardiology', 'hospital': 'Manipal Hospital'},
    {'name': 'Dr. Kavita Rao', 'specialty': 'General Physician', 'hospital': 'Cloudnine Clinics'},
    {'name': 'Dr. Vikram Shah', 'specialty': 'Gastroenterologist', 'hospital': 'Aster CMI'},
  ];

  // ─── MEDICAL HISTORY (TIMELINE) ───────────────────────────────────────────
  static const List<Map<String, String>> history = [
    {'date': '25 Apr 2026', 'event': 'Cardiology Review — BP 132/84, may reduce Metformin', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Prescriptions'},
    {'date': '20 Apr 2026', 'event': 'Quarterly Review — HbA1c improved to 5.8%', 'doctor': 'SRL Diagnostics', 'category': 'Labs'},
    {'date': '10 Mar 2026', 'event': 'Liver Function Test — Mild ALT elevation, Grade 1 Fatty Liver', 'doctor': 'Dr. Vikram Shah', 'category': 'Labs'},
    {'date': '20 Feb 2026', 'event': 'Metformin 500mg started for newly diagnosed Type 2 Diabetes', 'doctor': 'Dr. Kavita Rao', 'category': 'Prescriptions'},
    {'date': '15 Jan 2026', 'event': 'Post-Diwali Blood Work — HbA1c spiked to 7.2%', 'doctor': 'SRL Diagnostics', 'category': 'Labs'},
    {'date': '25 Aug 2025', 'event': 'TMT Report — Negative for Ischemia', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Reports'},
    {'date': '10 Aug 2025', 'event': 'Atorvastatin increased to 20mg, Fish Oil added', 'doctor': 'Dr. Rajesh Mehta', 'category': 'Prescriptions'},
    {'date': '20 Jun 2025', 'event': 'Baseline Blood Work — HbA1c 6.8%, Cholesterol 245', 'doctor': 'SRL Diagnostics', 'category': 'Labs'},
    {'date': '15 May 2025', 'event': 'Initial diagnosis — Hypertension & Dyslipidemia. Telmisartan + Atorvastatin started', 'doctor': 'Dr. Kavita Rao', 'category': 'Prescriptions'},
  ];

  // ─── PROFILE MAP (for legacy SharedPreferences consumers) ─────────────────
  static Map<String, String> get profileMap => {
    'name': name,
    'abha': abhaNumber,
    'dob': dob,
    'mobile': mobile,
    'bloodGroup': bloodGroup,
    'allergies': allergiesShort,
    'emergencyContact': '$emergencyRelation — $emergencyPhone',
    'physician': '${primaryPhysician['name']}\n${primaryPhysician['specialty']}',
    'conditions': conditionsShort,
  };

  // ─── AI SYSTEM PROMPT CONTEXT ──────────────────────────────────────────────
  static String get aiContext => '''
PATIENT PERSONA:
- Name: $name
- Age: $age (DOB: $dob)
- Gender: $gender
- Blood Group: $bloodGroup
- ABHA: $abhaNumber
- Address: $address

CONDITIONS:
${conditions.map((c) => '- $c').join('\n')}

ALLERGIES:
${allergies.map((a) => '- $a (CRITICAL — do NOT suggest medications containing this)').join('\n')}

ACTIVE MEDICATIONS:
${medications.map((m) => '- ${m['name']} ${m['dosage']} — ${m['frequency']} (for ${m['for']})').join('\n')}

LATEST VITALS:
${vitals.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

PRIMARY PHYSICIAN:
- ${primaryPhysician['name']} (${primaryPhysician['specialty']})
- ${primaryPhysician['hospital']}
- Phone: ${primaryPhysician['phone']}

MEDICAL HISTORY (most recent first):
${history.map((h) => '- [${h['date']}] ${h['event']} — ${h['doctor']}').join('\n')}

EMERGENCY CONTACT:
- $emergencyRelation — $emergencyPhone
''';
}
