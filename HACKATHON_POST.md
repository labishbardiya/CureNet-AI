---
title: "CureNet AI: Decentralized Health Intelligence for India, Powered by Gemma 4"
published: true
description: "An ABDM-native, offline-first clinical intelligence platform that brings structured medical data extraction, FHIR R4 compliance, and privacy-preserving AI to healthcare settings with no internet — using Gemma 4 running locally via Ollama."
tags: google, gemma, healthtech, opensource
cover_image:
---

## Table of Contents

1. [The Crisis](#the-crisis)
2. [What I Built](#what-i-built)
3. [How Gemma 4 Powers CureNet](#how-gemma-4-powers-curenet)
4. [Architecture](#architecture)
5. [Clinical Insight Engine](#clinical-insight-engine)
6. [Privacy, Security, and DPDP Act 2023 Compliance](#privacy-security-and-dpdp-act-2023-compliance)
7. [ABDM Compliance](#abdm-compliance)
8. [Offline-First Design](#offline-first-design)
9. [Claims Optimization, Safety, and Adherence](#claims-optimization-safety-and-adherence)
10. [Total Addressable Savings](#total-addressable-savings)
11. [Setup and Reproduction](#setup-and-reproduction)

---

## The Crisis

India's healthcare system is hemorrhaging money, time, and trust at an industrial scale.

### The Financial Leak

In FY 2023-24, Indian health insurance companies **disallowed claims worth Rs 15,100 crore** and **repudiated an additional Rs 10,937 crore** — a combined **Rs 26,037 crore** in denied payouts from a total claims pool of Rs 1.17 lakh crore (IRDAI Annual Report, FY24). A significant proportion of these denials stem from incomplete documentation, missing medical history, and discrepancies in patient records — problems that structured, digitized health data would eliminate.

Meanwhile, India's diagnostics market has crossed **Rs 1.2 lakh crore** (USD 15 billion, FY24), yet fewer than **1% of India's estimated 3 lakh diagnostic laboratories are NABL-accredited**. Patients pay out-of-pocket for **47% of total health expenditure** — among the highest rates globally — and a significant fraction of that is driven by redundant, repeated diagnostic testing that occurs because previous results are trapped in incompatible paper systems.

Peer-reviewed research published via the NIH found that **32% of patients** transferred between institutions with incompatible medical record systems experienced **duplicate testing within 12 hours**, with approximately 20% of those duplicates being clinically unnecessary.

The total economic opportunity cost of India's disease burden is estimated at **USD 1 trillion annually** (Fortune India). Redundant diagnostics, denied claims, and fragmented records are a significant contributor to this drain.

### The Two-Minute Crisis

In overloaded OPDs across India, doctors see **100+ patients in a few hours**, leaving a functional consultation window of approximately **two minutes per patient** (BMJ Open). In those two minutes, a doctor must reconstruct the patient's entire medical history — allergies, chronic conditions, active medications, recent lab results — from disorganized paper records, patient recollection, or nothing at all.

This is not a technology problem. This is a human capacity problem that technology must solve.

### The Memory Gap

Despite the rapid progress of the Ayushman Bharat Digital Mission, the digital transformation is far from complete. As of 2024, **less than 15% of Indian hospitals had fully digitized medical record systems**. While over 76 crore Indians have created ABHA IDs, the vast majority of clinical encounters — especially in rural and semi-urban settings — still produce paper-based records that are never digitized.

This reliance on patient recall and fragmented paper triggers a cascade of inefficiencies:

- **Redundant diagnostics:** Doctors re-order tests they cannot verify were already performed
- **Medication conflicts:** Prescriptions are written without visibility into what the patient is already taking
- **Missed follow-ups:** Chronic condition monitoring falls through the cracks
- **Claim denials:** Insurance submissions lack the structured documentation required for approval

### The Cybersecurity Dimension

Healthcare data is under siege. Indian healthcare institutions face an average of **8,600+ cyberattacks per week** — significantly above the global average. The AIIMS Delhi ransomware attack (November 2022) crippled the hospital for two weeks, affecting 100+ servers and potentially exposing the records of **30-40 million patients**. In September 2024, Star Health Insurance suffered a breach compromising **31 million patient records**.

These attacks exploit the fundamental vulnerability of centralized, unencrypted medical data systems. A privacy-first, local-storage architecture is not a feature — it is a necessity.

---

## What I Built

CureNet AI is an ABDM-native, offline-first health intelligence platform that deploys edge AI directly into the local clinic ecosystem. It transforms fragmented, handwritten medical records into structured, searchable, FHIR R4-compliant digital assets — without requiring an internet connection.

The platform consists of:

- A **Flutter mobile application** with 28 production screens covering the complete ABDM patient journey
- A **Node.js backend** for vision-based medical entity extraction and FHIR R4 bundle construction
- A **dual-model AI architecture** where Gemma 4 E4B handles edge tasks and Gemma 4 31B Dense handles complex medical reasoning — both running locally through Ollama

When online, the system uses cloud APIs as a fallback. When offline — as is the reality in thousands of villages across India — Gemma 4 runs entirely on the local machine. No data leaves the device. No cloud dependency.

---

## How Gemma 4 Powers CureNet

Gemma 4's open-weights architecture (Apache 2.0) is what makes offline clinical intelligence feasible. No API costs, no vendor lock-in, no patient data transmitted to third-party servers.

### Gemma 4 E4B — Edge Intelligence

The E4B model (`gemma4:e4b`, ~3 GB) runs locally for high-frequency, low-latency operations:

- **Intent Classification:** Classifies every user message as `MEDICAL_QUERY`, `GENERAL_CHAT`, or `APP_HELP` in under 2 seconds. This determines whether the full RAG pipeline (clinical atoms + web search + semantic search) is activated.
- **Title Generation:** Creates concise chat session titles without consuming resources from the larger model.
- **Rate-Limit Failover:** When the 31B model is overloaded (429/503), E4B takes over as a degraded-but-functional fallback.

E4B's Per-Layer Embeddings (PLE) architecture packs frontier-level reasoning into a tiny memory footprint. Its 128K context window accommodates large clinical data logs while running natively offline.

### Gemma 4 31B Dense — Medical Reasoning and Vision

The 31B Dense model (`gemma4:31b`, ~20 GB) runs on the clinic workstation for tasks demanding complete context retention:

- **Multimodal Medical Extraction:** Processes prescription and lab report images directly using a zero-shot structure prompt. Extracts patient identifiers, doctor credentials, medications (name, dosage, frequency, duration, form, route), lab results (test, value, unit, reference range), vitals, diagnosis, and follow-up instructions.
- **FHIR R4 Conversion:** Structured output feeds into a 756-line FHIR builder that generates ABDM-compliant Document Bundles with SNOMED CT and LOINC coding.
- **RAG-Augmented Medical Chat:** The ABHAy assistant uses 31B for complex medical queries, augmented with clinical atoms, semantic search results, and web context.

The Dense architecture processes every token through all 31 billion parameters, providing complete context retention. Medical records cannot tolerate routing gaps or hallucination — the Dense variant ensures reliable, high-quality extraction.

### Cloud Fallback

When Ollama is unavailable, the app transparently falls back to Groq Cloud:

| Local Model | Groq Fallback |
|---|---|
| `gemma4:e4b` | `llama-3.1-8b-instant` |
| `gemma4:31b` | `llama-3.3-70b-versatile` |

Fallback is automatic and session-cached.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Flutter Mobile App                      │
│                                                          │
│   ABHAy AI (RAG)  │  28 Screens  │  Encrypted ObjectBox  │
│   E4B: intent     │  ABDM flows  │  AES-256-GCM          │
│   31B: chat/RAG   │  Scan/FHIR   │  Keystore-backed keys │
├──────────────────────────────────────────────────────────┤
│                Node.js Backend                           │
│                                                          │
│   Gemma 4 31B Vision  →  Document Classifier             │
│         ↓                        ↓                       │
│   Structured JSON     →  FHIR R4 Bundle Builder          │
│                          (SNOMED CT + LOINC + NRCeS)     │
├──────────────────────────────────────────────────────────┤
│   Ollama (PRIMARY)  │  Groq (FALLBACK)  │  ABDM Sandbox  │
│   gemma4:e4b        │  llama-3.1-8b     │  V3 APIs       │
│   gemma4:31b        │  llama-3.3-70b    │  M1/M2/M3      │
└──────────────────────────────────────────────────────────┘
```

The routing hierarchy is enforced by a `ConnectivityService` that probes three tiers in parallel:

1. **Local Ollama** (edge/workstation) — zero-latency, fully private
2. **Backend API** (clinic LAN) — FHIR pipeline, low-latency
3. **Cloud APIs** (Groq, ABDM, Bhashini) — internet-dependent fallback

Results are cached for 30 seconds to minimize probe overhead.

---

## Clinical Insight Engine

CureNet is not just a document scanner. It is a clinical insight engine that transforms raw medical data into actionable intelligence.

### Intelligent Ingestion Pipeline

The document scanning pipeline combines multiple extraction strategies:

1. **Gemma 4 31B Vision** (primary): Processes the document image directly using multimodal capabilities
2. **Tesseract.js + Gemma 4 31B** (fallback): OCR text extraction followed by LLM-based structured parsing
3. **Gemma 4 E4B** (edge fallback): Lightweight parsing when the workstation model is unavailable

### Structured Medical Parsing

Every extracted entity is mapped into clinical schemas:

- **Medications:** Name, dosage, frequency, duration, form, route — with Indian prescription patterns like `1+0+1` (morning/afternoon/night) correctly parsed
- **Lab Results:** Test name, value, unit, reference range — with abnormal values flagged
- **Identifiers:** Patient, doctor, clinic, date, registration number
- **Clinical:** Diagnosis, chief complaint, vitals, follow-up instructions

### FHIR R4 Bundle Generation

The 756-line FHIR builder generates ABDM-compliant Document Bundles containing:

- `Composition` (document metadata)
- `Patient`, `Practitioner`, `Organization` (identifiers)
- `Encounter` (clinical context)
- `MedicationRequest` (prescriptions with SNOMED CT coding)
- `Observation` (lab results with LOINC coding)
- `DiagnosticReport` (report aggregation)

Coding coverage: **170+ SNOMED CT medication codes** (including Indian brand-name mappings like Crocin → Paracetamol) and **50+ LOINC lab test codes**. Bundle validation enforces: all references resolve, no empty SNOMED codes, no placeholders, no duplicate entries.

### Reducing Redundant Diagnostics

When a doctor opens a patient's profile in CureNet, they see a structured timeline of every lab test, medication, and diagnosis — all searchable by natural language via vector embeddings. Before ordering a new test, the doctor can instantly verify whether it was already performed, what the results were, and when. This directly attacks the 32% duplicate testing rate documented in peer-reviewed literature.

---

## Privacy, Security, and DPDP Act 2023 Compliance

### Defense-in-Depth Security

| Layer | Mechanism | Implementation |
|---|---|---|
| Data at Rest | AES-256-GCM encryption | All clinical atoms encrypted before ObjectBox storage |
| Key Management | Platform secure enclave | Android Keystore / iOS Keychain via `flutter_secure_storage` |
| ABDM Data Exchange | RSA-OAEP + ECDH X25519 + AES-GCM 256 | All OTPs and Aadhaar numbers encrypted with ABDM public certificate |
| Health Locker | Biometric authentication | Fingerprint/Face ID via `local_auth` |
| Credential Storage | Keychain-backed | ABHA tokens, session keys, API credentials |
| AI Privacy | Local-first inference | All Gemma 4 inference on-device via Ollama |
| FHIR Compliance | Strict validation | No empty codes, no placeholders, no broken references |

### DPDP Act 2023 Compliance

The Digital Personal Data Protection Act, 2023 mandates **free, specific, informed, unconditional, and unambiguous** consent from patients before processing their personal data. CureNet's architecture is designed for full compliance:

- **Purpose-Specific Consent:** Data is collected only for the specific clinical purpose. No bundled consent forms.
- **Data Minimization:** Only clinically necessary fields are stored. Sensitive PHI (name, value, unit, metadata) is encrypted; non-sensitive fields (type, date) remain queryable.
- **Right to Withdraw:** Patient data is stored locally on the device. The patient controls their data physically — it never leaves their device without explicit action (QR sharing, ABDM data push).
- **Local-First Processing:** When Ollama is available, no patient data is transmitted to any cloud service for AI processing. This eliminates the class of consent issues related to third-party data processors.
- **Emergency Access:** The Emergency Snapshot screen provides critical information (allergies, active medications, blood type) without exposing full medical history, aligning with the Act's provisions for "deemed consent" in medical emergencies.
- **Audit Trail:** All ABDM data exchanges use proper request signing with `REQUEST-ID` and `TIMESTAMP` headers, creating a verifiable audit trail.

### Addressing the Cybersecurity Threat

CureNet's local-first architecture directly mitigates the attack surface that led to breaches like AIIMS Delhi (30-40M records) and Star Health Insurance (31M records):

- **No centralized patient database** to compromise — data lives on the patient's device
- **Hardware-backed encryption keys** cannot be extracted even with root access
- **Offline operation** reduces network exposure to zero when running on local Ollama

---

## ABDM Compliance

Full Ayushman Bharat Digital Mission integration across three milestones (490-line `abdm_service.dart`):

| Milestone | Capability | Implementation |
|---|---|---|
| **M1** | ABHA creation (Aadhaar + Mobile OTP) | RSA-OAEP encrypted payloads via ABDM V3 APIs |
| **M1** | Profile fetch + ABHA card download | Authenticated GET with auto-refreshing session tokens |
| **M1** | Multi-method login | Aadhaar, ABHA Number, ABHA Address, Mobile OTP |
| **M2** | Care context linking (HIP) | `hip/v3/link/carecontext` — associates records with ABHA |
| **M2** | Consent management | `consent/v3/request/hip/on-notify` — acknowledgement |
| **M2** | Health data exchange | `data-flow/v3/health-information/hip/on-request` |
| **M3** | HIU data retrieval | ECDH X25519 key exchange + AES-GCM 256 decryption |

ABDM Sandbox domains: Gateway (`dev.abdm.gov.in/gateway`), ABHA V3 (`abhasbx.abdm.gov.in/abha/api`), HIE-CM (`dev.abdm.gov.in/api/hiecm`).

---

## Offline-First Design

CureNet is engineered for environments where reliable internet does not exist.

| Mode | Available Services | Behavior |
|---|---|---|
| **Full Edge** | Ollama + Backend | All features, zero cloud dependency |
| **Edge + Cloud** | Ollama + Internet | AI local; ABDM/Bhashini via cloud |
| **Cloud Only** | Internet only | Groq fallback for AI, full ABDM |
| **Fully Offline** | None | AI serves responses from locally stored clinical records |

The app never crashes due to network state. Every code path handles the offline case gracefully.

---

## Claims Optimization, Safety, and Adherence

### Claims Optimization

Structured FHIR R4 bundles with proper SNOMED CT and LOINC coding directly reduce claim denials:

- **Complete documentation:** Every prescription and lab report is digitized with all required fields
- **Standardized coding:** Insurance systems can process FHIR bundles without manual interpretation
- **Verifiable history:** Claim reviewers can trace the complete clinical context for each treatment decision

### Patient Safety

- **Drug interaction visibility:** The AI assistant can cross-reference current medications against new prescriptions
- **Allergy flagging:** Emergency Snapshot provides immediate access to allergy information
- **Continuity of care:** Structured records travel with the patient across providers

### Treatment Adherence

- **Medication tracking:** Patients can query ABHAy about their current medications, dosages, and schedules
- **Lab trend monitoring:** Historical lab results are stored and queryable, enabling trend analysis
- **Multilingual access:** Bhashini translation ensures patients who speak Hindi or Bengali can understand their medical information

---

## Total Addressable Savings

Based on verified data from IRDAI, BMJ Open, NIH, and Fortune India:

| Problem | Scale | CureNet's Impact |
|---|---|---|
| Insurance claim denials | Rs 26,037 crore/year (FY24, IRDAI) | Structured FHIR bundles with complete documentation reduce denial rates |
| Redundant diagnostics | 32% duplication rate across incompatible EMRs (NIH) | Unified local record history eliminates the need to re-order tests |
| OPD consultation time | ~2 minutes per patient (BMJ Open) | Structured patient summary available instantly — no manual reconstruction |
| Out-of-pocket burden | 47% of total health expenditure | Reduced repeat testing + fewer claim denials = lower patient costs |
| Cybersecurity exposure | 8,600+ attacks/week on Indian healthcare | Local-first, encrypted architecture minimizes attack surface |
| Economic opportunity cost | USD 1 trillion annual disease burden (Fortune India) | Every digitized record is one step toward a functioning health data ecosystem |

---

## Setup and Reproduction

```bash
# 1. Install Ollama
brew install ollama  # macOS
# or: curl -fsSL https://ollama.com/install.sh | sh  # Linux

# 2. Pull Gemma 4 models
ollama pull gemma4:e4b    # ~3 GB — edge tasks
ollama pull gemma4:31b    # ~20 GB — medical reasoning (needs 32GB RAM)

# 3. Start Ollama server
ollama serve

# 4. Clone and install
git clone https://github.com/labishbardiya/CureNet-AI.git
cd CureNet-AI/curenet
flutter pub get

# 5. Run the Flutter app
flutter run \
  --dart-define=GROQ_API_KEY=your_key \
  --dart-define=TAVILY_API_KEY=your_key \
  --dart-define=ABDM_CLIENT_ID=your_id \
  --dart-define=ABDM_CLIENT_SECRET=your_secret \
  --dart-define=BHASHINI_API_KEY=your_key \
  --dart-define=BHASHINI_USER_ID=your_user \
  --dart-define=BHASHINI_AUTH=your_auth

# 6. Run the backend (OCR pipeline)
cd backend && cp .env.example .env && npm install && npm run dev
```

When both services are running, the app displays:

```
[Connectivity] Ollama=true | Backend=true | Internet=true
[AI] Ollama reachable — using Gemma 4 (edge-first mode)
```

---

A single clinic workstation running Ollama with Gemma 4 can digitize an entire practice. Every handwritten prescription becomes a structured, ABDM-compliant FHIR R4 record. Every lab report becomes a coded observation. Every patient interaction becomes a queryable clinical atom stored in an encrypted local database.

No cloud subscription. No vendor lock-in. No compromise on patient privacy. Full DPDP Act 2023 compliance.

That is what open-weights AI makes possible.
