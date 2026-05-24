const crypto = require('crypto');
const { lookupMedicationSnomed, lookupRoute, lookupLabTestCode } = require('./snomedMap');

function generateId() {
    return crypto.randomUUID();
}

/**
 * ═══════════════════════════════════════════════════════════════════
 *  ABDM-Compliant FHIR R4 Bundle Builder (v3)
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Generates a valid FHIR R4 Document Bundle for:
 *    - Prescriptions  → Composition + MedicationRequest resources
 *    - Lab Reports    → Composition + DiagnosticReport + Observation resources
 *
 *  Conforms to:
 *    - FHIR R4 (v4.0.1)
 *    - ABDM Health Information Exchange specifications
 *    - NRCeS (National Resource Centre for EHR Standards) profiles
 *
 *  STRICT RULES enforced:
 *    - No empty SNOMED codes (uses snomedMap.js lookup)
 *    - No placeholder values
 *    - No duplicate entries
 *    - All FHIR references must be valid
 *    - Composition must be first entry
 */

// ─── Shared Resource Builders ────────────────────────────────────────────────

function buildOrganizationResource(orgId, data) {
    return {
        fullUrl: `urn:uuid:${orgId}`,
        resource: {
            resourceType: "Organization",
            id: orgId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/Organization"]
            },
            identifier: [{
                system: "https://facility.ndhm.gov.in",
                value: data.facility_id || "unknown"
            }],
            name: data.clinic || "Unknown Healthcare Facility",
            active: true
        }
    };
}

function buildPatientResource(patientId, data) {
    const resource = {
        fullUrl: `urn:uuid:${patientId}`,
        resource: {
            resourceType: "Patient",
            id: patientId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/Patient"]
            },
            identifier: [{
                system: "https://healthid.ndhm.gov.in",
                value: data.abha_number || data.abha_id || "unknown",
                type: {
                    coding: [{
                        system: "http://terminology.hl7.org/CodeSystem/v2-0203",
                        code: "MR",
                        display: "Medical record number"
                    }]
                }
            }],
            name: [{
                text: data.patient_name || "Unknown Patient",
                use: "official"
            }],
            gender: data.gender || "unknown"
        }
    };

    if (data.age) {
        resource.resource.extension = resource.resource.extension || [];
        resource.resource.extension.push({
            url: "https://nrces.in/ndhm/fhir/r4/StructureDefinition/Age",
            valueString: data.age
        });
    }

    return resource;
}

function buildPractitionerResource(doctorId, data) {
    const resource = {
        fullUrl: `urn:uuid:${doctorId}`,
        resource: {
            resourceType: "Practitioner",
            id: doctorId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/Practitioner"]
            },
            identifier: [{
                system: "https://doctor.ndhm.gov.in",
                value: data.doctor_reg_no || "unknown"
            }],
            name: [{
                text: data.doctor_name || "Unknown Practitioner",
                use: "official"
            }]
        }
    };

    if (data.clinic) {
        resource.resource.qualification = [{
            code: { text: data.clinic }
        }];
    }

    return resource;
}

function buildEncounterResource(encounterId, patientId, date) {
    return {
        fullUrl: `urn:uuid:${encounterId}`,
        resource: {
            resourceType: "Encounter",
            id: encounterId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/Encounter"]
            },
            status: "finished",
            class: {
                system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                code: "AMB",
                display: "ambulatory"
            },
            subject: { reference: `urn:uuid:${patientId}` },
            period: { start: date }
        }
    };
}

// ═══════════════════════════════════════════════════════════════════
//  PRESCRIPTION BUNDLE BUILDER
// ═══════════════════════════════════════════════════════════════════

function buildPrescriptionBundle(structuredData) {
    const timestamp = new Date().toISOString();
    const bundleId = generateId();
    const patientId = generateId();
    const doctorId = generateId();
    const orgId = generateId();
    const encounterId = generateId();
    const compositionId = generateId();
    const prescriptionDate = structuredData.date || timestamp.split('T')[0];

    const medications = structuredData.medications || [];

    // Deduplicate medications by name+frequency
    const dedupMap = new Map();
    medications.forEach(med => {
        const key = `${(med.name || '').toLowerCase()}|${med.frequency || ''}`;
        if (!dedupMap.has(key)) {
            dedupMap.set(key, med);
        }
    });
    const uniqueMeds = [...dedupMap.values()];

    const medicationSectionEntries = [];
    const medicationRequestEntries = [];
    const observationEntries = [];

    // ─── Build Vitals as Observations ────────────────────────────────
    if (structuredData.vitals) {
        const vitals = structuredData.vitals;
        const mapping = {
            bp: { code: "85354-9", display: "Blood pressure panel", system: "http://loinc.org" },
            pulse: { code: "8867-4", display: "Heart rate", system: "http://loinc.org" },
            temperature: { code: "8310-5", display: "Body temperature", system: "http://loinc.org" },
            weight: { code: "29463-7", display: "Body weight", system: "http://loinc.org" }
        };

        for (const [key, value] of Object.entries(vitals)) {
            if (value && mapping[key]) {
                const obsId = generateId();
                const map = mapping[key];
                
                const observation = {
                    fullUrl: `urn:uuid:${obsId}`,
                    resource: {
                        resourceType: "Observation",
                        id: obsId,
                        meta: { profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/Observation"] },
                        status: "final",
                        code: {
                            coding: [{ system: map.system, code: map.code, display: map.display }],
                            text: map.display
                        },
                        subject: { reference: `urn:uuid:${patientId}` },
                        effectiveDateTime: prescriptionDate,
                        valueString: String(value)
                    }
                };
                observationEntries.push(observation);
            }
        }
    }

    uniqueMeds.forEach(med => {
        const medRequestId = generateId();
        medicationSectionEntries.push({ reference: `urn:uuid:${medRequestId}` });

        // Build dosageInstruction
        const dosageInstruction = { text: formatDosageText(med) };

        // Timing from frequency pattern (e.g. "2+0+2")
        const freqPattern = (med.frequency || '').match(/^(\d)\+(\d)\+(\d)$/);
        if (freqPattern) {
            const [_, morning, afternoon, night] = freqPattern;
            const totalPerDay = parseInt(morning) + parseInt(afternoon) + parseInt(night);
            dosageInstruction.timing = {
                repeat: { frequency: totalPerDay, period: 1, periodUnit: "d" }
            };
            dosageInstruction.additionalInstruction = [{
                text: `Morning: ${morning}, Afternoon: ${afternoon}, Night: ${night}`
            }];
        }

        // Dose quantity
        const doseMatch = (med.dosage || '').match(/(\d+)\s*(mg|ml|mcg|gm|g|IU)/i);
        if (doseMatch) {
            dosageInstruction.doseAndRate = [{
                doseQuantity: {
                    value: parseInt(doseMatch[1]),
                    unit: doseMatch[2].toLowerCase(),
                    system: "http://unitsofmeasure.org",
                    code: doseMatch[2].toLowerCase()
                }
            }];
        }

        // Route (always use SNOMED lookup)
        const routeInfo = lookupRoute(med.route);
        dosageInstruction.route = {
            coding: [{
                system: "http://snomed.info/sct",
                code: routeInfo.code,
                display: routeInfo.display
            }]
        };

        // SNOMED coding for the medication (NEVER empty)
        const snomedInfo = lookupMedicationSnomed(med.name);

        const medRequest = {
            fullUrl: `urn:uuid:${medRequestId}`,
            resource: {
                resourceType: "MedicationRequest",
                id: medRequestId,
                meta: {
                    profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/MedicationRequest"]
                },
                status: "active",
                intent: "order",
                medicationCodeableConcept: {
                    text: med.name || "Unknown Medication",
                    coding: [{
                        system: "http://snomed.info/sct",
                        code: snomedInfo.code,
                        display: `${med.name}${med.form ? ` (${med.form})` : ''}`
                    }]
                },
                subject: { reference: `urn:uuid:${patientId}` },
                authoredOn: prescriptionDate,
                requester: { reference: `urn:uuid:${doctorId}` },
                encounter: { reference: `urn:uuid:${encounterId}` },
                dosageInstruction: [dosageInstruction]
            }
        };

        // Duration → dispenseRequest
        if (med.duration && med.duration !== 'unclear' && med.duration !== 'as directed') {
            const durMatch = med.duration.match(/(\d+)\s*(days?|weeks?|wk|months?|mon)/i);
            if (durMatch) {
                let durationDays = parseInt(durMatch[1]);
                const unit = durMatch[2].toLowerCase();
                if (unit.startsWith('week') || unit === 'wk') durationDays *= 7;
                if (unit.startsWith('month') || unit === 'mon') durationDays *= 30;
                medRequest.resource.dispenseRequest = {
                    expectedSupplyDuration: {
                        value: durationDays,
                        unit: "days",
                        system: "http://unitsofmeasure.org",
                        code: "d"
                    }
                };
            }
        }

        medicationRequestEntries.push(medRequest);
    });

    // ─── Composition sections ────────────────────────────────────────
    const sections = [];

    if (structuredData.diagnosis) {
        sections.push({
            title: "Diagnosis",
            code: {
                coding: [{ system: "http://snomed.info/sct", code: "439401001", display: "Diagnosis section" }]
            },
            text: {
                status: "generated",
                div: `<div xmlns="http://www.w3.org/1999/xhtml">${structuredData.diagnosis}</div>`
            }
        });
    }

    if (structuredData.chief_complaint) {
        sections.push({
            title: "Chief Complaint",
            code: {
                coding: [{ system: "http://snomed.info/sct", code: "422843007", display: "Chief complaint section" }]
            },
            text: {
                status: "generated",
                div: `<div xmlns="http://www.w3.org/1999/xhtml">${structuredData.chief_complaint}</div>`
            }
        });
    }

    if (observationEntries.length > 0) {
        sections.push({
            title: "Vitals",
            code: {
                coding: [{ system: "http://snomed.info/sct", code: "1184593002", display: "Vital signs section" }]
            },
            entry: observationEntries.map(obs => ({ reference: obs.fullUrl }))
        });
    }

    sections.push({
        title: "Prescription",
        code: {
            coding: [{ system: "http://snomed.info/sct", code: "440545006", display: "Prescription record" }]
        },
        entry: medicationSectionEntries
    });

    if (structuredData.investigations) {
        sections.push({
            title: "Investigations Advised",
            code: {
                coding: [{ system: "http://snomed.info/sct", code: "721981007", display: "Diagnostic studies report" }]
            },
            text: {
                status: "generated",
                div: `<div xmlns="http://www.w3.org/1999/xhtml">${structuredData.investigations}</div>`
            }
        });
    }

    if (structuredData.follow_up) {
        const adviceText = Array.isArray(structuredData.follow_up.advice)
            ? structuredData.follow_up.advice.join(', ')
            : structuredData.follow_up.advice || '';
        sections.push({
            title: "Follow-up",
            code: {
                coding: [{ system: "http://snomed.info/sct", code: "390906007", display: "Follow-up encounter" }]
            },
            text: {
                status: "generated",
                div: `<div xmlns="http://www.w3.org/1999/xhtml">Date: ${structuredData.follow_up.date || 'TBD'}. Advice: ${adviceText}</div>`
            }
        });
    }

    const compositionResource = {
        fullUrl: `urn:uuid:${compositionId}`,
        resource: {
            resourceType: "Composition",
            id: compositionId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/PrescriptionRecord"]
            },
            status: "final",
            type: {
                coding: [{ system: "http://snomed.info/sct", code: "440545006", display: "Prescription record" }]
            },
            category: [{
                coding: [{
                    system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                    code: "PHAR",
                    display: "Pharmacy"
                }]
            }],
            subject: { reference: `urn:uuid:${patientId}` },
            encounter: { reference: `urn:uuid:${encounterId}` },
            date: prescriptionDate,
            author: [
                { reference: `urn:uuid:${doctorId}` },
                { reference: `urn:uuid:${orgId}` }
            ],
            title: "Prescription Record",
            section: sections
        }
    };

    return {
        resourceType: "Bundle",
        id: bundleId,
        meta: {
            lastUpdated: timestamp,
            profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/DocumentBundle"]
        },
        identifier: { system: "https://curenet.abdm.gov.in", value: bundleId },
        type: "document",
        timestamp,
        entry: [
            compositionResource,
            buildPatientResource(patientId, structuredData),
            buildPractitionerResource(doctorId, structuredData),
            buildOrganizationResource(orgId, structuredData),
            buildEncounterResource(encounterId, patientId, prescriptionDate),
            ...medicationRequestEntries,
            ...observationEntries
        ]
    };
}


// ═══════════════════════════════════════════════════════════════════
//  LAB REPORT BUNDLE BUILDER
// ═══════════════════════════════════════════════════════════════════

function buildLabReportBundle(structuredData) {
    const timestamp = new Date().toISOString();
    const bundleId = generateId();
    const patientId = generateId();
    const doctorId = generateId();
    const orgId = generateId();
    const encounterId = generateId();
    const compositionId = generateId();
    const diagnosticReportId = generateId();
    const reportDate = structuredData.date || timestamp.split('T')[0];

    const labResults = structuredData.lab_results || [];

    // Deduplicate lab results by test_name
    const dedupMap = new Map();
    labResults.forEach(test => {
        const key = (test.test_name || '').toLowerCase();
        if (!dedupMap.has(key)) {
            dedupMap.set(key, test);
        }
    });
    const uniqueTests = [...dedupMap.values()];

    const observationEntries = [];
    const observationRefs = [];

    uniqueTests.forEach(test => {
        const obsId = generateId();
        observationRefs.push({ reference: `urn:uuid:${obsId}` });

        const testCode = lookupLabTestCode(test.test_name);

        const observation = {
            fullUrl: `urn:uuid:${obsId}`,
            resource: {
                resourceType: "Observation",
                id: obsId,
                meta: {
                    profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/Observation"]
                },
                status: "final",
                code: {
                    coding: [{
                        system: testCode.system,
                        code: testCode.code,
                        display: test.test_name
                    }],
                    text: test.test_name
                },
                subject: { reference: `urn:uuid:${patientId}` },
                effectiveDateTime: reportDate
            }
        };

        // Value
        const numericValue = parseFloat(test.value);
        if (!isNaN(numericValue) && test.unit) {
            observation.resource.valueQuantity = {
                value: numericValue,
                unit: test.unit,
                system: "http://unitsofmeasure.org",
                code: test.unit
            };
        } else if (test.value) {
            observation.resource.valueString = String(test.value);
        }

        // Reference range
        if (test.reference_range) {
            const rangeMatch = test.reference_range.match(/([\d.]+)\s*[-–]\s*([\d.]+)/);
            if (rangeMatch) {
                observation.resource.referenceRange = [{
                    low: { value: parseFloat(rangeMatch[1]), unit: test.unit || '' },
                    high: { value: parseFloat(rangeMatch[2]), unit: test.unit || '' },
                    text: test.reference_range
                }];
            } else {
                observation.resource.referenceRange = [{ text: test.reference_range }];
            }
        }

        observationEntries.push(observation);
    });

    // DiagnosticReport
    const diagnosticReport = {
        fullUrl: `urn:uuid:${diagnosticReportId}`,
        resource: {
            resourceType: "DiagnosticReport",
            id: diagnosticReportId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/DiagnosticReportLab"]
            },
            status: "final",
            category: [{
                coding: [{
                    system: "http://terminology.hl7.org/CodeSystem/v2-0074",
                    code: "LAB",
                    display: "Laboratory"
                }]
            }],
            code: {
                coding: [{
                    system: "http://snomed.info/sct",
                    code: "721981007",
                    display: "Diagnostic studies report"
                }],
                text: structuredData.report_title || "Laboratory Report"
            },
            subject: { reference: `urn:uuid:${patientId}` },
            effectiveDateTime: reportDate,
            issued: timestamp,
            performer: [
                { reference: `urn:uuid:${doctorId}` },
                { reference: `urn:uuid:${orgId}` }
            ],
            result: observationRefs
        }
    };

    // Composition
    const compositionResource = {
        fullUrl: `urn:uuid:${compositionId}`,
        resource: {
            resourceType: "Composition",
            id: compositionId,
            meta: {
                profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/DiagnosticReportRecord"]
            },
            status: "final",
            type: {
                coding: [{ system: "http://snomed.info/sct", code: "721981007", display: "Diagnostic studies report" }]
            },
            category: [{
                coding: [{
                    system: "http://terminology.hl7.org/CodeSystem/v2-0074",
                    code: "LAB",
                    display: "Laboratory"
                }]
            }],
            subject: { reference: `urn:uuid:${patientId}` },
            encounter: { reference: `urn:uuid:${encounterId}` },
            date: reportDate,
            author: [
                { reference: `urn:uuid:${doctorId}` },
                { reference: `urn:uuid:${orgId}` }
            ],
            title: "Diagnostic Report - Lab",
            section: [{
                title: "Lab Results",
                code: {
                    coding: [{ system: "http://snomed.info/sct", code: "721981007", display: "Diagnostic studies report" }]
                },
                entry: [
                    { reference: `urn:uuid:${diagnosticReportId}` },
                    ...observationRefs
                ]
            }]
        }
    };

    return {
        resourceType: "Bundle",
        id: bundleId,
        meta: {
            lastUpdated: timestamp,
            profile: ["https://nrces.in/ndhm/fhir/r4/StructureDefinition/DocumentBundle"]
        },
        identifier: { system: "https://curenet.abdm.gov.in", value: bundleId },
        type: "document",
        timestamp,
        entry: [
            compositionResource,
            buildPatientResource(patientId, structuredData),
            buildPractitionerResource(doctorId, structuredData),
            buildOrganizationResource(orgId, structuredData),
            buildEncounterResource(encounterId, patientId, reportDate),
            diagnosticReport,
            ...observationEntries
        ]
    };
}


// ═══════════════════════════════════════════════════════════════════
//  UNIFIED ENTRY POINT
// ═══════════════════════════════════════════════════════════════════

/**
 * Builds an ABDM-compliant FHIR R4 Document Bundle.
 * Detects document type from structuredData and delegates accordingly.
 *
 * @param {Object} structuredData - Parsed clinical data
 * @param {string} [documentType] - Explicit type override: 'prescription' | 'lab_report'
 * @returns {Object} FHIR R4 Bundle
 */
exports.buildABDMDocumentBundle = (structuredData, documentType) => {
    const type = documentType || detectType(structuredData);

    if (type === 'lab_report') {
        return buildLabReportBundle(structuredData);
    }
    return buildPrescriptionBundle(structuredData);
};

function detectType(data) {
    if (data.lab_results && data.lab_results.length > 0) return 'lab_report';
    return 'prescription';
}


// ═══════════════════════════════════════════════════════════════════
//  FHIR BUNDLE VALIDATOR
// ═══════════════════════════════════════════════════════════════════

/**
 * Validates a FHIR bundle for ABDM strict compliance.
 * Returns { valid: boolean, errors: string[] }
 */
exports.validateFhirBundle = (bundle) => {
    const errors = [];

    // 1. Bundle type
    if (bundle.type !== 'document') {
        errors.push('Bundle.type must be "document"');
    }

    // 2. Composition must be first entry
    if (!bundle.entry || bundle.entry.length === 0) {
        errors.push('Bundle has no entries');
        return { valid: false, errors };
    }
    if (bundle.entry[0].resource?.resourceType !== 'Composition') {
        errors.push('Composition must be first entry');
    }

    // 3. All references must resolve
    const allFullUrls = new Set(bundle.entry.map(e => e.fullUrl));
    function checkRefs(obj, path) {
        if (!obj || typeof obj !== 'object') return;
        if (obj.reference && typeof obj.reference === 'string' && obj.reference.startsWith('urn:uuid:')) {
            if (!allFullUrls.has(obj.reference)) {
                errors.push(`Broken reference: ${obj.reference} at ${path}`);
            }
        }
        for (const [k, v] of Object.entries(obj)) {
            if (Array.isArray(v)) {
                v.forEach((item, i) => checkRefs(item, `${path}.${k}[${i}]`));
            } else if (typeof v === 'object') {
                checkRefs(v, `${path}.${k}`);
            }
        }
    }
    checkRefs(bundle, 'Bundle');

    // 4. No empty SNOMED codes on MedicationRequest
    bundle.entry
        .filter(e => e.resource.resourceType === 'MedicationRequest')
        .forEach(e => {
            const coding = e.resource.medicationCodeableConcept?.coding?.[0];
            if (!coding?.code || coding.code === '' || coding.code === 'UNKNOWN') {
                errors.push(`Empty/UNKNOWN SNOMED code on medication: ${e.resource.medicationCodeableConcept?.text}`);
            }
            if (!e.resource.dosageInstruction?.length) {
                errors.push(`Missing dosageInstruction on ${e.fullUrl}`);
            }
        });

    // 5. No placeholders
    const jsonStr = JSON.stringify(bundle);
    if (jsonStr.includes('PLACEHOLDER')) {
        errors.push('Placeholder value still present in bundle');
    }

    // 6. No duplicate medications
    const medKeys = new Set();
    bundle.entry
        .filter(e => e.resource.resourceType === 'MedicationRequest')
        .forEach(e => {
            const name = e.resource.medicationCodeableConcept?.text;
            const dosage = e.resource.dosageInstruction?.[0]?.text;
            const key = `${name}|${dosage}`;
            if (medKeys.has(key)) {
                errors.push(`Duplicate medication: ${name}`);
            }
            medKeys.add(key);
        });

    // 7. No duplicate observations
    const obsKeys = new Set();
    bundle.entry
        .filter(e => e.resource.resourceType === 'Observation')
        .forEach(e => {
            const name = e.resource.code?.text;
            if (obsKeys.has(name)) {
                errors.push(`Duplicate observation: ${name}`);
            }
            obsKeys.add(name);
        });

    return { valid: errors.length === 0, errors };
};


// ─── Helper: Format dosage text ──────────────────────────────────────────────
function formatDosageText(med) {
    const parts = [];
    if (med.form) parts.push(med.form);
    if (med.dosage && med.dosage !== 'unclear' && med.dosage !== 'as prescribed') {
        parts.push(med.dosage);
    }
    if (med.frequency && med.frequency !== 'unclear') {
        parts.push(med.frequency);
    }
    if (med.duration && med.duration !== 'unclear' && med.duration !== 'as directed') {
        parts.push(`for ${med.duration}`);
    }
    if (med.route) {
        parts.push(`(${med.route})`);
    }
    return parts.length > 0 ? parts.join(' — ') : 'As directed';
}
