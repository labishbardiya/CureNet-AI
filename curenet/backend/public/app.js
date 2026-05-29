/* ═══════════════════════════════════════════════════════════════
   CureNet Doctor's Portal — Application Logic
   SPA with QR scanning, consent management, emergency card,
   records timeline, FHIR viewer
   ═══════════════════════════════════════════════════════════════ */

const API_BASE = window.location.origin;
let currentShareId = null;
let currentRequestId = null;
let currentEmergencyData = null;
let currentRecords = [];
let html5QrCode = null;
let scannerActive = false;
let statusPollInterval = null;

// ─── SPA Router ────────────────────────────────────────────────
function showView(viewId) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  const view = document.getElementById(viewId);
  if (view) view.classList.add('active');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

// ─── Toast Notifications ───────────────────────────────────────
function showToast(message) {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.textContent = message;
  document.body.appendChild(toast);

  requestAnimationFrame(() => {
    requestAnimationFrame(() => toast.classList.add('visible'));
  });

  setTimeout(() => {
    toast.classList.remove('visible');
    setTimeout(() => toast.remove(), 400);
  }, 3000);
}

// ─── QR Scanner ────────────────────────────────────────────────
function initQrScanner() {
  const scannerContainer = document.getElementById('qr-reader');
  if (!scannerContainer || scannerActive) return;

  html5QrCode = new Html5Qrcode('qr-reader');
  scannerActive = true;

  html5QrCode.start(
    { facingMode: 'environment' },
    { fps: 10, qrbox: { width: 250, height: 250 } },
    (decodedText) => {
      stopScanner();
      handleQrResult(decodedText);
    },
    () => {}
  ).catch(err => {
    console.warn('Camera access denied or unavailable:', err);
    scannerActive = false;
    document.getElementById('scanner-status').innerHTML =
      '<p style="color: var(--amber); font-size: 13px; text-align: center; padding: 20px;">📷 Camera not available. Please enter the Share ID manually below.</p>';
  });
}

function stopScanner() {
  if (html5QrCode && scannerActive) {
    html5QrCode.stop().then(() => { scannerActive = false; }).catch(() => { scannerActive = false; });
  }
}

function handleQrResult(url) {
  const parts = url.split('/api/emergency/');
  if (parts.length > 1) {
    const shareId = parts[1].split('?')[0].split('#')[0];
    requestAccess(shareId);
  } else {
    requestAccess(url.trim());
  }
}

// ─── Manual Share ID Input ─────────────────────────────────────
function handleManualInput() {
  const input = document.getElementById('share-id-input');
  const value = input.value.trim();
  if (!value) {
    showToast('Please enter a Share ID');
    return;
  }

  if (value.includes('/api/emergency/')) {
    handleQrResult(value);
  } else {
    requestAccess(value);
  }
}

// ─── QR Image Upload ──────────────────────────────────────────
function handleQrImageUpload(event) {
  const file = event.target.files[0];
  if (!file) return;
  decodeQrFromFile(file);
}

function decodeQrFromFile(file) {
  const statusEl = document.getElementById('upload-status');
  statusEl.innerHTML = '<div class="upload-status-scanning"><div class="spinner" style="width:16px;height:16px;border-width:2px;"></div> Scanning QR code from image...</div>';

  const canvasEl = document.getElementById('qr-upload-canvas');
  canvasEl.innerHTML = '';

  const scannerId = 'qr-scanner-' + Date.now();
  const scannerDiv = document.createElement('div');
  scannerDiv.id = scannerId;
  canvasEl.appendChild(scannerDiv);

  const scanner = new Html5Qrcode(scannerId);
  scanner.scanFile(file, true)
    .then(decodedText => {
      console.log('[QR Upload] Decoded:', decodedText);
      statusEl.innerHTML = '';
      try { scanner.clear(); } catch(e) {}
      handleQrResult(decodedText);
    })
    .catch(err => {
      console.error('[QR Upload] Decode failed:', err);
      statusEl.innerHTML = '<div class="upload-status-error">⚠️ No QR code found in image. Please try a clearer or cropped photo.</div>';
      try { scanner.clear(); } catch(e) {}
      document.getElementById('qr-file-input').value = '';
    });
}

// Drag and drop support
window.addEventListener('DOMContentLoaded', () => {
  const uploadArea = document.getElementById('upload-area');
  if (!uploadArea) return;

  ['dragenter', 'dragover'].forEach(evt => {
    uploadArea.addEventListener(evt, (e) => { e.preventDefault(); uploadArea.classList.add('drag-over'); });
  });
  ['dragleave', 'drop'].forEach(evt => {
    uploadArea.addEventListener(evt, (e) => { e.preventDefault(); uploadArea.classList.remove('drag-over'); });
  });
  uploadArea.addEventListener('drop', (e) => {
    const file = e.dataTransfer.files[0];
    if (file && file.type.startsWith('image/')) decodeQrFromFile(file);
  });
});

// ═══════════════════════════════════════════════════════════════
// CONSENT MANAGEMENT FLOW
// ═══════════════════════════════════════════════════════════════

// ─── Step 1: Request Access ────────────────────────────────────
async function requestAccess(shareId) {
  currentShareId = shareId;
  showView('view-waiting');

  try {
    const res = await fetch(`${API_BASE}/api/access/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        shareId,
        doctorName: 'Doctor',
        doctorDevice: navigator.userAgent.substring(0, 60)
      })
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Failed to send access request.');
    }

    const data = await res.json();
    currentRequestId = data.requestId;

    console.log('[Access] Request created:', currentRequestId);
    document.getElementById('waiting-request-id').textContent = currentRequestId;

    // Start polling for approval
    startStatusPolling();

  } catch (err) {
    console.error('[Access] Request error:', err);
    document.getElementById('error-message').textContent = err.message;
    showView('view-error');
  }
}

// ─── Step 2: Poll for Approval ─────────────────────────────────
function startStatusPolling() {
  stopStatusPolling();

  pollStatus(); // Immediate first check

  statusPollInterval = setInterval(pollStatus, 3000);
}

function stopStatusPolling() {
  if (statusPollInterval) {
    clearInterval(statusPollInterval);
    statusPollInterval = null;
  }
}

async function pollStatus() {
  if (!currentRequestId) return;

  try {
    const res = await fetch(`${API_BASE}/api/access/status/${currentRequestId}`);
    if (!res.ok) return;

    const data = await res.json();
    const status = data.accessStatus;

    if (status === 'approved') {
      stopStatusPolling();
      currentEmergencyData = data.emergencyData;

      if (currentEmergencyData) {
        renderEmergencyCard(currentEmergencyData);
        showView('view-card');
        showToast('✓ Patient approved access');
        fetchRecords();

        // Continue polling to detect revocation
        startRevocationPolling();
      } else {
        document.getElementById('error-message').textContent = 'Access approved but emergency data has expired.';
        showView('view-error');
      }

    } else if (status === 'denied') {
      stopStatusPolling();
      showView('view-denied');

    } else if (status === 'revoked') {
      stopStatusPolling();
      showView('view-revoked');
    }
    // If still 'pending', keep polling
  } catch (err) {
    console.warn('[Access] Poll error:', err);
  }
}

// ─── Step 3: Monitor for Revocation ────────────────────────────
function startRevocationPolling() {
  // Poll every 5 seconds to check if patient revoked
  statusPollInterval = setInterval(async () => {
    if (!currentRequestId) return;

    try {
      const res = await fetch(`${API_BASE}/api/access/status/${currentRequestId}`);
      if (!res.ok) return;

      const data = await res.json();
      if (data.accessStatus === 'revoked') {
        stopStatusPolling();
        showView('view-revoked');
        showToast('Access has been revoked by the patient');
      }
    } catch (err) {
      console.warn('[Access] Revocation poll error:', err);
    }
  }, 5000);
}

// ─── Render Emergency Card ─────────────────────────────────────
function renderEmergencyCard(data) {
  const container = document.getElementById('emergency-card-content');

  const medicationsList = (data.medications || [])
    .map(m => `<li><span class="med-dot"></span>${escapeHtml(m)}</li>`)
    .join('') || '<li style="color: var(--text-muted);">No medications recorded</li>';

  const conditionChips = (data.conditions || [])
    .map(c => `<span class="condition-chip">${escapeHtml(c)}</span>`)
    .join('') || '<span style="color: var(--text-muted); font-size: 13px;">No conditions recorded</span>';

  const vitalsHtml = (data.vitals || [])
    .map(v => `<div class="vitals-item">${escapeHtml(v)}</div>`)
    .join('') || '<div style="color: var(--text-muted); font-size: 13px;">No vitals recorded</div>';

  const physicianHtml = data.physician
    ? escapeHtml(data.physician).replace(/\n/g, '<br>')
    : '<span style="color: var(--text-muted);">Not specified</span>';

  container.innerHTML = `
    <div class="emergency-card">
      <div class="emergency-header">
        <div class="emergency-identity">
          <div class="emergency-icon">🆘</div>
          <div>
            <div class="emergency-name">${escapeHtml(data.name || 'PATIENT')}</div>
            <div class="emergency-abha">ABHA: ${escapeHtml(data.abha || 'Not linked')}</div>
          </div>
        </div>
        <div class="emergency-pills">
          <span class="emergency-pill">AGE: ${escapeHtml(data.age || '—')}</span>
          <span class="emergency-pill">GENDER: ${escapeHtml(data.gender || '—')}</span>
          <span class="emergency-pill urgent">BLOOD: ${escapeHtml(data.bloodGroup || '?')}</span>
        </div>
      </div>

      <div class="emergency-body">
        <div class="section-label">⚠️ Critical Allergies</div>
        <div class="allergy-box">${escapeHtml(data.allergies || 'None Reported')}</div>

        <div class="section-label">💊 Active Medications</div>
        <ul class="med-list">${medicationsList}</ul>

        <div class="section-label">🏥 Chronic Conditions</div>
        <div class="condition-chips">${conditionChips}</div>

        <div class="info-grid">
          <div>
            <div class="section-label">❤️ Latest Vitals</div>
            ${vitalsHtml}
          </div>
          <div>
            <div class="section-label">🩺 Physician</div>
            <div class="physician-text">${physicianHtml}</div>
          </div>
        </div>

        ${data.emergencyName || data.emergencyPhone ? `
        <div class="emergency-contact-box">
          <div class="emergency-contact-icon">📞</div>
          <div>
            <div class="emergency-contact-label">Emergency Contact</div>
            <div class="emergency-contact-name">${escapeHtml(data.emergencyName || '')}</div>
            <div class="emergency-contact-phone">${escapeHtml(data.emergencyPhone || '')}</div>
          </div>
        </div>` : ''}
      </div>
    </div>
  `;
}

// ─── Fetch Records ─────────────────────────────────────────────
async function fetchRecords() {
  try {
    const res = await fetch(`${API_BASE}/api/records/all`);
    if (!res.ok) return;
    const json = await res.json();
    currentRecords = json.data || [];
    renderRecords(currentRecords);
  } catch (err) {
    console.warn('Could not fetch records:', err);
  }
}

// ─── Render Records Timeline ───────────────────────────────────
function renderRecords(records) {
  const container = document.getElementById('records-timeline');
  const countEl = document.getElementById('records-count');

  if (!records || records.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">📋</div>
        <h3>No Records Found</h3>
        <p>Clinical records will appear here after the patient scans prescriptions or lab reports.</p>
      </div>`;
    if (countEl) countEl.innerHTML = '<strong>0</strong> records';
    return;
  }

  if (countEl) countEl.innerHTML = `<strong>${records.length}</strong> record${records.length !== 1 ? 's' : ''}`;

  container.innerHTML = records.map((record, index) => {
    const uiData = record.uiData || {};
    const summary = uiData.summary || {};
    const docType = uiData.document_type || record.abdmContext?.hiType || 'report';
    const typeClass = docType.includes('prescription') ? 'prescription' : docType.includes('lab') ? 'lab' : 'report';
    const typeIcon = typeClass === 'prescription' ? '💊' : typeClass === 'lab' ? '🔬' : '📄';
    const typeLabel = typeClass === 'prescription' ? 'Prescription' : typeClass === 'lab' ? 'Lab Report' : 'Report';

    const title = summary.doctor
      ? `${summary.doctor}${summary.diagnosis ? ' — ' + summary.diagnosis : ''}`
      : record.abdmContext?.displayString || `Record #${index + 1}`;

    const date = record.createdAt
      ? new Date(record.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
      : '';

    const medsCount = (uiData.medications || []).length;
    const labsCount = (uiData.lab_results || []).length;
    const meta = [date, medsCount ? `${medsCount} medications` : '', labsCount ? `${labsCount} lab results` : '']
      .filter(Boolean).join(' · ');

    return `
      <div class="record-item" onclick="viewRecord(${index})">
        <div class="record-item-header">
          <div class="record-item-left">
            <div class="record-type-icon ${typeClass}">${typeIcon}</div>
            <div>
              <div class="record-title">${escapeHtml(title)}</div>
              <div class="record-meta">${escapeHtml(meta)}</div>
            </div>
          </div>
          <span class="record-badge ${typeClass}">${typeLabel}</span>
        </div>
      </div>`;
  }).join('');
}

// ─── View Single Record (FHIR Bundle) ──────────────────────────
function viewRecord(index) {
  const record = currentRecords[index];
  if (!record) return;

  const uiData = record.uiData || {};
  const summary = uiData.summary || {};
  const fhirBundle = record.fhirBundle;

  document.getElementById('record-detail-title').textContent =
    summary.doctor || record.abdmContext?.displayString || `Record #${index + 1}`;

  const detailContainer = document.getElementById('record-detail-content');
  let html = '';

  // Summary grid
  if (summary.diagnosis || summary.chief_complaint) {
    html += '<div class="summary-grid">';
    if (summary.diagnosis) html += `<div class="summary-item"><div class="summary-item-label">Diagnosis</div><div class="summary-item-value">${escapeHtml(summary.diagnosis)}</div></div>`;
    if (summary.chief_complaint) html += `<div class="summary-item"><div class="summary-item-label">Chief Complaint</div><div class="summary-item-value">${escapeHtml(summary.chief_complaint)}</div></div>`;
    if (summary.doctor) html += `<div class="summary-item"><div class="summary-item-label">Doctor</div><div class="summary-item-value">${escapeHtml(summary.doctor)}</div></div>`;
    if (summary.date) html += `<div class="summary-item"><div class="summary-item-label">Date</div><div class="summary-item-value">${escapeHtml(summary.date)}</div></div>`;
    html += '</div>';
  }

  // Medications
  const meds = uiData.medications || [];
  if (meds.length > 0) {
    html += `<div style="margin-bottom: 24px;"><div class="section-label">💊 Medications (${meds.length})</div><ul class="med-list">
      ${meds.map(m => {
        const name = typeof m === 'string' ? m : (m.name || 'Unknown');
        const detail = typeof m === 'object' ? [m.dosage, m.frequency, m.duration].filter(Boolean).join(' · ') : '';
        return `<li><span class="med-dot"></span><div><strong>${escapeHtml(name)}</strong>${detail ? `<br><span style="font-size:12px;color:var(--text-muted);">${escapeHtml(detail)}</span>` : ''}</div></li>`;
      }).join('')}</ul></div>`;
  }

  // Lab results
  const labs = uiData.lab_results || [];
  if (labs.length > 0) {
    html += `<div style="margin-bottom: 24px;"><div class="section-label">🔬 Lab Results (${labs.length})</div><ul class="med-list">
      ${labs.map(l => {
        const name = typeof l === 'string' ? l : (l.test || l.name || 'Unknown');
        const value = typeof l === 'object' ? [l.value, l.unit].filter(Boolean).join(' ') : '';
        const ref = typeof l === 'object' && l.reference_range ? `Ref: ${l.reference_range}` : '';
        return `<li><span class="med-dot" style="background:var(--blue);"></span><div><strong>${escapeHtml(name)}</strong>${value ? ` — ${escapeHtml(value)}` : ''}${ref ? `<br><span style="font-size:12px;color:var(--text-muted);">${escapeHtml(ref)}</span>` : ''}</div></li>`;
      }).join('')}</ul></div>`;
  }

  // FHIR Bundle
  if (fhirBundle && fhirBundle.entry && fhirBundle.entry.length > 0) {
    html += `<div class="fhir-viewer"><div class="section-label">🔥 FHIR R4 Bundle (${fhirBundle.entry.length} resources)</div>
      ${fhirBundle.entry.map((entry, i) => {
        const resource = entry.resource || entry;
        const resourceType = resource.resourceType || 'Unknown';
        return `<div class="fhir-resource" id="fhir-resource-${i}">
          <div class="fhir-resource-header" onclick="toggleFhirResource(${i})">
            <span class="fhir-resource-type">${getResourceIcon(resourceType)} ${resourceType}</span>
            <span style="color:var(--text-muted);font-size:12px;">▼</span>
          </div>
          <div class="fhir-resource-body">
            <div class="fhir-json">${syntaxHighlightJson(JSON.stringify(resource, null, 2))}</div>
          </div>
        </div>`;
      }).join('')}</div>`;
  }

  detailContainer.innerHTML = html || `<div class="empty-state"><div class="empty-state-icon">📋</div><h3>No Detailed Data</h3><p>This record does not have structured clinical data.</p></div>`;
  showView('view-record-detail');
}

function toggleFhirResource(index) {
  const el = document.getElementById(`fhir-resource-${index}`);
  if (el) el.classList.toggle('expanded');
}

function getResourceIcon(type) {
  const icons = { 'Bundle': '📦', 'Composition': '📝', 'Patient': '🧑', 'Practitioner': '👨‍⚕️', 'Organization': '🏥', 'Encounter': '🤝', 'MedicationRequest': '💊', 'Observation': '🔬', 'DiagnosticReport': '📊', 'Condition': '🩺', 'AllergyIntolerance': '⚠️' };
  return icons[type] || '📄';
}

// ─── JSON Syntax Highlighting ──────────────────────────────────
function syntaxHighlightJson(json) {
  return escapeHtml(json).replace(
    /("(\\u[a-fA-F0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g,
    match => {
      let cls = 'number';
      if (/^"/.test(match)) { cls = /:$/.test(match) ? 'key' : 'string'; }
      else if (/true|false/.test(match)) { cls = 'boolean'; }
      else if (/null/.test(match)) { cls = 'null'; }
      return `<span class="${cls}">${match}</span>`;
    }
  );
}

// ─── Utility ───────────────────────────────────────────────────
function escapeHtml(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = String(str);
  return div.innerHTML;
}

// ─── Tab Switching ─────────────────────────────────────────────
function switchTab(tabName) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  event.target.classList.add('active');
  document.getElementById('tab-emergency').style.display = tabName === 'emergency' ? 'block' : 'none';
  document.getElementById('tab-records').style.display = tabName === 'records' ? 'block' : 'none';
}

// ─── Actions ───────────────────────────────────────────────────
function printCard() { window.print(); }

function goBack() {
  stopScanner();
  stopStatusPolling();
  currentShareId = null;
  currentRequestId = null;
  currentEmergencyData = null;
  currentRecords = [];
  const input = document.getElementById('share-id-input');
  if (input) input.value = '';
  showView('view-landing');
}

function goBackToCard() { showView('view-card'); }

// ─── Keyboard ──────────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && document.activeElement === document.getElementById('share-id-input')) {
    handleManualInput();
  }
});

// ─── Init ──────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  const hash = window.location.hash.substring(1);
  if (hash) {
    requestAccess(hash);
  } else {
    showView('view-landing');
  }
});
