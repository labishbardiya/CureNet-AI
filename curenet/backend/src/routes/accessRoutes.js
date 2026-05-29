const express = require('express');
const router = express.Router();
const AccessRequest = require('../models/AccessRequest');
const EmergencyShare = require('../models/EmergencyShare');
const { v4: uuidv4 } = require('uuid');

/**
 * @route POST /api/access/request
 * @desc Doctor creates an access request after scanning a patient's QR.
 * @body { shareId, doctorName?, doctorDevice? }
 */
router.post('/request', async (req, res) => {
    try {
        const { shareId, doctorName, doctorDevice } = req.body;
        if (!shareId) {
            return res.status(400).json({ error: 'shareId is required' });
        }

        // Verify the share exists
        let patientUserId = 'arjun';
        const share = await EmergencyShare.findOne({ shareId });
        if (!share) {
            // Try base64url decode fallback — still allow request
            try {
                JSON.parse(Buffer.from(shareId, 'base64url').toString('utf-8'));
            } catch (e) {
                return res.status(404).json({ error: 'Invalid share ID or expired.' });
            }
        }

        const requestId = uuidv4().split('-')[0] + uuidv4().split('-')[1];

        const accessReq = new AccessRequest({
            requestId,
            shareId,
            patientUserId,
            doctorInfo: {
                name: doctorName || 'Doctor',
                device: doctorDevice || req.headers['user-agent']?.substring(0, 60) || 'Unknown Device'
            },
            status: 'pending'
        });

        await accessReq.save();

        console.log(`[Access] New request ${requestId} from ${doctorName || 'Doctor'} for share ${shareId}`);

        res.json({
            status: 'ok',
            requestId,
            message: 'Access request sent. Waiting for patient approval.'
        });
    } catch (err) {
        console.error('[Access] Error creating request:', err);
        res.status(500).json({ error: 'Failed to create access request.' });
    }
});

/**
 * @route GET /api/access/pending/:userId
 * @desc Patient's Flutter app polls this to check for pending access requests.
 */
router.get('/pending/:userId', async (req, res) => {
    try {
        // Only show requests created in the last 30 minutes
        const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
        const pending = await AccessRequest.find({
            patientUserId: req.params.userId,
            status: 'pending',
            createdAt: { $gte: thirtyMinAgo }
        }).sort({ createdAt: -1 });

        res.json({
            status: 'ok',
            count: pending.length,
            requests: pending.map(r => ({
                requestId: r.requestId,
                shareId: r.shareId,
                doctorInfo: r.doctorInfo,
                status: r.status,
                createdAt: r.createdAt
            }))
        });
    } catch (err) {
        console.error('[Access] Error fetching pending:', err);
        res.status(500).json({ error: 'Failed to fetch pending requests.' });
    }
});

/**
 * @route POST /api/access/respond
 * @desc Patient approves or denies an access request.
 * @body { requestId, action: 'approved' | 'denied' }
 */
router.post('/respond', async (req, res) => {
    try {
        const { requestId, action } = req.body;
        if (!requestId || !['approved', 'denied'].includes(action)) {
            return res.status(400).json({ error: 'requestId and action (approved/denied) are required.' });
        }

        const accessReq = await AccessRequest.findOne({ requestId });
        if (!accessReq) {
            return res.status(404).json({ error: 'Access request not found.' });
        }

        if (accessReq.status !== 'pending') {
            return res.status(400).json({ error: `Request already ${accessReq.status}.` });
        }

        accessReq.status = action;
        accessReq.respondedAt = new Date();

        if (action === 'approved') {
            // Access expires 30 minutes after approval
            accessReq.expiresAt = new Date(Date.now() + 30 * 60 * 1000);
        }

        await accessReq.save();

        console.log(`[Access] Request ${requestId} ${action} by patient.`);

        res.json({
            status: 'ok',
            requestId,
            action,
            expiresAt: accessReq.expiresAt
        });
    } catch (err) {
        console.error('[Access] Error responding:', err);
        res.status(500).json({ error: 'Failed to respond to access request.' });
    }
});

/**
 * @route GET /api/access/status/:requestId
 * @desc Doctor's portal polls this to check if the patient approved/denied.
 *       If approved and not expired, also returns emergency data.
 */
router.get('/status/:requestId', async (req, res) => {
    try {
        const accessReq = await AccessRequest.findOne({ requestId: req.params.requestId });
        if (!accessReq) {
            return res.status(404).json({ error: 'Access request not found or expired.' });
        }

        const response = {
            status: 'ok',
            requestId: accessReq.requestId,
            accessStatus: accessReq.status,
            createdAt: accessReq.createdAt,
            respondedAt: accessReq.respondedAt,
            expiresAt: accessReq.expiresAt
        };

        // If approved and not expired, include the emergency data
        if (accessReq.status === 'approved') {
            if (accessReq.expiresAt && new Date() > accessReq.expiresAt) {
                // Auto-expire
                accessReq.status = 'revoked';
                await accessReq.save();
                response.accessStatus = 'revoked';
                response.reason = 'Access window expired (30 minutes).';
            } else {
                // Fetch emergency data
                const share = await EmergencyShare.findOne({ shareId: accessReq.shareId });
                if (share) {
                    response.emergencyData = share.data;
                } else {
                    // Try base64 decode
                    try {
                        response.emergencyData = JSON.parse(
                            Buffer.from(accessReq.shareId, 'base64url').toString('utf-8')
                        );
                    } catch (e) {
                        response.emergencyData = null;
                        response.warning = 'Emergency share data has expired.';
                    }
                }
            }
        }

        res.json(response);
    } catch (err) {
        console.error('[Access] Error checking status:', err);
        res.status(500).json({ error: 'Failed to check access status.' });
    }
});

/**
 * @route POST /api/access/revoke/:requestId
 * @desc Patient revokes a previously approved access request.
 */
router.post('/revoke/:requestId', async (req, res) => {
    try {
        const accessReq = await AccessRequest.findOne({ requestId: req.params.requestId });
        if (!accessReq) {
            return res.status(404).json({ error: 'Access request not found.' });
        }

        if (accessReq.status !== 'approved') {
            return res.status(400).json({ error: `Cannot revoke — request is ${accessReq.status}.` });
        }

        accessReq.status = 'revoked';
        accessReq.respondedAt = new Date();
        await accessReq.save();

        console.log(`[Access] Request ${req.params.requestId} REVOKED by patient.`);

        res.json({ status: 'ok', message: 'Access revoked successfully.' });
    } catch (err) {
        console.error('[Access] Error revoking:', err);
        res.status(500).json({ error: 'Failed to revoke access.' });
    }
});

/**
 * @route DELETE /api/access/clear
 * @desc Clear all access requests (dev/debug utility).
 */
router.delete('/clear', async (req, res) => {
    try {
        const result = await AccessRequest.deleteMany({});
        console.log(`[Access] Cleared ${result.deletedCount} access requests.`);
        res.json({ status: 'ok', deleted: result.deletedCount });
    } catch (err) {
        console.error('[Access] Error clearing:', err);
        res.status(500).json({ error: 'Failed to clear access requests.' });
    }
});

module.exports = router;
