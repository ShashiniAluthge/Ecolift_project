const admin = require('../config/firebaseInitializer'); // Ensure this path is correct

const sendNotification = async (title, body, token, data) => {
    // if (!title || !body || !token || !data) {
    //     return { status: false, error: 'Title, body, token, and data are required.', response_code: 400 };
    // }

    const message = {
        notification: {
            title,
            body
        },
        token,// FCM device token (from mobile/web app)
        data: data // Optional data payload
    };

    try {
        try {
            const response = await admin.messaging().send(message);
            console.log('Successfully sent message:', response);
            return { status: true, response, response_code: 200 };

        } catch (error) {
            console.error('Error sending message:', error);
            return { status: false, error: error.message, response_code: 500 };
        }
    }
    catch (error) {
        console.error('Error sending message:', error);
        return { status: false, error: error.message, response_code: 500 };
    }
};

module.exports = {
    sendNotification
};