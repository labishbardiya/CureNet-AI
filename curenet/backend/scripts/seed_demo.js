/**
 * CureNet Demo Seeder — Seeds MongoDB with a rich longitudinal patient history.
 * Patient: Arjun Mishra (matches Persona.dart)
 * Run: node scripts/seed_demo.js
 */
const mongoose = require('mongoose');
const Record = require('../src/models/recordModel');
const { generateEmbedding } = require('../src/services/embeddingService');
require('dotenv').config();

const RECORDS = [
  // ── Visit 1: Initial Diagnosis (12 months ago) ──
  {
    jobId: 'demo-rx-001',
    status: 'completed',
    confidence_score: 0.95,
    abdmContext: { documentType: 'prescription', displayString: 'General Consultation — Dr. Kavita Rao', hiType: 'Prescription' },
    raw_text: 'Prescription — Dr. Kavita Rao, Cloudnine Clinics, Bengaluru. Patient: Arjun Mishra, 45M. Diagnosis: Essential Hypertension Stage 1, Dyslipidemia. Rx: Tab Telmisartan 40mg — 1 OD (morning, before food). Tab Atorvastatin 10mg — 1 OD (night, after dinner). Tab Ecosprin 75mg — 1 OD (after lunch). Advice: Low salt diet, 30 min walk daily, avoid fried food, review after 3 months with lipid profile.',
    uiData: {
      document_type: 'prescription',
      summary: { patient: 'Arjun Mishra', doctor: 'Dr. Kavita Rao', date: '2025-05-15', diagnosis: 'Essential Hypertension, Dyslipidemia' },
      medications: [
        { name: 'Telmisartan', dosage: '40mg', frequency: 'Once daily (morning)', duration: 'Ongoing', purpose: 'Hypertension' },
        { name: 'Atorvastatin', dosage: '10mg', frequency: 'Once daily (night)', duration: 'Ongoing', purpose: 'Cholesterol' },
        { name: 'Ecosprin', dosage: '75mg', frequency: 'Once daily', duration: 'Ongoing', purpose: 'Blood Thinner' },
      ],
      lab_results: [],
    },
    clinical_atoms: [
      { type: 'medication', name: 'Telmisartan', value: '40mg', unit: 'mg', date: '2025-05-15' },
      { type: 'medication', name: 'Atorvastatin', value: '10mg', unit: 'mg', date: '2025-05-15' },
      { type: 'medication', name: 'Ecosprin', value: '75mg', unit: 'mg', date: '2025-05-15' },
      { type: 'condition', name: 'Essential Hypertension', value: 'Stage 1', date: '2025-05-15' },
      { type: 'condition', name: 'Dyslipidemia', value: 'Diagnosed', date: '2025-05-15' },
    ],
    createdAt: new Date('2025-05-15T10:00:00Z'),
  },

  // ── Visit 2: First Lab Report (11 months ago) ──
  {
    jobId: 'demo-lab-001',
    status: 'completed',
    confidence_score: 0.92,
    abdmContext: { documentType: 'lab_report', displayString: 'Baseline Blood Work — SRL Diagnostics', hiType: 'DiagnosticReport' },
    raw_text: 'Lab Report — SRL Diagnostics, Bengaluru. Patient: Arjun Mishra, 45/M. Date: 20-Jun-2025. Tests: HbA1c: 6.8% (Pre-diabetic), Fasting Blood Sugar: 126 mg/dL (High), Total Cholesterol: 245 mg/dL (High), LDL: 165 mg/dL (High), HDL: 38 mg/dL (Low), Triglycerides: 210 mg/dL (High), Hemoglobin: 14.2 g/dL, Creatinine: 0.9 mg/dL, TSH: 3.2 uIU/mL.',
    uiData: {
      document_type: 'lab_report',
      summary: { patient: 'Arjun Mishra', doctor: 'SRL Diagnostics', date: '2025-06-20', diagnosis: 'Baseline Blood Work' },
      medications: [],
      lab_results: [
        { test_name: 'HbA1c', value: 6.8, unit: '%', reference_range: '4.0-5.6', status: 'High' },
        { test_name: 'Fasting Blood Sugar', value: 126, unit: 'mg/dL', reference_range: '70-100', status: 'High' },
        { test_name: 'Total Cholesterol', value: 245, unit: 'mg/dL', reference_range: '<200', status: 'High' },
        { test_name: 'LDL Cholesterol', value: 165, unit: 'mg/dL', reference_range: '<100', status: 'High' },
        { test_name: 'HDL Cholesterol', value: 38, unit: 'mg/dL', reference_range: '>40', status: 'Low' },
        { test_name: 'Triglycerides', value: 210, unit: 'mg/dL', reference_range: '<150', status: 'High' },
        { test_name: 'Hemoglobin', value: 14.2, unit: 'g/dL', reference_range: '13-17', status: 'Normal' },
        { test_name: 'Creatinine', value: 0.9, unit: 'mg/dL', reference_range: '0.7-1.3', status: 'Normal' },
        { test_name: 'TSH', value: 3.2, unit: 'uIU/mL', reference_range: '0.4-4.0', status: 'Normal' },
      ],
    },
    clinical_atoms: [
      { type: 'observation', name: 'HbA1c', value: '6.8', unit: '%', date: '2025-06-20' },
      { type: 'observation', name: 'Fasting Blood Sugar', value: '126', unit: 'mg/dL', date: '2025-06-20' },
      { type: 'observation', name: 'Total Cholesterol', value: '245', unit: 'mg/dL', date: '2025-06-20' },
      { type: 'observation', name: 'Hemoglobin', value: '14.2', unit: 'g/dL', date: '2025-06-20' },
      { type: 'observation', name: 'TSH', value: '3.2', unit: 'uIU/mL', date: '2025-06-20' },
    ],
    createdAt: new Date('2025-06-20T09:00:00Z'),
  },

  // ── Visit 3: Medication Adjustment (8 months ago) ──
  {
    jobId: 'demo-rx-002',
    status: 'completed',
    confidence_score: 0.93,
    abdmContext: { documentType: 'prescription', displayString: 'Follow-up — Dr. Rajesh Mehta (Cardiology)', hiType: 'Prescription' },
    raw_text: 'Prescription — Dr. Rajesh Mehta, Manipal Hospital, Bengaluru. Patient: Arjun Mishra, 45M. Follow-up for Hypertension & Dyslipidemia. BP today: 142/92 mmHg. Increased Atorvastatin to 20mg. Added Fish Oil 1000mg for HDL improvement. Continue Telmisartan 40mg. Advised TMT (Treadmill Test). Review in 3 months.',
    uiData: {
      document_type: 'prescription',
      summary: { patient: 'Arjun Mishra', doctor: 'Dr. Rajesh Mehta', date: '2025-08-10', diagnosis: 'Hypertension Follow-up' },
      medications: [
        { name: 'Telmisartan', dosage: '40mg', frequency: 'Once daily (morning)', duration: 'Ongoing', purpose: 'Hypertension' },
        { name: 'Atorvastatin', dosage: '20mg', frequency: 'Once daily (night)', duration: 'Ongoing', purpose: 'Cholesterol (Increased)' },
        { name: 'Fish Oil', dosage: '1000mg', frequency: 'Once daily', duration: 'Ongoing', purpose: 'HDL Improvement' },
        { name: 'Ecosprin', dosage: '75mg', frequency: 'Once daily', duration: 'Ongoing', purpose: 'Blood Thinner' },
      ],
      lab_results: [],
    },
    clinical_atoms: [
      { type: 'observation', name: 'Blood Pressure', value: '142/92', unit: 'mmHg', date: '2025-08-10' },
      { type: 'medication', name: 'Atorvastatin', value: '20mg (increased from 10mg)', unit: 'mg', date: '2025-08-10' },
      { type: 'medication', name: 'Fish Oil', value: '1000mg', unit: 'mg', date: '2025-08-10' },
    ],
    createdAt: new Date('2025-08-10T11:00:00Z'),
  },

  // ── Visit 4: TMT Report (7 months ago) ──
  {
    jobId: 'demo-rpt-001',
    status: 'completed',
    confidence_score: 0.90,
    abdmContext: { documentType: 'other', displayString: 'TMT Report — Manipal Hospital', hiType: 'DiagnosticReport' },
    raw_text: 'Treadmill Test (TMT) Report — Manipal Hospital. Patient: Arjun Mishra, 45M. Protocol: Bruce. Duration: 9 minutes 12 seconds. Peak HR: 156 bpm (89% predicted). BP at peak: 178/88. ST changes: None significant. Conclusion: NEGATIVE for inducible ischemia. Exercise capacity: Good. Advice: Continue current medications, annual repeat recommended.',
    uiData: {
      document_type: 'other',
      summary: { patient: 'Arjun Mishra', doctor: 'Dr. Rajesh Mehta', date: '2025-08-25', diagnosis: 'TMT — Negative for Ischemia' },
      medications: [],
      lab_results: [],
    },
    clinical_atoms: [
      { type: 'observation', name: 'TMT Result', value: 'Negative for Ischemia', date: '2025-08-25' },
      { type: 'observation', name: 'Exercise Capacity', value: 'Good (9m12s Bruce Protocol)', date: '2025-08-25' },
    ],
    createdAt: new Date('2025-08-25T14:00:00Z'),
  },

  // ── Visit 5: Festival Spike Lab (4 months ago) ──
  {
    jobId: 'demo-lab-002',
    status: 'completed',
    confidence_score: 0.94,
    abdmContext: { documentType: 'lab_report', displayString: 'Post-Diwali Blood Work — SRL Diagnostics', hiType: 'DiagnosticReport' },
    raw_text: 'Lab Report — SRL Diagnostics. Patient: Arjun Mishra. Date: 15-Jan-2026. HbA1c: 7.2% (HIGH — worsened from 6.8%). Fasting Blood Sugar: 148 mg/dL (High). Total Cholesterol: 225 mg/dL (Borderline High). LDL: 152 mg/dL (High). HDL: 41 mg/dL (Borderline). Triglycerides: 195 mg/dL (High). Note: Post-festival dietary lapse suspected.',
    uiData: {
      document_type: 'lab_report',
      summary: { patient: 'Arjun Mishra', doctor: 'SRL Diagnostics', date: '2026-01-15', diagnosis: 'Post-Diwali Blood Work — Worsened Glycemic Control' },
      medications: [],
      lab_results: [
        { test_name: 'HbA1c', value: 7.2, unit: '%', reference_range: '4.0-5.6', status: 'High' },
        { test_name: 'Fasting Blood Sugar', value: 148, unit: 'mg/dL', reference_range: '70-100', status: 'High' },
        { test_name: 'Total Cholesterol', value: 225, unit: 'mg/dL', reference_range: '<200', status: 'Borderline High' },
        { test_name: 'LDL Cholesterol', value: 152, unit: 'mg/dL', reference_range: '<100', status: 'High' },
        { test_name: 'HDL Cholesterol', value: 41, unit: 'mg/dL', reference_range: '>40', status: 'Borderline' },
        { test_name: 'Triglycerides', value: 195, unit: 'mg/dL', reference_range: '<150', status: 'High' },
      ],
    },
    clinical_atoms: [
      { type: 'observation', name: 'HbA1c', value: '7.2', unit: '%', date: '2026-01-15' },
      { type: 'observation', name: 'Fasting Blood Sugar', value: '148', unit: 'mg/dL', date: '2026-01-15' },
      { type: 'observation', name: 'Total Cholesterol', value: '225', unit: 'mg/dL', date: '2026-01-15' },
    ],
    createdAt: new Date('2026-01-15T09:30:00Z'),
  },

  // ── Visit 6: Medication Escalation (3 months ago) ──
  {
    jobId: 'demo-rx-003',
    status: 'completed',
    confidence_score: 0.95,
    abdmContext: { documentType: 'prescription', displayString: 'Diabetes Management — Dr. Kavita Rao', hiType: 'Prescription' },
    raw_text: 'Prescription — Dr. Kavita Rao, Cloudnine Clinics. Patient: Arjun Mishra. HbA1c has risen to 7.2%. Starting Metformin 500mg BD. Continue Telmisartan 40mg, Atorvastatin 20mg, Fish Oil 1000mg. Stop Ecosprin (GI discomfort reported). Strict diabetic diet. Recheck HbA1c in 3 months.',
    uiData: {
      document_type: 'prescription',
      summary: { patient: 'Arjun Mishra', doctor: 'Dr. Kavita Rao', date: '2026-02-20', diagnosis: 'Type 2 Diabetes — New Diagnosis, Ongoing Hypertension' },
      medications: [
        { name: 'Metformin', dosage: '500mg', frequency: 'Twice daily (after meals)', duration: 'Ongoing', purpose: 'Diabetes (NEW)' },
        { name: 'Telmisartan', dosage: '40mg', frequency: 'Once daily (morning)', duration: 'Ongoing', purpose: 'Hypertension' },
        { name: 'Atorvastatin', dosage: '20mg', frequency: 'Once daily (night)', duration: 'Ongoing', purpose: 'Cholesterol' },
        { name: 'Fish Oil', dosage: '1000mg', frequency: 'Once daily', duration: 'Ongoing', purpose: 'Heart Health' },
      ],
      lab_results: [],
    },
    clinical_atoms: [
      { type: 'medication', name: 'Metformin', value: '500mg BD (NEW)', unit: 'mg', date: '2026-02-20' },
      { type: 'condition', name: 'Type 2 Diabetes Mellitus', value: 'Newly Diagnosed', date: '2026-02-20' },
      { type: 'medication', name: 'Ecosprin', value: 'STOPPED (GI discomfort)', date: '2026-02-20' },
    ],
    createdAt: new Date('2026-02-20T10:30:00Z'),
  },

  // ── Visit 7: Liver Check (2 months ago) ──
  {
    jobId: 'demo-rpt-002',
    status: 'completed',
    confidence_score: 0.91,
    abdmContext: { documentType: 'lab_report', displayString: 'Liver Function Test — Aster CMI', hiType: 'DiagnosticReport' },
    raw_text: 'Lab Report — Aster CMI Hospital. Patient: Arjun Mishra. Date: 10-Mar-2026. LFT: SGPT/ALT: 52 U/L (mildly elevated), SGOT/AST: 38 U/L (Normal), ALP: 95 U/L (Normal), Bilirubin Total: 0.8 mg/dL (Normal). USG Abdomen: Grade 1 Fatty Liver, no focal lesion. Dr. Vikram Shah — Continue Atorvastatin, monitor ALT in 3 months.',
    uiData: {
      document_type: 'lab_report',
      summary: { patient: 'Arjun Mishra', doctor: 'Dr. Vikram Shah', date: '2026-03-10', diagnosis: 'Mild Fatty Liver, Elevated ALT' },
      medications: [],
      lab_results: [
        { test_name: 'SGPT/ALT', value: 52, unit: 'U/L', reference_range: '7-56', status: 'Mildly Elevated' },
        { test_name: 'SGOT/AST', value: 38, unit: 'U/L', reference_range: '10-40', status: 'Normal' },
        { test_name: 'ALP', value: 95, unit: 'U/L', reference_range: '44-147', status: 'Normal' },
        { test_name: 'Bilirubin', value: 0.8, unit: 'mg/dL', reference_range: '0.1-1.2', status: 'Normal' },
      ],
    },
    clinical_atoms: [
      { type: 'observation', name: 'SGPT/ALT', value: '52', unit: 'U/L', date: '2026-03-10' },
      { type: 'condition', name: 'Fatty Liver', value: 'Grade 1', date: '2026-03-10' },
    ],
    createdAt: new Date('2026-03-10T11:00:00Z'),
  },

  // ── Visit 8: Latest Follow-up with IMPROVED numbers (Recent) ──
  {
    jobId: 'demo-lab-003',
    status: 'completed',
    confidence_score: 0.96,
    abdmContext: { documentType: 'lab_report', displayString: 'Quarterly Review — SRL Diagnostics', hiType: 'DiagnosticReport' },
    raw_text: 'Lab Report — SRL Diagnostics. Patient: Arjun Mishra. Date: 20-Apr-2026. HbA1c: 5.8% (IMPROVED — was 7.2%). Fasting Blood Sugar: 102 mg/dL (Borderline). Total Cholesterol: 210 mg/dL (Borderline). LDL: 145 mg/dL (Improved). HDL: 42 mg/dL. Triglycerides: 180 mg/dL. Creatinine: 0.9 mg/dL. Note: Excellent response to Metformin + lifestyle changes.',
    uiData: {
      document_type: 'lab_report',
      summary: { patient: 'Arjun Mishra', doctor: 'SRL Diagnostics', date: '2026-04-20', diagnosis: 'Quarterly Review — Excellent Improvement' },
      medications: [],
      lab_results: [
        { test_name: 'HbA1c', value: 5.8, unit: '%', reference_range: '4.0-5.6', status: 'Near Normal' },
        { test_name: 'Fasting Blood Sugar', value: 102, unit: 'mg/dL', reference_range: '70-100', status: 'Borderline' },
        { test_name: 'Total Cholesterol', value: 210, unit: 'mg/dL', reference_range: '<200', status: 'Borderline' },
        { test_name: 'LDL Cholesterol', value: 145, unit: 'mg/dL', reference_range: '<100', status: 'High' },
        { test_name: 'HDL Cholesterol', value: 42, unit: 'mg/dL', reference_range: '>40', status: 'Normal' },
        { test_name: 'Triglycerides', value: 180, unit: 'mg/dL', reference_range: '<150', status: 'High' },
        { test_name: 'Creatinine', value: 0.9, unit: 'mg/dL', reference_range: '0.7-1.3', status: 'Normal' },
      ],
    },
    clinical_atoms: [
      { type: 'observation', name: 'HbA1c', value: '5.8', unit: '%', date: '2026-04-20' },
      { type: 'observation', name: 'Fasting Blood Sugar', value: '102', unit: 'mg/dL', date: '2026-04-20' },
      { type: 'observation', name: 'Total Cholesterol', value: '210', unit: 'mg/dL', date: '2026-04-20' },
      { type: 'observation', name: 'Creatinine', value: '0.9', unit: 'mg/dL', date: '2026-04-20' },
    ],
    createdAt: new Date('2026-04-20T09:00:00Z'),
  },

  // ── Visit 9: Latest Cardiology Follow-up ──
  {
    jobId: 'demo-rx-004',
    status: 'completed',
    confidence_score: 0.94,
    abdmContext: { documentType: 'prescription', displayString: 'Cardiology Review — Dr. Rajesh Mehta', hiType: 'Prescription' },
    raw_text: 'Prescription — Dr. Rajesh Mehta, Manipal Hospital. Patient: Arjun Mishra. BP: 132/84 mmHg (well controlled). HbA1c improved to 5.8%. Continue all current medications. Reduce Metformin to 500mg OD if next HbA1c is below 5.7%. Annual TMT recommended. Next visit: 3 months.',
    uiData: {
      document_type: 'prescription',
      summary: { patient: 'Arjun Mishra', doctor: 'Dr. Rajesh Mehta', date: '2026-04-25', diagnosis: 'Stable Hypertension, Diabetes Under Control' },
      medications: [
        { name: 'Metformin', dosage: '500mg', frequency: 'Twice daily', duration: 'May reduce', purpose: 'Diabetes' },
        { name: 'Telmisartan', dosage: '40mg', frequency: 'Once daily (morning)', duration: 'Ongoing', purpose: 'Hypertension' },
        { name: 'Atorvastatin', dosage: '20mg', frequency: 'Once daily (night)', duration: 'Ongoing', purpose: 'Cholesterol' },
        { name: 'Fish Oil', dosage: '1000mg', frequency: 'Once daily', duration: 'Ongoing', purpose: 'Heart Health' },
      ],
      lab_results: [],
    },
    clinical_atoms: [
      { type: 'observation', name: 'Blood Pressure', value: '132/84', unit: 'mmHg', date: '2026-04-25' },
    ],
    createdAt: new Date('2026-04-25T15:00:00Z'),
  },
];

async function seed() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected. Clearing old demo records...');
  
  // Clear existing demo records
  await Record.deleteMany({ jobId: { $regex: /^demo-/ } });
  console.log('Old demo data cleared.');

  let success = 0, failed = 0;

  for (const data of RECORDS) {
    console.log(`Seeding: ${data.abdmContext.displayString}...`);
    try {
      const text = data.raw_text.substring(0, 6000).replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
      data.vector_embedding = await generateEmbedding(text);
      
      // Check if real vector was returned
      if (data.vector_embedding[0] === 0 && data.vector_embedding[1] === 0) {
        console.log('  ⚠️  Fallback vector used (API unavailable)');
      } else {
        console.log('  ✅ NVIDIA 1024-dim vector generated');
      }
      
      await Record.create(data);
      success++;
    } catch (e) {
      console.log(`  ❌ Failed: ${e.message}`);
      failed++;
    }
  }

  console.log(`\n════════════════════════════════════════`);
  console.log(`  SEEDING COMPLETE: ${success} success, ${failed} failed`);
  console.log(`  Records in DB: ${await Record.countDocuments()}`);
  console.log(`════════════════════════════════════════\n`);
  process.exit(0);
}

seed().catch(e => { console.error(e); process.exit(1); });
