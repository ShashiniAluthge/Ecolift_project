const { createClient } = require('redis');

// Create Redis client
const client = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
});

// Error handling
client.on('error', (err) => {
    console.error('Redis Error:', err);
});

// Connection handling
client.on('connect', () => {
    console.log('Redis client connected');
});

// Connect to Redis
const connectRedis = async () => {
    try {
        await client.connect();
        console.log('Connected to Redis');
    } catch (error) {
        console.error('Redis connection error:', error);
        // Try to reconnect after 5 seconds
        setTimeout(connectRedis, 5000);
    }
};

// Update collector location in Redis
const updateCollectorLocation = async (collectorId, longitude, latitude) => {
    try {
        // Store location in Redis Geo set
        await client.geoAdd('collector-locations', {
            longitude,
            latitude, 
            member: collectorId
        });
        
        // Set this collector as active (with expiration of 5 minutes)
        await client.set(`collector:${collectorId}:active`, 'true', {
            EX: 300 // 5 minutes expiration
        });
        
        return true;
    } catch (error) {
        console.error('Redis update location error:', error);
        return false;
    }
};

// Find nearby collectors from Redis
const findNearbyCollectors = async (longitude, latitude, radius = 5, unit = 'km') => {
    try {
        // Get collectors within the specified radius
        const nearbyCollectors = await client.geoSearch(
            'collector-locations',
            {
                longitude,
                latitude
            },
            {
                radius,
                unit
            }
        );
        
        // Filter to only active collectors
        const activeCollectors = [];
        for (const collectorId of nearbyCollectors) {
            const isActive = await client.get(`collector:${collectorId}:active`);
            if (isActive) {
                activeCollectors.push(collectorId);
            }
        }
        
        return activeCollectors;
    } catch (error) {
        console.error('Redis find nearby error:', error);
        return [];
    }
};

// Get collector's current location
const getCollectorLocation = async (collectorId) => {
    try {
        const position = await client.geoPos('collector-locations', collectorId);
        if (position && position[0]) {
            return {
                longitude: position[0].longitude,
                latitude: position[0].latitude
            };
        }
        return null;
    } catch (error) {
        console.error('Redis get location error:', error);
        return null;
    }
};

module.exports = {
    client,
    connectRedis,
    updateCollectorLocation,
    findNearbyCollectors,
    getCollectorLocation
}; 