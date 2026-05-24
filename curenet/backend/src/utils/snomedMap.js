/**
 * ═══════════════════════════════════════════════════════════════════
 *  SNOMED CT Code Map for CureNet ABDM Pipeline
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Maps medication names (lowercase) → SNOMED CT concept IDs.
 *  Used by fhirBuilder to ensure NO empty SNOMED codes in output.
 *
 *  For brand-name drugs without a direct SNOMED code, we map to
 *  the active ingredient's SNOMED code with a fallback to the
 *  generic pharmaceutical product category.
 */

const SNOMED_MEDICATIONS = {
    // ─── Common Generics (WHO INN) ───────────────────────────────────
    'paracetamol':          '387517004',
    'acetaminophen':        '387517004',
    'amoxicillin':          '27658006',
    'metformin':            '109081006',
    'atorvastatin':         '373444002',
    'amlodipine':           '386864001',
    'azithromycin':         '387531004',
    'cefixime':             '96034006',
    'omeprazole':           '387137007',
    'pantoprazole':         '395821003',
    'telmisartan':          '387069000',
    'losartan':             '373567002',
    'diclofenac':           '7034005',
    'ibuprofen':            '387207008',
    'glimepiride':          '386966003',
    'vildagliptin':         '424864008',
    'cetirizine':           '372523007',
    'levocetirizine':       '421889003',
    'montelukast':          '373728005',
    'doxycycline':          '372478003',
    'clopidogrel':          '386952008',
    'atropine':             '372832002',
    'salbutamol':           '372897005',
    'aspirin':              '387458008',
    'warfarin':             '372756006',
    'enoxaparin':           '372562000',
    'heparin':              '372877000',
    'rivaroxaban':          '442031002',

    // ─── ACE Inhibitors / ARBs ───────────────────────────────────────
    'lisinopril':           '386873009',
    'enalapril':            '372658000',
    'ramipril':             '386872004',
    'valsartan':            '386876001',
    'candesartan':          '372512008',

    // ─── Beta Blockers ──────────────────────────────────────────────
    'metoprolol':           '372826007',
    'atenolol':             '387506000',
    'propranolol':          '372772003',
    'bisoprolol':           '386868003',
    'carvedilol':           '386870007',

    // ─── Diuretics ──────────────────────────────────────────────────
    'furosemide':           '387475002',
    'spironolactone':       '387078006',
    'hydrochlorothiazide':  '387525002',
    'torsemide':            '108476002',

    // ─── Diabetes ───────────────────────────────────────────────────
    'insulin':              '67866001',
    'glipizide':            '386858008',
    'gliclazide':           '386853002',
    'pioglitazone':         '386964005',
    'sitagliptin':          '423307000',

    // ─── Thyroid ────────────────────────────────────────────────────
    'levothyroxine':        '710809001',
    'carbimazole':          '387340001',
    'propylthiouracil':     '387530003',

    // ─── Anxiolytics / Sedatives ────────────────────────────────────
    'alprazolam':           '386983007',
    'diazepam':             '387264003',
    'lorazepam':            '387106007',
    'clonazepam':           '387383007',
    'zolpidem':             '387569009',

    // ─── Antipsychotics ─────────────────────────────────────────────
    'risperidone':          '386840002',
    'olanzapine':           '386849001',
    'quetiapine':           '386850001',
    'haloperidol':          '386837002',

    // ─── PPIs / GI ──────────────────────────────────────────────────
    'rabeprazole':          '396044003',
    'esomeprazole':         '396047005',
    'lansoprazole':         '386888004',
    'ranitidine':           '372755005',
    'domperidone':          '387181004',
    'ondansetron':          '372487007',
    'metronidazole':        '372602008',

    // ─── Antibiotics ────────────────────────────────────────────────
    'ciprofloxacin':        '392412000',
    'ofloxacin':            '387551000',
    'norfloxacin':          '387271008',
    'levofloxacin':         '387552007',
    'moxifloxacin':         '412439003',
    'ceftriaxone':          '372670001',
    'cephalexin':           '372667001',
    'clindamycin':          '372786004',
    'fluconazole':          '387174006',
    'ketoconazole':         '387216007',

    // ─── Steroids ───────────────────────────────────────────────────
    'prednisolone':         '116601002',
    'dexamethasone':        '372584003',
    'methylprednisolone':   '116602009',
    'hydrocortisone':       '396458002',

    // ─── Pain / Neuro ───────────────────────────────────────────────
    'tramadol':             '386858008',
    'gabapentin':           '386845006',
    'pregabalin':           '415160008',
    'duloxetine':           '407032004',
    'amitriptyline':        '372726002',

    // ─── NSAIDs / Muscle Relaxants ──────────────────────────────────
    'aceclofenac':          '391704009',
    'etoricoxib':           '409134009',
    'piroxicam':            '387153001',
    'naproxen':             '372588000',
    'mefenamic acid':       '387185008',
    'nimesulide':           '391747006',
    'thiocolchicoside':     '699180006',
    'chlorzoxazone':        '373285006',
    'tizanidine':           '373440006',
    'baclofen':             '387342009',

    // ─── Supplements / Vitamins ─────────────────────────────────────
    'calcium carbonate':    '387307005',
    'cholecalciferol':      '18414002',
    'vitamin d3':           '18414002',
    'vitamin b12':          '419382002',
    'folic acid':           '63718003',
    'iron':                 '3829006',
    'ferrous sulphate':     '387402000',
    'zinc':                 '86739005',
    'calcitriol':           '11115001',
    'alfacalcidol':         '391730008',

    // ─── Orthopedic / Joint ─────────────────────────────────────────
    'glucosamine':          '412300004',
    'chondroitin':          '4104007',
    'collagen':             '61472002',
    'diacerein':            '395841002',

    // ─── Brand Names → Active Ingredient SNOMED ─────────────────────
    // These are Indian brand names mapped to their active ingredient code
    'ultrafun-plus':        '7034005',    // Diclofenac + Paracetamol combination
    'ultrafun plus':        '7034005',
    'relentus':             '373728005',  // Montelukast-based
    'bogat':                '412300004',  // Glucosamine + Diacerein combination
    'ultracal-d':           '18414002',   // Calcium + Vitamin D3
    'ultracal d':           '18414002',
    'cartilix':             '412300004',  // Glucosamine/Chondroitin joint supplement
    'augmentin':            '27658006',   // Amoxicillin + Clavulanic acid
    'zifi':                 '96034006',   // Cefixime brand
    'calpol':               '387517004',  // Paracetamol brand
    'crocin':               '387517004',  // Paracetamol brand
    'dolo':                 '387517004',  // Paracetamol brand
    'pan-d':                '395821003',  // Pantoprazole + Domperidone
    'omez':                 '387137007',  // Omeprazole brand
    'glycomet':             '109081006',  // Metformin brand
    'ecosprin':             '387458008',  // Aspirin brand
    'budecort':             '395726003',  // Budesonide brand
    'foracort':             '395726003',  // Formoterol + Budesonide brand
    'rabekind':             '396044003',  // Rabeprazole brand
    'shelcal':              '387307005',  // Calcium brand
    'ccm':                  '387307005',  // Calcium + Vitamin brand
    'gemcal':               '387307005',  // Calcium brand
};

// ─── SNOMED codes for Lab Tests ──────────────────────────────────────────────
const SNOMED_LAB_TESTS = {
    'hemoglobin':           '59260-0',
    'haemoglobin':          '59260-0',
    'hb':                   '59260-0',
    'wbc':                  '6690-2',
    'white blood cell':     '6690-2',
    'rbc':                  '789-8',
    'red blood cell':       '789-8',
    'platelet':             '777-3',
    'platelets':            '777-3',
    'hematocrit':           '4544-3',
    'haematocrit':          '4544-3',
    'mcv':                  '787-2',
    'mch':                  '785-6',
    'mchc':                 '786-4',
    'esr':                  '4537-7',
    'creatinine':           '2160-0',
    'urea':                 '3091-6',
    'blood urea nitrogen':  '3094-0',
    'bun':                  '3094-0',
    'glucose':              '2345-7',
    'blood sugar':          '2345-7',
    'fasting glucose':      '1558-6',
    'fasting blood sugar':  '1558-6',
    'fbs':                  '1558-6',
    'pp glucose':           '1521-4',
    'ppbs':                 '1521-4',
    'hba1c':                '4548-4',
    'glycated hemoglobin':  '4548-4',
    'cholesterol':          '2093-3',
    'total cholesterol':    '2093-3',
    'hdl':                  '2085-9',
    'ldl':                  '2089-1',
    'triglycerides':        '2571-8',
    'vldl':                 '2091-7',
    'sgpt':                 '1742-6',
    'alt':                  '1742-6',
    'sgot':                 '1920-8',
    'ast':                  '1920-8',
    'alkaline phosphatase': '6768-6',
    'alp':                  '6768-6',
    'bilirubin':            '1975-2',
    'total bilirubin':      '1975-2',
    'direct bilirubin':     '1968-7',
    'indirect bilirubin':   '1971-1',
    'albumin':              '1751-7',
    'total protein':        '2885-2',
    'uric acid':            '3084-1',
    'sodium':               '2951-2',
    'potassium':            '2823-3',
    'chloride':             '2075-0',
    'calcium':              '17861-6',
    'phosphorus':           '2777-1',
    'magnesium':            '19123-9',
    'iron':                 '2498-4',
    'tibc':                 '2500-7',
    'ferritin':             '2276-4',
    'vitamin d':            '1989-3',
    'vitamin b12':          '2132-9',
    'tsh':                  '3016-3',
    't3':                   '3053-6',
    't4':                   '3026-2',
    'free t3':              '3051-0',
    'free t4':              '3024-7',
    'psa':                  '2857-1',
    'crp':                  '1988-5',
    'hs-crp':               '30522-7',
    'hiv':                  '7018-2',
    'hbsag':                '5196-1',
    'anti hcv':             '16128-1',
};

// ─── Route code map ─────────────────────────────────────────────────────────
const SNOMED_ROUTES = {
    'oral':         { code: '26643006',  display: 'Oral route' },
    'topical':      { code: '6064005',   display: 'Topical route' },
    'injection':    { code: '78421000',  display: 'Intramuscular route' },
    'intravenous':  { code: '47625008',  display: 'Intravenous route' },
    'subcutaneous': { code: '34206005',  display: 'Subcutaneous route' },
    'inhalation':   { code: '18679011',  display: 'Inhalation route' },
    'rectal':       { code: '37161004',  display: 'Rectal route' },
    'ophthalmic':   { code: '54485002',  display: 'Ophthalmic route' },
    'nasal':        { code: '46713006',  display: 'Nasal route' },
    'sublingual':   { code: '37839007',  display: 'Sublingual route' },
};

/**
 * Looks up a SNOMED code for a medication name.
 * Falls back to the generic "medicinal product" concept if not found.
 */
function lookupMedicationSnomed(medName) {
    if (!medName) return { code: '763158003', display: 'Medicinal product (product)' };
    const key = medName.toLowerCase().trim();
    const code = SNOMED_MEDICATIONS[key];
    if (code) {
        return { code, display: medName };
    }
    // Fallback: generic medicinal product
    return { code: '763158003', display: `${medName} (medicinal product)` };
}

/**
 * Looks up a LOINC code for a lab test name.
 */
function lookupLabTestCode(testName) {
    if (!testName) return { code: '26436-6', display: 'Laboratory studies' };
    const key = testName.toLowerCase().trim();
    const code = SNOMED_LAB_TESTS[key];
    if (code) {
        return { system: 'http://loinc.org', code, display: testName };
    }
    return { system: 'http://loinc.org', code: '26436-6', display: testName };
}

/**
 * Looks up route coding.
 */
function lookupRoute(routeName) {
    if (!routeName) return SNOMED_ROUTES['oral'];
    const key = routeName.toLowerCase().trim();
    return SNOMED_ROUTES[key] || SNOMED_ROUTES['oral'];
}

module.exports = {
    SNOMED_MEDICATIONS,
    SNOMED_LAB_TESTS,
    SNOMED_ROUTES,
    lookupMedicationSnomed,
    lookupLabTestCode,
    lookupRoute
};
