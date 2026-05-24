# CureNet AI

**India's first ABDM-native health intelligence platform — powered by Gemma 4 edge inference.**

CureNet brings AI-powered clinical intelligence to healthcare settings where reliable internet is a luxury. By running Gemma 4 locally via Ollama, CureNet delivers medical document extraction, FHIR R4 bundle generation, and RAG-augmented health insights — entirely offline, entirely private.

Built for the Ayushman Bharat Digital Mission (ABDM) ecosystem with full M1/M2/M3 milestone compliance.

---

## Table of Contents

- [Key Differentiators](#key-differentiators)
- [Architecture](#architecture)
- [How Gemma 4 Is Used](#how-gemma-4-is-used)
- [Features](#features)
- [ABDM Milestone Compliance](#abdm-milestone-compliance)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Security & Privacy](#security--privacy)
- [Offline-First Architecture](#offline-first-architecture)

---

## Key Differentiators

| Capability | CureNet | Typical Health Apps |
|---|---|---|
| AI inference location | Local device via Ollama | Cloud-only |
| Works without internet | Yes — full offline mode | No |
| Clinical data encryption | AES-256-GCM + platform keychain | Basic or none |
| FHIR R4 compliance | ABDM/NRCeS profiles, SNOMED CT + LOINC coded | Partial or missing |
| ABDM integration depth | M1 + M2 + M3 (enrollment, HIP, HIU) | M1 only |
| Multilingual support | English, Hindi, Bengali (Bhashini API) | English only |

---

## Architecture

CureNet uses a **dual-model, edge-first architecture** leveraging the Gemma 4 family. All AI inference defaults to local Ollama; cloud APIs serve only as fallback.

```
┌──────────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                           │
│                                                                  │
│  ┌─────────────────┐   ┌──────────────────────────────────────┐  │
│  │  ABHAy AI Chat  │   │  28 Production Screens               │  │
│  │  (RAG Pipeline) │   │  ─────────────────────────────────── │  │
│  │                 │   │  Home · Chat · Records · DocScan     │  │
│  │  Intent → E4B   │   │  Health Locker · Emergency Snapshot  │  │
│  │  Chat  → 31B    │   │  ABHA Creation · Login Flows         │  │
│  │  Offline → Local│   │  Profile · QR Share · Notifications  │  │
│  └────────┬────────┘   └──────────────────────────────────────┘  │
│           │                                                      │
│  ┌────────▼─────────────────────────────────────────────────┐    │
│  │  Services Layer (12 services)                            │    │
│  │  AI · ABDM · OCR · FHIR · ObjectBox · Crypto · Bhashini │    │
│  │  Biometric · SecureStorage · Connectivity · Tavily · TTS │    │
│  └────────┬─────────────────────────────────────────────────┘    │
│           │                                                      │
│  ┌────────▼─────────────────────────────────────────────────┐    │
│  │  Encrypted Local Storage                                 │    │
│  │  ObjectBox + AES-256-GCM │ Keys in Keychain/Keystore     │    │
│  └──────────────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────┤
│                           ▼ HTTP                                 │
├──────────────────────────────────────────────────────────────────┤
│                Node.js Backend (Workstation)                     │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ Vision Extraction│  │ Document         │  │ FHIR R4       │  │
│  │ Gemma 4 31B      │  │ Classification   │  │ Bundle Builder│  │
│  │ (Ollama local)   │  │ (Rx vs Lab)      │  │ (756 lines)   │  │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬───────┘  │
│           │                     │                     │          │
│  ┌────────▼─────────────────────▼─────────────────────▼───────┐  │
│  │  SNOMED CT (170+ codes) + LOINC (50+ codes) + NRCeS       │  │
│  └────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────┤
│                           ▼                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │ Ollama      │  │ Groq Cloud   │  │ ABDM Sandbox         │    │
│  │ (PRIMARY)   │  │ (FALLBACK)   │  │ (Gateway/ABHA/HIE-CM)│    │
│  │ gemma4:e4b  │  │ llama-3.1-8b │  │ M1/M2/M3 APIs        │    │
│  │ gemma4:31b  │  │ llama-3.3-70b│  │                      │    │
│  └─────────────┘  └──────────────┘  └──────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

**Routing hierarchy** (three-tier network probing with 30-second cache):

1. **Local Ollama** — edge/workstation, zero-latency, fully private
2. **Backend API** — clinic LAN, FHIR pipeline
3. **Cloud APIs** — Groq fallback, ABDM sandbox, Bhashini, Tavily

---

## How Gemma 4 Is Used

### Gemma 4 E4B (`gemma4:e4b`) — On-Device Edge Intelligence

The lightweight E4B model runs locally via Ollama for low-latency, high-frequency tasks:

| Task | Implementation | Details |
|---|---|---|
| **Intent Classification** | `_identifyIntent()` in `ai_service.dart` | Classifies user messages as `MEDICAL_QUERY`, `GENERAL_CHAT`, or `APP_HELP` in <4 seconds |
| **Title Generation** | `generateTitle()` in `ai_service.dart` | Creates concise 3-word chat session titles |
| **Rate-Limit Failover** | Automatic model cascade | When the 31B model is overloaded (429/503), E4B takes over as a degraded-but-functional fallback |

With its **Per-Layer Embeddings (PLE)** architecture, E4B packs frontier-level reasoning into a ~3 GB memory footprint. Its **128K context window** accommodates large clinical data logs while running natively offline — critical for rural healthcare settings where connectivity is intermittent.

### Gemma 4 31B Dense (`gemma4:31b`) — Medical Reasoning & Vision

The full-power 31B Dense model runs on the clinic workstation via Ollama for complex clinical tasks:

| Task | Implementation | Details |
|---|---|---|
| **Vision-Based Extraction** | `visionLlmService.js` (backend) | Processes prescription/lab report images using multimodal capabilities; extracts medications, dosages, vitals, lab values |
| **Medical RAG Chat** | `sendMessageStream()` in `ai_service.dart` | RAG-augmented responses using clinical atoms + semantic search results + Tavily web context |
| **FHIR R4 Conversion** | `llm_parser.py` + `fhirBuilder.js` | Maps unstructured OCR output into strict FHIR R4 bundles with SNOMED/LOINC coding |
| **Document Classification** | `documentClassifier.js` | Distinguishes prescriptions from lab reports for pipeline routing |

The Dense architecture provides **complete context retention** with a **256K context window** and unmatched multi-step reasoning. Medical records cannot tolerate routing gaps or hallucination — the Dense variant ensures reliable, high-quality extraction.

### Cloud Fallback (Groq)

When Ollama is unavailable, the app transparently falls back to Groq Cloud:

| Local Model | Groq Fallback |
|---|---|
| `gemma4:e4b` | `llama-3.1-8b-instant` |
| `gemma4:31b` | `llama-3.3-70b-versatile` |

Fallback is automatic and session-cached — the app probes Ollama once, caches the result, and routes all subsequent requests accordingly.

---

## Features

### ABHAy AI Assistant
AI-powered health chat with RAG (Retrieval-Augmented Generation) pipeline. Queries run through a parallel pipeline: intent classification, Tavily web search, clinical atom retrieval, and semantic search — all executed concurrently to cut latency from ~12s to ~4s. Supports streaming responses in English, Hindi, and Bengali.

### Clinical Document Scanning
Photograph prescriptions or lab reports and extract structured clinical data automatically. The OCR pipeline uses Gemma 4 31B vision extraction on the backend, with Tesseract.js as a fallback. Extracted data is classified, parsed, and converted to FHIR R4 bundles.

### FHIR R4 Bundle Generation
A 756-line FHIR builder generates ABDM-compliant Document Bundles containing `Composition`, `Patient`, `Practitioner`, `Organization`, `Encounter`, `MedicationRequest`, `DiagnosticReport`, and `Observation` resources. Bundles are validated against strict rules: no empty SNOMED codes, no placeholders, no broken references, no duplicates.

### Smart Health Locker
Biometrically protected storage for medical documents. Uses `local_auth` for fingerprint/face authentication and `flutter_secure_storage` backed by Android Keystore / iOS Keychain.

### Emergency Snapshot
A single-screen summary of critical health information — allergies, active medications, blood type, emergency contacts — designed for paramedics and emergency responders.

### Encrypted Local Storage
All clinical atoms are stored in an AES-256-GCM encrypted ObjectBox database. Encryption keys are derived and stored in platform-native secure enclaves (Android Keystore / iOS Keychain).

### Multilingual Support
Full English, Hindi, and Bengali support via the Bhashini Translation API, with text-to-speech for accessibility. Language selection persists across sessions.

### ABDM Integration
Full Ayushman Bharat Digital Mission integration across three milestones — ABHA creation (Aadhaar/Mobile), profile management, health data linking, consent management, and data exchange.

### Records Browser
Browse, search, and filter all scanned clinical records. Includes semantic search powered by vector embeddings (Xenova Transformers) for natural-language queries against your medical history.

### QR Code Sharing
Generate and share QR codes containing ABHA address and profile information for quick identity verification at healthcare facilities.

---

## ABDM Milestone Compliance

| Milestone | Scope | Implementation | Status |
|---|---|---|---|
| **M1** | ABHA Enrollment | ABHA creation via Aadhaar OTP and Mobile OTP flows; V3 API with RSA-OAEP encrypted payloads; profile fetch, ABHA card download, address suggestions | ✅ Complete |
| **M1** | Session Management | Gateway session creation with auto-refresh (15-min TTL); V3 endpoint with v0.5 fallback | ✅ Complete |
| **M1** | Authentication | Multi-method login: Aadhaar, ABHA number, ABHA address, mobile OTP; all OTPs encrypted with ABDM public certificate | ✅ Complete |
| **M2** | HIP (Health Information Provider) | Care context linking via `hip/v3/link/carecontext`; bridge URL registration; service add/update | ✅ Complete |
| **M2** | Consent Management | Consent artefact acknowledgement via `consent/v3/request/hip/on-notify` | ✅ Complete |
| **M2** | Data Flow | Health information request resolution via `data-flow/v3/health-information/hip/on-request` | ✅ Complete |
| **M3** | HIU (Health Information User) | Consent-based data retrieval from ABDM; ECDH X25519 key exchange + AES-GCM for data decryption | ✅ Complete |

**ABDM API domains used:**
- **Gateway:** `https://dev.abdm.gov.in/gateway` — sessions, bridge registration
- **ABHA V3:** `https://abhasbx.abdm.gov.in/abha/api` — enrollment, profile, certificates
- **HIE-CM:** `https://dev.abdm.gov.in/api/hiecm` — consent, data flow

---

## Tech Stack

### Flutter App (Mobile)

| Category | Technology |
|---|---|
| Framework | Flutter 3.11 / Dart |
| AI Inference | Ollama (local Gemma 4) → Groq Cloud (fallback) |
| Database | ObjectBox with AES-256-GCM encryption |
| Auth & Security | `local_auth`, `flutter_secure_storage`, `pointycastle`, `cryptography` |
| FHIR | `fhir` package (R4 models on-device) |
| State Management | `provider` |
| Networking | `http` (streaming SSE support) |
| Accessibility | `speech_to_text`, `flutter_tts`, Bhashini TTS |
| Charts | `fl_chart` |
| QR | `qr_flutter` |
| Camera | `camera`, `image_picker` |

### Node.js Backend

| Category | Technology |
|---|---|
| Runtime | Node.js ≥18, Express |
| AI Vision | Gemma 4 31B via Ollama → Groq/Nvidia fallback |
| OCR Fallback | Tesseract.js 5.x |
| Embeddings | Xenova Transformers (vector search) |
| FHIR Builder | Custom 756-line generator with SNOMED/LOINC maps |
| Medical Coding | 170+ SNOMED CT codes, 50+ LOINC codes |
| Image Processing | Sharp |
| Database | MongoDB (via Mongoose) |
| PDF Processing | pdf2pic, Mammoth |

---

## Project Structure

```
curenet/
├── lib/
│   ├── main.dart                          — App entry point
│   ├── core/
│   │   ├── abdm_crypto.dart               — RSA-OAEP, ECDH X25519, AES-GCM (ABDM)
│   │   ├── app_config.dart                — API keys, Ollama URL, backend URL
│   │   ├── app_language.dart              — Multilingual state management
│   │   ├── app_router.dart                — Screen routing (28 screens)
│   │   ├── auth_provider.dart             — Auth state management
│   │   ├── data_mode.dart                 — Demo/live data toggle
│   │   ├── persona.dart                   — Demo patient data (Arjun Mishra)
│   │   ├── theme.dart                     — Material Design 3 theme
│   │   ├── translated_text.dart           — Translation widget
│   │   └── voice_helper.dart              — TTS helper
│   ├── models/
│   │   └── clinical_atom.dart             — ObjectBox entity for clinical data
│   ├── screens/                           — 28 production screens
│   │   ├── chat_screen.dart               — ABHAy AI chat (39KB)
│   │   ├── doc_scan_screen.dart           — Document scanning (19KB)
│   │   ├── scan_result_screen.dart        — FHIR results viewer (29KB)
│   │   ├── records_screen.dart            — Records browser + search (35KB)
│   │   ├── health_locker_screen.dart      — Biometric-protected locker
│   │   ├── emergency_snapshot_screen.dart — Emergency card (21KB)
│   │   ├── home_screen.dart               — Dashboard (21KB)
│   │   ├── create_abha_*.dart             — ABHA creation flows
│   │   ├── login_*.dart                   — Multi-method login (5 screens)
│   │   ├── profile_screen.dart            — User profile
│   │   ├── qr_share_screen.dart           — QR code sharing
│   │   └── ...                            — 28 total
│   └── services/
│       ├── ai_service.dart                — Gemma 4 E4B + 31B via Ollama, Groq fallback
│       ├── abdm_service.dart              — Full ABDM M1/M2/M3 integration (490 lines)
│       ├── ocr_service.dart               — OCR pipeline + semantic search (17KB)
│       ├── fhir_service.dart              — Flutter-side FHIR R4 generation
│       ├── objectbox_service.dart         — Encrypted ObjectBox CRUD
│       ├── db_crypto_service.dart         — AES-256-GCM encryption engine
│       ├── connectivity_service.dart      — Three-tier network probing
│       ├── bhashini_translate_service.dart — Hindi/Bengali translation
│       ├── bhashini_tts_service.dart       — Text-to-speech
│       ├── biometric_service.dart         — Fingerprint/face auth
│       ├── secure_storage_service.dart    — Keychain credential storage
│       └── tavily_service.dart            — Web search augmentation
├── backend/
│   ├── package.json                       — Backend dependencies
│   ├── .env.example                       — Environment variable template
│   └── src/
│       ├── server.js                      — Express server entry point
│       ├── services/
│       │   ├── ocr/
│       │   │   ├── visionLlmService.js    — Gemma 4 31B vision extraction (16KB)
│       │   │   ├── llm_parser.py          — Gemma 4 E4B HF parser
│       │   │   ├── parserService.js       — Structured data parser
│       │   │   ├── preprocessService.js   — Image preprocessing
│       │   │   ├── postprocessService.js  — Output post-processing
│       │   │   └── normalizationService.js — Medical term normalization
│       │   ├── workerService.js           — OCR pipeline orchestrator
│       │   ├── documentProcessor.js       — FHIR bundle orchestrator
│       │   ├── documentClassifier.js      — Prescription vs lab report classifier
│       │   └── embeddingService.js        — Xenova vector embeddings
│       └── utils/
│           ├── fhirBuilder.js             — 756-line ABDM FHIR R4 builder
│           ├── snomedMap.js               — 170+ SNOMED CT + 50+ LOINC codes
│           └── medical_dictionary.json    — Medical term dictionary
└── pubspec.yaml                           — Flutter dependencies
```

---

## Prerequisites

| Requirement | Version | Purpose |
|---|---|---|
| Flutter SDK | `≥3.11.0` | Mobile app framework |
| Node.js | `≥18.0.0` | Backend OCR pipeline |
| Ollama | Latest | Local Gemma 4 inference |
| RAM (recommended) | ≥32 GB | For running `gemma4:31b` locally |

**API Keys Required:**

| Service | Purpose | Required |
|---|---|---|
| Groq | Cloud AI fallback | Recommended |
| Tavily | Web search augmentation | Recommended |
| ABDM Sandbox | ABHA enrollment + health data exchange | Required |
| Bhashini | Hindi/Bengali translation + TTS | Required for multilingual |

---

## Setup

### 1. Install Ollama & Pull Gemma 4 Models

Ollama runs Gemma 4 locally on your machine. This is the **primary** inference path — not an optional component.

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows — download from https://ollama.com/download
```

Pull the Gemma 4 models:

```bash
# Gemma 4 E4B — lightweight model for intent classification & titles (~3GB)
ollama pull gemma4:e4b

# Gemma 4 31B Dense — full-power model for medical reasoning & vision (~20GB)
# Requires ≥32GB RAM. If unavailable, E4B handles all tasks.
ollama pull gemma4:31b
```

Start the Ollama server:

```bash
ollama serve
# Runs on http://localhost:11434 by default
```

> **Resource-constrained machines:** If you lack the RAM for 31B, you can run with `gemma4:e4b` alone. The app automatically adapts to whatever Gemma 4 model is available.

### 2. Clone & Install Flutter Dependencies

```bash
git clone https://github.com/labishbardiya/CureNet-AI.git
cd CureNet-AI/curenet
flutter pub get
```

### 3. Run the Flutter App

API keys are passed via `--dart-define`. Groq is a **cloud fallback** — the app works without it when Ollama is running:

```bash
flutter run \
  --dart-define=GROQ_API_KEY=your_groq_key \
  --dart-define=TAVILY_API_KEY=your_tavily_key \
  --dart-define=ABDM_CLIENT_ID=your_abdm_client_id \
  --dart-define=ABDM_CLIENT_SECRET=your_abdm_client_secret \
  --dart-define=BHASHINI_API_KEY=your_bhashini_key \
  --dart-define=BHASHINI_USER_ID=your_bhashini_user \
  --dart-define=BHASHINI_AUTH=your_bhashini_auth
```

**Optional — Custom Ollama host** (e.g., clinic workstation on LAN):

```bash
  --dart-define=OLLAMA_URL=http://192.168.1.100:11434
```

### 4. Run the Backend (OCR Pipeline)

The Node.js backend handles document scanning with Gemma 4 31B vision extraction:

```bash
cd backend
cp .env.example .env
# Edit .env with your API keys, MongoDB URI, and Ollama URL
npm install
npm run dev
```

The backend runs on `http://localhost:3000` by default. When Ollama is on the same machine, it automatically uses Gemma 4 31B Dense for medical entity extraction. If Ollama is unavailable, it falls back to Groq Cloud.

### 5. Verify Setup

Once both services are running, the app's connectivity probe will display:

```
[Connectivity] Ollama=true | Backend=true | Internet=true
[AI] ✅ Ollama reachable — using Gemma 4 (edge-first mode)
```

---

## Security & Privacy

CureNet implements defense-in-depth security across all layers:

| Layer | Mechanism | Implementation |
|---|---|---|
| **Data at Rest** | AES-256-GCM encryption | `db_crypto_service.dart` — all clinical atoms encrypted before ObjectBox storage |
| **Key Management** | Platform secure enclave | Android Keystore / iOS Keychain via `flutter_secure_storage` |
| **ABDM Data Exchange** | RSA-OAEP + ECDH X25519 + AES-GCM | `abdm_crypto.dart` — all OTPs and Aadhaar numbers encrypted with ABDM public certificate |
| **Health Locker Access** | Biometric authentication | Fingerprint/Face ID via `local_auth` |
| **Credential Storage** | Keychain-backed secure storage | ABHA tokens, session keys, and API credentials |
| **AI Privacy** | Local-first inference | All Gemma 4 inference runs on-device via Ollama — no patient data leaves the local network |
| **FHIR Compliance** | Strict validation | No empty SNOMED codes, no placeholders, no broken references, no duplicate entries |

**Key privacy guarantee:** When Ollama is available, no patient data is transmitted to any cloud service for AI processing. The Groq fallback is only activated when local inference is unavailable, and the user is informed via the connectivity status.

---

## Offline-First Architecture

CureNet is engineered for environments where reliable internet is unavailable:

```
┌─────────────────────────────────────────────────────────┐
│               Connectivity Service                      │
│                                                         │
│   Probe 1: Ollama (localhost:11434)  ─── 2s timeout     │
│   Probe 2: Backend (localhost:3000)  ─── 2s timeout     │
│   Probe 3: Internet (api.groq.com)  ─── 3s timeout     │
│                                                         │
│   All three probes run in parallel.                     │
│   Results cached for 30 seconds.                        │
└─────────────────────────────────────────────────────────┘
```

| Mode | Available Services | Behavior |
|---|---|---|
| **Full Edge** | Ollama + Backend | All features, zero cloud dependency |
| **Edge + Cloud** | Ollama + Internet | AI local, ABDM/Bhashini via cloud |
| **Cloud Only** | Internet only | Groq fallback for AI, full ABDM |
| **Fully Offline** | None | Serves responses from locally stored clinical records; medications and lab results displayed from encrypted ObjectBox |

The app never crashes due to network state. Every code path handles the offline case gracefully.

---

## Development Mode

The app includes a demo mode with pre-loaded patient data for testing without ABDM sandbox credentials.

**Toggle:** On the Home Screen, **long-press** the greeting text to switch between demo data (hardcoded persona) and live local data.

---

## License

MIT

---

<p align="center">
  Built for the Ayushman Bharat Digital Mission — making healthcare intelligence accessible to every Indian.
</p>