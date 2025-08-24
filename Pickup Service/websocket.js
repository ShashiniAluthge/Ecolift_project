const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const axios = require('axios');

const clients = {
    collectors: new Map(),
    customers: new Map()
};

function setupWebSocket(server) {
    const websocketServer = new WebSocket.Server({
        server,
        verifyClient: (info, done) => {
            console.log(`Connection attempt from ${info.origin}`);
            done(true);
        }
    });

    const heartbeatInterval = setInterval(() => {
        websocketServer.clients.forEach(ws => {
            if (!ws.isAlive) {
                console.log('Terminating dead connection');
                return ws.terminate();
            }
            ws.isAlive = false;
            ws.ping();
        });
    }, 30000);

    websocketServer.on('connection', (wsclient) => {
        console.log('New client connected');
        wsclient.isAlive = true;

        wsclient.on('pong', () => {
            wsclient.isAlive = true;
        });

        wsclient.once('message', (rawMessage) => {
            console.log('Raw message received:', rawMessage);
            try {
                const { token, role } = JSON.parse(rawMessage);
                const decoded = jwt.verify(token, process.env.JWT_SECRET);

                const userId = decoded.userId;

                if (decoded.role !== role) {
                    throw new Error('Role mismatch');
                }

                if (decoded.exp * 1000 < Date.now()) {
                    throw new Error('Token has expired');
                }

                const userMap = role === 'collector' ? clients.collectors : clients.customers;
                userMap.set(userId, wsclient);

                console.log(`Authenticated ${role}: ${userId}`);
                wsclient.send(JSON.stringify({
                    type: 'AUTH_SUCCESS',
                    userId
                }));

                wsclient.on('message', (message) => {
                    try {
                        const parsed = JSON.parse(message);
                        console.log(`Received message type: ${parsed.type}`);

                        // Handle different message types
                        if (role === 'collector' && parsed.type === 'LOCATION_UPDATE') {
                            handleCollectorLocationUpdate(userId, parsed.coordinates, token);
                        } else {
                            // Generic response for other messages
                            wsclient.send(JSON.stringify({
                                type: 'MESSAGE_RECEIVED',
                                text: `Server received: ${parsed.messageText || 'Message'}`,
                                timestamp: Date.now()
                            }));
                        }
                    } catch (err) {
                        console.error('Error processing message:', err);
                        wsclient.send(JSON.stringify({
                            type: 'ERROR',
                            message: 'Error processing your message'
                        }));
                    }
                });

            } catch (err) {
                console.error('Authentication failed:', err.message);
                wsclient.send(JSON.stringify({
                    type: 'AUTH_ERROR',
                    message: err.message
                }));
                wsclient.close();
            }
        });

        wsclient.on('close', () => {
            [clients.collectors, clients.customers].forEach(map => {
                map.forEach((value, key) => {
                    if (value === wsclient) {
                        console.log(`${key} disconnected`);
                        map.delete(key);
                    }
                });
            });
        });
    });

    websocketServer.on('close', () => {
        clearInterval(heartbeatInterval);
    });

    return websocketServer;
}

// Handle location updates from collectors
async function handleCollectorLocationUpdate(collectorId, coordinates, token) {
    try {
        // Forward the location update to the User Service
        await axios.patch(`${process.env.USER_SERVICE_URL}/api/users/collectors/location`,
            { coordinates },
            { headers: { Authorization: `Bearer ${token}` } }
        );

        console.log(`Updated location for collector ${collectorId}: [${coordinates}]`);

        // Notify the collector that the update was successful
        const client = clients.collectors.get(collectorId);
        if (client && client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
                type: 'LOCATION_UPDATE_SUCCESS',
                timestamp: Date.now()
            }));
        }
    } catch (error) {
        console.error('Error updating collector location:', error.message);

        // Notify the collector about the error
        const client = clients.collectors.get(collectorId);
        if (client && client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
                type: 'LOCATION_UPDATE_ERROR',
                message: 'Failed to update your location',
                timestamp: Date.now()
            }));
        }
    }
}

function getIO() {
    return {
        notifyCollectors: (message, collectorIds) => {
            collectorIds.forEach(collectorId => {
                const client = clients.collectors.get(collectorId);
                if (client && client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify({
                        ...message,
                        timestamp: Date.now()
                    }));
                }
            });
        },
        notifyCustomer: (userId, message) => {
            const client = clients.customers.get(userId);
            if (client && client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                    ...message,
                    timestamp: Date.now()
                }));
            }
        }
    };
}

module.exports = { setupWebSocket, getIO };
