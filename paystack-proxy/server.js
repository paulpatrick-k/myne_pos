const express = require('express');
const axios = require('axios');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config();

const app = express();
app.use(express.json());

const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY;
const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://127.0.0.1:8090';
const PB_ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL;
const PB_ADMIN_PASSWORD = process.env.PB_ADMIN_PASSWORD;

// Endpoint to initialize payment
app.post('/init-payment', async (req, res) => {
    console.log('➡️ /init-payment called', req.body);
    const { amount, email, businessId, reference } = req.body;

    if (!amount || !email || !businessId || !reference) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    try {
        const response = await axios.post('https://api.paystack.co/transaction/initialize', {
            amount: amount,
            email: email,
            reference: reference,
            callback_url: 'https://myne.app/success',
            metadata: { businessId: businessId }
        }, {
            headers: {
                Authorization: `Bearer ${PAYSTACK_SECRET}`,
                'Content-Type': 'application/json'
            }
        });

        console.log('✅ Paystack init success, auth URL:', response.data.data.authorization_url);
        res.json({ authorization_url: response.data.data.authorization_url });
    } catch (error) {
        console.error('❌ Paystack init error:', error.response?.data || error.message);
        res.status(500).json({ error: 'Payment initialization failed' });
    }
});

// NEW: Confirm payment and activate subscription (synchronous)
app.post('/confirm-payment', async (req, res) => {
    console.log('➡️ /confirm-payment called', req.body);
    const { reference, businessId } = req.body;

    if (!reference || !businessId) {
        return res.status(400).json({ error: 'Missing reference or businessId' });
    }

    try {
        // 1. Verify transaction status with Paystack
        const verifyRes = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {
            headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
        });
        const data = verifyRes.data.data;
        if (data.status !== 'success') {
            console.log('⚠️ Transaction not successful:', data.status);
            return res.status(400).json({ error: 'Transaction not successful' });
        }
        console.log('✅ Transaction verified as successful');

        // 2. Activate subscription (extend trial by 30 days)
        const newTrialEnd = new Date();
        newTrialEnd.setDate(newTrialEnd.getDate() + 30);

        // 3. Authenticate with PocketBase admin
        const authRes = await axios.post(`${POCKETBASE_URL}/api/admins/auth-with-password`, {
            identity: PB_ADMIN_EMAIL,
            password: PB_ADMIN_PASSWORD
        });
        const adminToken = authRes.data.token;
        console.log('✅ PocketBase admin authenticated');

        // 4. Update the business record
        await axios.patch(`${POCKETBASE_URL}/api/collections/businesses/records/${businessId}`, {
            subscription_active: true,
            trial_end: newTrialEnd.toISOString(),
            paystack_transaction_ref: reference
        }, {
            headers: { Authorization: adminToken }
        });

        console.log(`✅ Subscription activated for business ${businessId}, trial_end: ${newTrialEnd.toISOString()}`);
        res.json({ success: true });
    } catch (error) {
        console.error('❌ Confirmation error:', error.response?.data || error.message);
        res.status(500).json({ error: 'Activation failed: ' + (error.response?.data?.message || error.message) });
    }
});

// (Optional) Webhook endpoint – keep for redundancy
app.post('/paystack-webhook', async (req, res) => {
    const signature = req.headers['x-paystack-signature'];
    const secret = PAYSTACK_SECRET;
    const hash = crypto.createHmac('sha512', secret)
        .update(JSON.stringify(req.body))
        .digest('hex');
    if (hash !== signature) {
        return res.status(401).json({ error: 'Invalid signature' });
    }

    const event = req.body.event;
    if (event === 'charge.success') {
        const data = req.body.data;
        const reference = data.reference;
        const businessId = data.metadata.businessId;
        // You could also call the same activation logic here, but we rely on synchronous confirm.
        console.log(`Webhook received for ${reference}, business ${businessId}`);
        // For safety, you might want to activate here as well.
    }
    res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Paystack proxy listening on port ${PORT}`);
});
