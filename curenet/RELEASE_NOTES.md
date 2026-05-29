# CureNet AI v1.0.0 — Production Release

**India's first ABDM-native, offline-first Health Intelligence Platform powered by Gemma 4**

---

## What's New in v1.0.0

### Real-Time Doctor Access Consent
- Doctor scans patient QR → sends access request via **Doctor's Portal**
- Patient's phone **auto-detects request within 4 seconds** and shows approval dialog
- Approve/Deny with one tap — works on **any screen** in the app
- 30-minute access window, **revocable anytime** by the patient
- Portal shows live data on approval, rejection screen on denial

### Cloud Deployment (Render)
- Backend + Doctor's Portal deployed on **Render** (cloud)
- **MongoDB Atlas** for persistent cloud database
- No USB cable or local server required — works from anywhere
- Doctor Portal accessible at: `https://curenet.onrender.com/portal`

### Multilingual Offline Fallback
- **60+ critical UI strings** pre-translated for Hindi and Bengali
- Works even when Bhashini API is unreachable
- Circuit breaker: stops hitting dead APIs after 3 failures

---

## Core Features (All Implemented)

| Feature | Status |
|---|---|
| **28 Production Screens** | ✅ |
| **Gemma 4 E4B + 31B Dense** (Ollama edge AI) | ✅ |
| **Groq Cloud Fallback** (works without Ollama) | ✅ |
| **Document Scanning** (camera + gallery) | ✅ |
| **FHIR R4 Bundle Generation** (756-line fhirBuilder.js) | ✅ |
| **ABDM Integration** (M1 + M2 + M3) | ✅ |
| **AES-256-GCM Encrypted ObjectBox** | ✅ |
| **Biometric Health Locker** (FaceID/Fingerprint) | ✅ |
| **ABHAy AI Assistant** (RAG + streaming) | ✅ |
| **Emergency Snapshot + QR Share** | ✅ |
| **22 Indian Languages** (Bhashini) | ✅ |
| **Doctor Access Portal** (real-time consent) | ✅ |
| **Cloud Deployment** (Render + Atlas) | ✅ |

---

## Architecture

```
Dual-Model AI (Edge-First):
  Gemma 4 E4B (128K context)  →  Intent, titles, basic parsing
  Gemma 4 31B Dense (256K)    →  Medical extraction, FHIR R4 conversion
  Groq Cloud                  →  Fallback when Ollama unavailable

Cloud Infrastructure:
  Render (Node.js + Portal)   →  https://curenet.onrender.com
  MongoDB Atlas               →  Persistent cloud database
  
Routing: Ollama local (primary) → Groq Cloud (fallback)
```

---

## Install

### Android APK
Download `app-release.apk` below and install on any Android device (Android 7.0+).

### Build from Source
```bash
git clone https://github.com/labishbardiya/CureNet.git
cd CureNet/curenet
flutter pub get
flutter run \
  --dart-define=GROQ_API_KEY=your_key \
  --dart-define=TAVILY_API_KEY=your_key
```

### Backend (Self-hosted)
```bash
cd backend && npm install
cp .env.example .env  # Add your MongoDB URI and API keys
npm start
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter/Dart |
| Backend | Node.js/Express (Render) |
| AI | Gemma 4 E4B + 31B (Ollama), Groq (fallback) |
| Database | ObjectBox (AES-256-GCM) + MongoDB Atlas |
| Standards | FHIR R4, ABDM V3, SNOMED CT, LOINC |
| Crypto | AES-256-GCM, RSA-OAEP, ECDH X25519 |
| Translation | Bhashini API (22 languages) |
| Deployment | Render (backend), MongoDB Atlas (database) |
