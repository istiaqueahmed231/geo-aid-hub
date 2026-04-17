const https = require('https');

const API_KEY = "AIzaSyDwnQj_7B2-cp7qz4wVLOW92AGMXBAuA9Q";
const users = ['admin@geoaid.com', 'test@test.com'];
const password = 'password123';

function createUser(email) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            email: email,
            password: password,
            returnSecureToken: true
        });

        const options = {
            hostname: 'identitytoolkit.googleapis.com',
            path: `/v1/accounts:signUp?key=${API_KEY}`,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': data.length
            }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                const response = JSON.parse(body);
                if (response.error) {
                    if (response.error.message === 'EMAIL_EXISTS') {
                        console.log(`✅ ${email} already exists in Firebase.`);
                        resolve();
                    } else {
                        console.error(`❌ Failed to create ${email}: ${response.error.message}`);
                        resolve();
                    }
                } else {
                    console.log(`✅ Successfully created ${email} in Firebase!`);
                    resolve();
                }
            });
        });

        req.on('error', (e) => reject(e));
        req.write(data);
        req.end();
    });
}

async function main() {
    for (const email of users) {
        await createUser(email);
    }
    console.log(`\n🎉 You can now log in using the password: ${password}`);
}

main();
