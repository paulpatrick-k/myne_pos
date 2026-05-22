// pb_hooks/paystack.js
const axios = require('axios');

routerAdd('POST', '/api/init-payment', (c) => {
    const { amount, email, businessId, reference } = c.body;

    if (!amount || !email || !businessId || !reference) {
        return c.json(400, { error: 'Missing required fields' });
    }

    const SECRET_KEY = $os.getenv("PAYSTACK_SECRET_KEY");

    return axios.post('https://api.paystack.co/transaction/initialize', {
        amount: amount,
        email: email,
        reference: reference,
        metadata: { businessId: businessId }
    }, {
        headers: {
            Authorization: `Bearer ${SECRET_KEY}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        return c.json(200, { authorization_url: response.data.data.authorization_url });
    })
    .catch(error => {
        console.error(error.response?.data);
        return c.json(500, { error: 'Payment initialization failed' });
    });
});
