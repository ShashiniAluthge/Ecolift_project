require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const http = require('http');
const cors = require('cors');
const pickupRoutes = require('./routes/pickupRoutes');

const { setupWebSocket } = require('./websocket');
const { connectRedis } = require('./services/redisService');

const app = express();

app.use(cors());
app.use(express.json());

// Middleware for logging requests
app.use((req, res, next) => {
    console.log(req.method, req.path);
    console.log(req.headers);
    next();
});

// API routes
app.use('/api/pickups', pickupRoutes);


// Create HTTP server and attach WebSocket server
const server = http.createServer(app);
setupWebSocket(server);

mongoose.connect(process.env.MONGO_URI)
    .then(async () => {
        console.log('✅ Connected to MongoDB');

        // Connect to Redis
        // try {
        //     await connectRedis();
        //     console.log('✅ Connected to Redis');
        // } catch (err) {
        //     console.error('❌ Redis connection error:', err);
        //     console.log('⚠️  Continuing without Redis - notifications will still work via User Service API');
        // }

        const port = process.env.PORT || 5000;
        server.listen(port, () => {
            console.log(`✅ Pickup Service running on port ${port}`);
            console.log(`✅ WebSocket server initialized for real-time notifications`);
            console.log(`✅ Notification system ready`);
        });
    })
    .catch(err => console.error('❌ Database connection error:', err));