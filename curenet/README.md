# CureNet AI

**India's first ABDM-native, offline-first Health Intelligence Platform powered by Gemma 4**

An edge-first, decentralized health platform that unifies fragmented medical records under ABDM and FHIR R4 standards. Deploys dual-model AI (Gemma 4 E4B + 31B Dense) directly at the clinic edge for offline-capable medical document parsing.

---

## Table of Contents
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup & Installation](#setup--installation)
- [Cloud Deployment (Render)](#cloud-deployment-render)
- [Doctor's Portal](#doctors-portal)
- [Environment Variables](#environment-variables)
- [API Endpoints](#api-endpoints)
- [Academic](#academic)

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                       │
│   Flutter UI → 28 Screens → TranslatedText (22 Languages)    │
├──────────────────────────────────────────────────────────────┤
│                      APPLICATION LAYER                        │
│   AccessRequestMonitor │ AIService │ ABDMService │ OCR        │
│   BhashiniTranslate │ BhashiniTTS │ ConnectivityService       │
├──────────────────────────────────────────────────────────────┤
│                     INTELLIGENCE LAYER                        │
│   Gemma 4 E4B (Edge) │ Gemma 4 31B Dense (Clinic Workstation)│
│   Groq Cloud (Fallback) │ Tavily (RAG) │ Bhashini (NLP/TTS)  │
├──────────────────────────────────────────────────────────────┤
│                        DATA LAYER                             │
│   ObjectBox (AES-256-GCM) │ MongoDB Atlas │ FHIR R4 Bundles   │
│   ABDM Gateway (Federated) │ SharedPreferences (Profile)      │
└──────────────────────────────────────────────────────────────┘

Cloud Deployment:
┌─────────────────┐     ┌──────────────────┐
│  Render          │────│  MongoDB Atlas    │
│  Node.js Backend │    │  (CureNet DB)     │
│  Doctor's Portal │    │                   │
└────────┬────────┘    └──────────────────┘
         │
    ┌────┴────┐      ┌─────────────────┐
    │  Phone  │      │  Any Browser    │
    │  App    │      │  Doctor Portal  │
    └─────────┘      └─────────────────┘
```

### Dual-Model AI Architecture

| Model | Runtime | Role | Context |
|---|---|---|---|
| **Gemma 4 E4B** | Ollama (edge device) | Intent classification, title generation, basic parsing | 128K |
| **Gemma 4 31B Dense** | Ollama (clinic workstation) | Medical entity extraction, FHIR R4 conversion, multimodal OCR | 256K |
| **Groq Cloud** | API fallback | When Ollama is unavailable (cloud mode) | — |

Routing: `Ollama local (primary) → Groq Cloud (fallback)`

---

## Features

### Intelligent Document Ingestion
- Camera-based document scanning with viewfinder overlay
- Hybrid OCR: EasyOCR + TrOCR + Gemma 4 31B Dense vision
- Processes prescriptions AND lab reports
- Extracts patient info, medications, lab results, vitals, diagnosis

### FHIR R4 Structured Medical Parsing
- 756-line `fhirBuilder.js` generates ABDM-compliant FHIR R4 Document Bundles
- Resources: Composition, Patient, Practitioner, Organization, Encounter, MedicationRequest, Observation, DiagnosticReport
- SNOMED CT coding with 170+ medication mappings and 50+ lab LOINC codes
- Full bundle validator with deduplication

### Real-Time Doctor Access Consent
- Doctor scans patient QR → sends access request via portal
- Patient's phone auto-detects request (polls every 4 seconds)
- Dialog appears on ANY screen — approve or deny with one tap
- 30-minute access window, revocable anytime
- Doctor portal shows live data or rejection status

### Privacy-First Architecture
- Encrypted ObjectBox DB: AES-256-GCM application-layer encryption
- Keys stored in Android Keystore / iOS Keychain via `flutter_secure_storage`
- Custom ABDM crypto: RSA-OAEP (SHA-1/MGF1), ECDH X25519, AES-GCM 256
- Biometric authentication for Health Locker access

### Full ABDM Integration (M1 + M2 + M3)
- 490-line `abdm_service.dart` with complete sandbox integration
- M1: ABHA creation via Aadhaar OTP + Mobile OTP
- M2: Link Care Context, consent management, data-flow responses (HIP)
- M3: HIU data requests
- Gateway session management with auto-refresh

### ABHAy AI Assistant (RAG-Augmented)
- Streaming chat with parallel pipeline (intent + web + atoms + semantic)
- Web search augmentation via Tavily
- Clinical atoms context from encrypted ObjectBox
- Rate-limit failover (large model → small model)
- Offline fallback from locally stored records

### Offline-First Architecture
- ConnectivityService probes three tiers: Ollama (edge) → Backend (LAN) → Cloud
- When fully offline, AI serves responses from local records
- All data stored locally first in encrypted ObjectBox

### Multilingual Support (22 Languages)
- Bhashini Translate API for 22 Indian languages
- Bhashini TTS for voice output
- Offline fallback translations for critical UI strings (Hindi/Bengali)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter/Dart |
| Backend | Node.js/Express |
| Local AI | Ollama (Gemma 4 E4B + 31B Dense) |
| Cloud AI Fallback | Groq API |
| Local Database | ObjectBox (AES-256-GCM encrypted) |
| Cloud Database | MongoDB Atlas |
| FHIR | HL7 FHIR R4 (v4.0.1) |
| ABDM | V3 Sandbox APIs |
| Crypto | AES-256-GCM, RSA-OAEP, ECDH X25519 |
| Embeddings | Xenova Transformers |
| Translation | Bhashini API |
| Search | Tavily API |
| Deployment | Render (cloud), adb reverse (local) |

---

## Project Structure

```
curenet/
├── render.yaml                   # Render deployment blueprint
├── .gitignore                    # Protects .env and secrets
├── .env.example                  # Template for env vars
├── lib/
│   ├── main.dart                 # App entry + AccessRequestMonitor init
│   ├── core/
│   │   ├── app_config.dart       # API keys, backend URL (Render)
│   │   ├── abdm_crypto.dart      # RSA-OAEP, ECDH, AES-GCM
│   │   ├── app_language.dart     # 22-language support
│   │   ├── app_router.dart       # 28 screen routes
│   │   ├── auth_provider.dart    # Auth state management
│   │   ├── data_mode.dart        # Demo/live data toggle
│   │   └── translated_text.dart  # Auto-translate widget
│   ├── models/
│   │   └── clinical_atom.dart    # ObjectBox entity
│   ├── screens/                  # 28 Flutter screens
│   │   ├── home_screen.dart
│   │   ├── chat_screen.dart      # ABHAy AI chat
│   │   ├── doc_scan_screen.dart  # Document scanning
│   │   ├── access_request_screen.dart
│   │   ├── access_granted_screen.dart
│   │   ├── emergency_snapshot_screen.dart
│   │   ├── qr_share_screen.dart
│   │   └── ...
│   └── services/
│       ├── access_request_monitor.dart  # Global consent monitor
│       ├── ai_service.dart       # Gemma 4 + Groq
│       ├── abdm_service.dart     # ABDM V3 APIs
│       ├── connectivity_service.dart
│       ├── bhashini_translate_service.dart
│       └── ...
├── backend/
│   ├── package.json              # Node.js deps + engine spec
│   ├── src/
│   │   ├── server.js             # Express server
│   │   ├── config/db.js          # MongoDB Atlas connection
│   │   ├── models/
│   │   │   ├── AccessRequest.js  # Consent tracking (TTL: 2hrs)
│   │   │   └── EmergencyShare.js # QR share data
│   │   ├── routes/
│   │   │   ├── accessRoutes.js   # Doctor access consent API
│   │   │   ├── ocrRoutes.js      # OCR pipeline
│   │   │   ├── recordRoutes.js   # Health records
│   │   │   └── emergencyRoutes.js
│   │   └── services/
│   │       ├── fhirBuilder.js    # 756-line FHIR R4 generator
│   │       └── workerService.js  # Background job queue
│   └── public/                   # Doctor's Portal (static)
│       ├── index.html
│       ├── app.js
│       └── styles.css
```

---

## Setup & Installation

### Prerequisites
- Flutter SDK 3.x
- Node.js 18+
- MongoDB Atlas account (free M0 cluster)
- Ollama (optional, for local AI)

### Quick Start

```bash
# 1. Clone
git clone https://github.com/labishbardiya/CureNet.git
cd CureNet/curenet

# 2. Install Flutter dependencies
flutter pub get

# 3. Install backend dependencies
cd backend && npm install && cd ..

# 4. Set up environment
cp backend/.env.example backend/.env
# Edit backend/.env with your API keys and MongoDB URI

# 5. Start backend
cd backend && npm run dev

# 6. Run Flutter app
flutter run \
  --dart-define=GROQ_API_KEY=your_key \
  --dart-define=TAVILY_API_KEY=your_key \
  --dart-define=BHASHINI_API_KEY=your_key \
  --dart-define=BHASHINI_USER_ID=your_id \
  --dart-define=BHASHINI_AUTH=your_auth
```

### Local Development (USB)

```bash
# Set up USB port forwarding (phone → Mac)
adb reverse tcp:3000 tcp:3000

# Run with local backend
flutter run --dart-define=BACKEND_URL=http://127.0.0.1:3000
```

---

## Cloud Deployment (Render)

The backend and Doctor's Portal are deployed on Render for cloud access.

### Live URLs
- **API**: `https://curenet-api.onrender.com`
- **Doctor Portal**: `https://curenet-api.onrender.com/portal`

### Deploy Your Own

1. Fork this repo on GitHub
2. Go to [render.com](https://render.com) → New Web Service → Connect repo
3. Configure:
   - **Root Directory**: `curenet`
   - **Build Command**: `cd backend && npm install`
   - **Start Command**: `cd backend && npm start`
4. Add environment variables: `MONGO_URI`, `GROQ_API_KEY`, `TAVILY_API_KEY`
5. Deploy

The `render.yaml` blueprint is included for one-click deployment.

---

## Doctor's Portal

The Doctor's Portal is a web-based interface for healthcare providers to request and view patient health data with real-time consent.

### Flow
1. Patient generates QR code from the app (Emergency Snapshot → Share)
2. Doctor opens portal at `https://curenet-api.onrender.com/portal`
3. Doctor enters the share ID from the QR code
4. Patient's phone auto-detects the request and shows an approval dialog
5. On approval, the doctor sees the patient's emergency health card
6. Access expires in 30 minutes or when the patient revokes it

---

## Environment Variables

### Backend (`backend/.env`)

| Variable | Required | Description |
|---|---|---|
| `MONGO_URI` | Yes | MongoDB Atlas connection string |
| `GROQ_API_KEY` | Yes | Groq Cloud API key |
| `TAVILY_API_KEY` | Yes | Tavily search API key |
| `BHASHINI_API_KEY` | Optional | Bhashini translation |
| `BHASHINI_USER_ID` | Optional | Bhashini user ID |
| `BHASHINI_AUTH` | Optional | Bhashini auth token |
| `OLLAMA_URL` | Optional | Local Ollama endpoint (default: localhost:11434) |
| `GEMMA4_MODEL` | Optional | Gemma 4 model name (default: gemma4:31b) |

### Flutter (`--dart-define`)

| Variable | Default | Description |
|---|---|---|
| `BACKEND_URL` | `https://curenet-api.onrender.com` | Backend API URL |
| `GROQ_API_KEY` | — | Groq API key |
| `TAVILY_API_KEY` | — | Tavily API key |
| `BHASHINI_API_KEY` | — | Bhashini key |

---

## API Endpoints

### Access Management
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/access/request` | Doctor creates access request |
| GET | `/api/access/pending/:userId` | Patient polls for pending requests |
| POST | `/api/access/respond` | Patient approves/denies |
| GET | `/api/access/status/:requestId` | Doctor polls for approval status |
| POST | `/api/access/revoke/:requestId` | Patient revokes access |

### Emergency Shares
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/emergency/share` | Create emergency share (returns shareId) |
| GET | `/api/emergency/:shareId` | Retrieve emergency data |

### OCR & Records
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/ocr/scan` | Process medical document image |
| GET | `/api/records/all` | Get all health records |

---

## Academic

### Project Details
- **Course**: Minor Project (PR1103)
- **Institution**: JK Lakshmipat University, IET
- **Faculty Guide**: Mr. Gaurav Raj, Assistant Professor, CSE
- **Team**: Labish Bardiya (2023BTECH106), Rakshika Sharma (2023BTECH065)

### Design
- [Figma Prototype](https://www.figma.com/design/McAGqBbIS6IET24IpoNC7z/CureNet-Prototype?t=RAh0iDHZpqQ5JNp6-1) (Password: `Curenet@2004`)

### Documentation
- [End-Term Report](docs/academic/CURENET_MINOR_PROJECT_REPORT.md)
- [Project Context](docs/academic/COMPLETE_PROJECT_CONTEXT.md)
- [Mid-Term Report](docs/academic/MIDTERM_REPORT.md)

---

## License

This project is developed as an academic minor project at JK Lakshmipat University.