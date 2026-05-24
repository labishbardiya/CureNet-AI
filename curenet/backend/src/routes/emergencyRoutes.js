const express = require('express');
const router = express.Router();
const EmergencyShare = require('../models/EmergencyShare');
const { v4: uuidv4 } = require('uuid');

/**
 * @route POST /api/emergency/share
 * @desc Stores emergency data temporarily and returns a short shareId
 */
router.post('/share', async (req, res) => {
    try {
        const shareId = uuidv4().split('-')[0]; // Short ID
        const newShare = new EmergencyShare({
            shareId,
            data: req.body
        });
        await newShare.save();
        res.json({ shareId });
    } catch (err) {
        console.error('Error sharing emergency data:', err);
        res.status(500).json({ error: 'Failed to generate share link' });
    }
});

/**
 * @route GET /api/emergency/:id
 * @desc Serves a downloadable Emergency Health Card as a standalone HTML page.
 */
router.get('/:id', async (req, res) => {
    try {
        let data;
        // Try fetching from DB first
        const share = await EmergencyShare.findOne({ shareId: req.params.id });
        if (share) {
            data = share.data;
        } else {
            // Fallback to base64 decoding (legacy)
            try {
                data = JSON.parse(
                    Buffer.from(req.params.id, 'base64url').toString('utf-8')
                );
            } catch (e) {
                return res.status(404).send('<h1>Emergency Card Not Found</h1><p>The link may have expired.</p>');
            }
        }

        const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Digital Emergency Pass — ${data.name || 'Patient'}</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, system-ui, sans-serif; background: #0A121E; color: #fff; display: flex; flex-direction: column; align-items: center; padding: 40px 20px; }
  .card { background: #fff; border-radius: 28px; max-width: 440px; width: 100%; box-shadow: 0 40px 100px rgba(0,0,0,0.6); overflow: hidden; color: #0D2240; }
  .header { background: #0D2240; padding: 32px; color: #fff; }
  .identity { display: flex; align-items: center; gap: 20px; margin-bottom: 24px; }
  .icon { width: 64px; height: 64px; border-radius: 20px; background: #fff; border: 3px solid #D32F2F; display: flex; align-items: center; justify-content: center; font-size: 32px; }
  .name { font-size: 24px; font-weight: 900; letter-spacing: 0.5px; text-transform: uppercase; }
  .abha { font-size: 12px; color: #9BA8BB; font-weight: 700; letter-spacing: 1px; margin-top: 4px; }
  .pills { display: flex; justify-content: space-between; margin-top: 24px; }
  .pill { padding: 8px 16px; border-radius: 30px; font-size: 11px; font-weight: 900; background: rgba(255,255,255,0.1); letter-spacing: 0.5px; }
  .pill.urgent { background: #D32F2F; }
  .body { padding: 32px; }
  .section-title { font-size: 11px; font-weight: 900; color: #9BA8BB; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 12px; }
  .alert-box { background: #FDE8E8; border: 1px solid rgba(211,47,47,0.2); padding: 20px; border-radius: 20px; color: #D32F2F; font-weight: 800; font-size: 18px; margin-bottom: 32px; }
  .list-item { display: flex; gap: 12px; align-items: flex-start; margin-bottom: 12px; font-weight: 700; font-size: 15px; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: #E07B39; margin-top: 6px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 32px; padding-top: 32px; border-top: 1px solid #E8ECF0; }
  .vitals-val { font-size: 14px; font-weight: 800; margin-bottom: 4px; }
  .emergency-footer { background: #E6F7EF; border: 1px solid rgba(34,163,106,0.2); padding: 24px; border-radius: 24px; display: flex; align-items: center; gap: 20px; margin-top: 32px; }
  .phone-icon { font-size: 28px; color: #22A36A; }
  .save-btn { margin-top: 40px; background: #22A36A; color: #fff; border: none; padding: 20px 40px; border-radius: 24px; font-size: 18px; font-weight: 900; cursor: pointer; width: 100%; max-width: 440px; transition: 0.3s; box-shadow: 0 10px 30px rgba(34,163,106,0.3); }
  @media print { .save-btn { display: none; } body { background: #fff; padding: 0; } .card { box-shadow: none; } }
</style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="identity">
        <div class="icon">🆘</div>
        <div>
          <div class="name">${data.name || 'PATIENT'}</div>
          <div class="abha">ABHA: ${data.abha || ''}</div>
        </div>
      </div>
      <div class="pills">
        <div class="pill">AGE: ${data.age || '45'}</div>
        <div class="pill">GENDER: ${data.gender || 'MALE'}</div>
        <div class="pill urgent">BLOOD: ${data.bloodGroup || '?'}</div>
      </div>
    </div>
    <div class="body">
      <div class="section-title">⚠️ Critical Allergies</div>
      <div class="alert-box">${data.allergies || 'None Reported'}</div>

      <div class="section-title">💊 Active Medications</div>
      ${(data.medications || []).map(m => '<div class="list-item"><div class="dot"></div>' + m + '</div>').join('')}

      <div class="grid">
        <div>
          <div class="section-title">❤️ Latest Vitals</div>
          ${(data.vitals || []).map(v => '<div class="vitals-val">' + v + '</div>').join('')}
        </div>
        <div>
          <div class="section-title">🩺 Physician</div>
          <div style="font-weight:700; font-size:14px; color:#5A6880; line-height:1.4">${(data.physician || '').replace(/\n/g, '<br>')}</div>
        </div>
      </div>

      <div class="emergency-footer">
        <div class="phone-icon">📞</div>
        <div>
          <div style="font-size:10px; font-weight:900; color:#22A36A; letter-spacing:1px">EMERGENCY CONTACT</div>
          <div style="font-weight:800; font-size:16px">${data.emergencyName || ''}</div>
          <div style="font-weight:900; font-size:18px; color:#22A36A">${data.emergencyPhone || ''}</div>
        </div>
      </div>
    </div>
  </div>
  <button class="save-btn" onclick="window.print()">DOWNLOAD EMERGENCY PASS</button>
</body>
</html>`;

        res.setHeader('Content-Type', 'text/html');
        res.send(html);
    } catch (err) {
        console.error(err);
        res.status(500).send('Internal Server Error');
    }
});

module.exports = router;
