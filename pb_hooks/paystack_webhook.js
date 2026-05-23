// pb_hooks/paystack_webhook.js
console.log("✅ paystack_webhook.js is being loaded");
const crypto = require('crypto');

onBeforeServe((e) => {
    console.log("✅ paystack_webhook.js: registering route /api/paystack-webhook");
    e.router.addRoute('POST', '/api/paystack-webhook', (c) => {
        const payload = c.body;
        const signature = c.request.headers['x-paystack-signature'];
        const secret = $os.getenv("PAYSTACK_SECRET_KEY");

        const hash = crypto.createHmac('sha512', secret)
                           .update(JSON.stringify(payload))
                           .digest('hex');
        
        if (hash !== signature) {
            return c.json(401, { error: 'Invalid signature' });
        }

        const event = payload.event;
        if (event === 'charge.success') {
            const data = payload.data;
            const reference = data.reference;
            const businessId = data.metadata.businessId;

            const newTrialEnd = new Date();
            newTrialEnd.setDate(newTrialEnd.getDate() + 30);

            const $app = c.app;
            const bizCollection = $app.findCollectionByNameOrId('businesses');
            const record = $app.dao().findFirstRecordByFilter(bizCollection, 'id = {:id}', { id: businessId });
            if (record) {
                record.set('subscription_active', true);
                record.set('trial_end', newTrialEnd.toISOString());
                record.set('paystack_transaction_ref', reference);
                $app.dao().saveRecord(record);
                console.log(`✅ Subscription activated for business ${businessId}`);
            }
        }

        return c.json(200, { status: 'ok' });
    });
});
