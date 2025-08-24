const jwt = require('jsonwebtoken');
const User = require('../models/userModel');
const bcrypt = require('bcrypt'); // For hashing passwords
const redisService = require('../services/redisService');


const register = async (req, res) => {
    const {
        name,
        phone,
        email,
        password,
        role,
        address,
        location,
        nicNumber,
        vehicleInfo,
        wasteTypes
    } = req.body;

    try {
        // Validate role
        if (!['customer', 'collector'].includes(role)) {
            return res.status(400).json({ message: 'Invalid role specified' });
        }

        // Check if user already exists
        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }

        // Validate required fields based on role
        if (role === 'customer' && !address) {
            return res.status(400).json({ message: 'Address is required for customers' });
        }

        // Validate collector-specific fields
        if (role === 'collector') {
            if (!nicNumber) {
                return res.status(400).json({ message: 'NIC number is required for collectors' });
            }
            if (!vehicleInfo?.type || !vehicleInfo?.number || !vehicleInfo?.capacity) {
                return res.status(400).json({
                    message: 'Vehicle information (type, number, and capacity) is required for collectors'
                });
            }
            if (!wasteTypes || !Array.isArray(wasteTypes) || wasteTypes.length === 0) {
                return res.status(400).json({
                    message: 'At least one waste type must be specified for collectors'
                });
            }
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Create base user data
        const userData = {
            name,
            phone,
            email,
            password: hashedPassword,
            role
        };

        // Add role-specific data
        if (role === 'customer') {
            userData.address = address;
        } else if (role === 'collector') {
            userData.nicNumber = nicNumber;
            userData.vehicleInfo = vehicleInfo;
            userData.wasteTypes = wasteTypes;
        }

        // Add location if provided
        if (location) {
            userData.location = location;
        }

        const user = await User.create(userData);

        res.status(201).json({
            message: 'User registered successfully',
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
        console.error('Registration error:', error);
    }
};

const login = async (req, res) => {
    const { email, password, fcmToken } = req.body;

    console.log('Login attempt:', { email, fcmToken });

    try {
        const user = await User.findOne({ email });
        if (!user) return res.status(401).json({ message: 'Invalid credentials' });

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        // Generate JWT with role information
        const token = jwt.sign(
            {
                userId: user._id.toString(), // Ensure ObjectId is converted to string
                role: user.role
            },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN }
        );

        // Return role-specific data
        const responseData = {
            id: user._id,
            name: user.name,
            email: user.email,
            phone: user.phone,
            role: user.role
        };

        if (user.role === 'customer') {
            responseData.address = user.address;
        } else {
            responseData.location = user.location;
            responseData.nicNumber = user.nicNumber;
            responseData.vehicleInfo = user.vehicleInfo;
            responseData.wasteTypes = user.wasteTypes;
        }
        const fcmUpdate = await User.updateOne(
            { _id: user._id },
            { $set: { fcmToken } });

        console.log('FCM token updated:', fcmUpdate);

        res.json({
            message: 'User logged in successfully',
            token,
            user: responseData
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

const updateCollectorLocation = async (req, res) => {
    try {
        console.log("---- updateCollectorLocation called ----");
        console.log("User ID:", req.user?.userId);
        console.log("User Role:", req.user?.role);
        console.log("Request Body:", req.body);

        if (req.user.role !== 'collector') {
            console.log("❌ Forbidden: User is not a collector");
            return res.status(403).json({ message: 'Only collectors can update locations' });
        }

        const coordinates = req.body.coordinates;
        console.log("📍 Incoming collector coordinates:", coordinates);

        if (!coordinates || !Array.isArray(coordinates) || coordinates.length !== 2) {
            console.log("❌ Invalid coordinates format");
            return res.status(400).json({ message: 'Invalid coordinates format. Expected [longitude, latitude]' });
        }

        // Destructure for clarity
        const [longitude, latitude] = coordinates;
        console.log(`✅ Parsed coordinates: Longitude=${longitude}, Latitude=${latitude}`);

        // Update location in MongoDB
        console.log("➡️ Updating MongoDB with collector location...");
        const user = await User.findByIdAndUpdate(
            req.user.userId,
            {
                location: {
                    type: 'Point',
                    coordinates: [longitude, latitude]
                }
            },
            { new: true, runValidators: true }
        );

        if (!user) {
            console.log("❌ User not found in database");
            return res.status(404).json({ message: 'User not found' });
        }

        console.log("✅ Location updated in MongoDB:", user.location);

        res.status(200).json({
            message: 'Location updated successfully',
            user: {
                id: user._id,
                location: user.location
            }
        });
    } catch (error) {
        console.error("🔥 Error updating collector location:", error);
        res.status(500).json({ message: 'Error updating location', error: error.message });
    }
};

const getCollectorLocation = async (req, res) => {
    try {
        console.log("--- getCollectorLocation API called ---");

        const collectorId = req.query.collectorId; // customer passes collector id
        console.log("Collector ID from query:", collectorId);

        if (!collectorId) {
            console.log("Error: collectorId is missing in request");
            return res.status(400).json({ message: 'collectorId is required' });
        }

        const user = await User.findById(collectorId);
        console.log("User fetched from DB:", user ? "FOUND" : "NOT FOUND");

        if (!user) {
            console.log("Error: Collector not found in DB");
            return res.status(404).json({ message: 'Collector not found' });
        }

        if (!user.location) {
            console.log("Error: Collector has no location saved");
            return res.status(404).json({ message: 'Collector location not found' });
        }

        console.log("Collector location coordinates:", user.location.coordinates);

        res.status(200).json({
            location: user.location.coordinates // [lng, lat]
        });
    } catch (error) {
        console.error("Error in getCollectorLocation:", error.message);
        res.status(500).json({ message: 'Error fetching location', error: error.message });
    }
};




const getNearbyCollectors = async (req, res) => {
    try {
        const coordinates = req.query.coordinates.map(Number);
        const maxDistance = req.query.maxDistance || 5000;

        const collectors = await User.find({
            role: 'collector',
            location: {
                $near: {
                    $geometry: {
                        type: "Point",
                        coordinates
                    },
                    $maxDistance: maxDistance
                }
            }
        }).select('-password -__v');

        res.status(200).json({
            message: 'Nearby collectors found',
            count: collectors.length,
            collectors
        });
    } catch (error) {
        res.status(400).json({ message: 'Error finding collectors', error: error.message });
    }
};

const getNearbyActiveCollectors = async (req, res) => {
    try {
        const coordinates = req.query.coordinates.map(Number);
        const [longitude, latitude] = coordinates;
        const radius = parseFloat(req.query.radius) || 5; // Default 5 km

        // Get collector IDs from Redis
        const collectorIds = await redisService.findNearbyCollectors(
            longitude,
            latitude,
            radius
        );

        if (!collectorIds.length) {
            return res.status(200).json({
                message: 'No active collectors found nearby',
                collectors: []
            });
        }

        // Get full collector data from MongoDB using the IDs from Redis
        const collectors = await User.find({
            _id: { $in: collectorIds },
            role: 'collector'
        }).select('-password -__v');

        // Add real-time location from Redis
        const collectorsWithLocation = await Promise.all(
            collectors.map(async (collector) => {
                const redisLocation = await redisService.getCollectorLocation(collector._id.toString());
                return {
                    ...collector.toObject(),
                    currentLocation: redisLocation
                };
            })
        );

        res.status(200).json({
            message: 'Nearby active collectors found',
            count: collectorsWithLocation.length,
            collectors: collectorsWithLocation
        });
    } catch (error) {
        res.status(400).json({ message: 'Error finding active collectors', error: error.message });
    }
};

const getAllCollectors = async (req, res) => {
    try {
        const collectors = await User.find({ role: 'collector' }).select('-password -__v');
        res.status(200).json({
            message: 'All collectors retrieved successfully',
            count: collectors.length,
            collectors
        });
    } catch (error) {
        res.status(400).json({ message: 'Error retrieving collectors', error: error.message });
    }
};
// Get customer details by ID
const getRequestedCustomerById = async (req, res) => {
    try {
        const { id } = req.params;

        // Find the user by ID and ensure the role is 'customer'
        const customer = await User.findOne({ _id: id, role: 'customer' }).select('-password -__v');

        if (!customer) {
            return res.status(404).json({ message: 'Customer not found' });
        }

        res.status(200).json({
            message: 'Customer retrieved successfully',
            customer
        });
    } catch (error) {
        console.error('Error fetching customer:', error);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

// Get collector details by ID
const getRequestedCollectorById = async (req, res) => {
    try {
        const { id } = req.params;

        // Find the user by ID and ensure the role is 'collector'
        const collector = await User.findOne({ _id: id, role: 'collector' }).select('-password -__v');
        console.log("collector id", id)

        if (!collector) {
            return res.status(404).json({ message: 'Collector not found' });
        }

        res.status(200).json({
            message: 'Collector retrieved successfully',
            collector
        });
    } catch (error) {
        console.error('Error fetching collector:', error);
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};



module.exports = {
    register,
    login,
    updateCollectorLocation,
    getNearbyCollectors,
    getNearbyActiveCollectors,
    getAllCollectors,
    getRequestedCustomerById,
    getRequestedCollectorById,
    getCollectorLocation
};
