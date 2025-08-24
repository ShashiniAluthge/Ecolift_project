const { getIO } = require('../websocket');
const PickupRequest = require('../models/pickupRequestModel');
const axios = require('axios');
const { findNearbyActiveCollectors } = require('../services/redisService');
const { sendNotification } = require('../services/notificationService');


const createPickupRequest = async (req, res) => {
    try {
        const isInstant = !req.body.scheduledTime;
        const requestType = isInstant ? 'instant' : 'scheduled';

        const pickupData = {

            customerId: req.user.userId,
            location: req.body.location,
            items: req.body.items,
            requestType,
            ...(isInstant ? {} : { scheduledTime: req.body.scheduledTime }),
        };

        const pickup = await PickupRequest.create(pickupData);

        const customerResponse = await axios.get(`${process.env.USER_SERVICE_URL}/api/users/customer/requested/${req.user.userId}`);
        console.log("customerResponse data", customerResponse.data);

        const customer = customerResponse.data.customer;

        if (isInstant) {
            const users = await axios.get(`${process.env.USER_SERVICE_URL}/api/users/collectors/all`);
            console.log("users*********************");
            console.log(users.data.collectors);

            for (const user of users.data.collectors) {
                console.log("user.fcmToken", user.fcmToken);
                if (user.fcmToken) {
                    try {
                        const isSent = await sendNotification(
                            'New Instant Pickup',
                            'A customer has requested an instant pickup.',
                            user.fcmToken,
                            {
                                pickupId: pickup._id.toString(),
                                type: 'INSTANT_PICKUP',
                                customerId: customer._id.toString(),
                                location: JSON.stringify(pickup.location), // ✅ string
                                items: JSON.stringify(pickup.items),       // ✅ string
                            }
                        );


                        console.log('location', pickup.location)
                        console.log('waste types', pickup.items);
                        console.log('Notification sent:', isSent);
                        console.log(`Notification sent to ${user._id}`);
                    } catch (error) {
                        console.error(`Failed to send notification to ${user._id}:`, error.message);
                    }

                }


            }

            res.status(201).json({ message: 'Pickup request created', pickup: { ...pickup.toObject(), customer } });
            console.log("Pickup request created successfully");
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error creating pickup request', error: error.message });
    }
}

// const createPickupRequest = async (req, res) => {
//     try {
//         const isInstant = !req.body.scheduledTime;
//         const requestType = isInstant ? 'instant' : 'scheduled';

//         const pickupData = {
//             customerId: req.user.userId,
//             location: req.body.location,
//             items: req.body.items,
//             requestType,
//             ...(isInstant ? {} : { scheduledTime: req.body.scheduledTime })
//         };

//         const pickup = await PickupRequest.create(pickupData);

//         if (isInstant) {
//             const coordinates = req.body.location.coordinates;
//             const [longitude, latitude] = coordinates;

//             const activeCollectorIds = await findNearbyActiveCollectors(longitude, latitude, 5);

//             if (activeCollectorIds.length > 0) {
//                 // Get collectors' FCM tokens
//                 const collectors = await Collector.find({ _id: { $in: activeCollectorIds }, fcmToken: { $ne: null } });

//                 for (const collector of collectors) {
//                     await admin.messaging().send({
//                         token: collector.fcmToken,
//                         notification: {
//                             title: 'New Instant Pickup',
//                             body: 'A customer nearby has requested a pickup.',
//                         },
//                         data: {
//                             pickupId: pickup._id.toString(),
//                             type: 'INSTANT_PICKUP'
//                         }
//                     });
//                 }

//                 console.log(`Notified ${collectors.length} active collectors about pickup request`);
//             }
//         }


//         res.status(201).json({ message: 'Pickup request created', pickup });
//     } catch (error) {
//         console.error(error);
//         res.status(500).json({ message: 'Error creating pickup request', error: error.message });
//     }
// };


const getAllCustomersPendingRequests = async (req, res) => {
    try {
        console.log('Fetching all pending pickups from DB...');
        const pickups = await PickupRequest.find({ status: 'Pending' });
        console.log(`Found ${pickups.length} pending pickups`);

        const pickupsWithCustomer = await Promise.all(
            pickups.map(async (pickup) => {
                console.log(`Fetching customer for pickup ${pickup._id}...`);
                try {
                    const customerResponse = await axios.get(
                        `${process.env.USER_SERVICE_URL}/api/users/customer/requested/${pickup.customerId}`
                    );

                    console.log(
                        `Customer data for pickup ${pickup._id}:`,
                        customerResponse.data.customer
                    );

                    const customer = customerResponse.data.customer;

                    return {
                        ...pickup.toObject(),
                        customerDetails: customer,
                    };
                } catch (customerError) {
                    console.error(
                        `Failed to fetch customer for pickup ${pickup._id}:`,
                        customerError.message
                    );
                    return {
                        ...pickup.toObject(),
                        customerDetails: null,
                    };
                }
            })
        );

        console.log('Returning pickups with customer details:', pickupsWithCustomer);
        res.status(200).json(pickupsWithCustomer);
    } catch (error) {
        console.error('Error fetching pending requests:', error.message);
        res.status(500).json({
            message: 'Error fetching requests',
            error: error.message,
        });
    }
};



const getPendingRequests = async (req, res) => {
    try {
        const customerId = req.user.userId; // comes from your JWT middleware
        const requests = await PickupRequest.find({
            status: 'Pending',
            customerId: customerId,
        }).sort({ createdAt: -1 }); // Optional: latest first

        res.json(requests);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching requests', error: error.message });
    }
};

const getAcceptedPickupsForCollector = async (req, res) => {
    try {
        const collectorId = req.user.userId;

        // Fetch accepted pickups for the collector
        const pickups = await PickupRequest.find({
            status: "Accepted",
            collectorId,
        }).sort({ createdAt: -1 });

        // Fetch customer details for each pickup
        const pickupsWithCustomer = await Promise.all(
            pickups.map(async (pickup) => {
                try {
                    const customerResponse = await axios.get(
                        `${process.env.USER_SERVICE_URL}/api/users/customer/requested/${pickup.customerId}`
                    );

                    const customer = customerResponse.data.customer;

                    return {
                        ...pickup.toObject(),
                        customerDetails: customer,
                    };
                } catch (customerError) {
                    console.error(
                        `Failed to fetch customer for pickup ${pickup._id}:`,
                        customerError.message
                    );
                    return {
                        ...pickup.toObject(),
                        customerDetails: null,
                    };
                }
            })
        );

        res.status(200).json(pickupsWithCustomer);
    } catch (error) {
        console.error("Error fetching accepted pickups:", error.message);
        res.status(500).json({
            message: "Error fetching accepted pickups",
            error: error.message,
        });
    }
};

// const getAcceptedPickupsForCollector = async (req, res) => {
//     try {
//         const collectorId = req.user.userId;
//         const requests = await PickupRequest.find({ status: 'Accepted', collectorId });
//         res.json(requests);
//     } catch (error) {
//         res.status(500).json({ message: 'Error fetching accepted pickups', error: error.message });
//     }
// };

// const acceptPickupRequest = async (req, res) => {
//     const { requestId, collectorId } = req.body;

//     try {
//         const pickup = await PickupRequest.findById(requestId);

//         if (!pickup || pickup.status !== 'Pending') {
//             return res.status(400).json({ message: 'Pickup not available or already accepted' });
//         }

//         pickup.status = 'Accepted';
//         pickup.collectorId = collectorId;
//         await pickup.save();

//         const io = getIO();
//         io.notifyCustomer(pickup.customerId.toString(), {
//             type: 'pickupRequestAccepted',
//             data: pickup.toJSON()
//         });

//         res.json({ message: 'Pickup request accepted', pickup });
//     } catch (error) {
//         res.status(500).json({ message: 'Error accepting pickup request', error: error.message });
//     }
// };

const acceptPickupRequest = async (req, res) => {
    try {
        const requestId = req.params.id; // use param instead of body
        const collectorId = req.user.userId; // from auth middleware

        const pickup = await PickupRequest.findById(requestId);

        if (!pickup) {
            return res.status(404).json({ message: 'Pickup request not found' });
        }

        if (pickup.status !== 'Pending') {
            return res.status(400).json({ message: 'Pickup not available or already accepted' });
        }

        pickup.status = 'Accepted';
        pickup.collectorId = collectorId;
        pickup.acceptedAt = new Date(); // Add timestamp when accepted
        await pickup.save();

        console.log("accepted collector id :", collectorId);

        // Get customer details for FCM notification
        try {
            const customerResponse = await axios.get(`${process.env.USER_SERVICE_URL}/api/users/customer/requested/${pickup.customerId}`);
            const customer = customerResponse.data.customer;

            console.log("customer data:", customerResponse.data.customer);

            // Get collector details
            const collectorResponse = await axios.get(`${process.env.USER_SERVICE_URL}/api/users/collectors/requested/${req.user.userId}`);
            const collector = collectorResponse.data.collector;

            console.log("collector data:", collectorResponse.data.collector);


            console.log("Customer FCM Token:", customer.fcmToken);

            // Send FCM notification to customer
            if (customer.fcmToken) {
                try {
                    const isSent = await sendNotification(
                        'Pickup Request Accepted',
                        `Your pickup request has been accepted by ${collector.name || 'a collector'}.`,
                        customer.fcmToken,
                        {
                            pickupId: pickup._id.toString(),
                            type: 'PICKUP_ACCEPTED',
                            collectorId: collectorId.toString(),
                            collectorName: collector.name || 'Collector',
                            location: JSON.stringify(pickup.location),
                            items: JSON.stringify(pickup.items),
                            acceptedAt: pickup.acceptedAt.toISOString()
                        }
                    );

                    console.log('FCM Notification sent to customer:', isSent);
                    console.log(`Notification sent to customer ${customer._id}`);
                } catch (fcmError) {
                    console.error(`Failed to send FCM notification to customer ${customer.name}:`, fcmError.message);
                }
            } else {
                console.log('Customer does not have FCM token');
            }

        } catch (userServiceError) {
            console.error('Failed to fetch user details for notification:', userServiceError.message);
            // Don't fail the request if user service calls fail
        }

        res.json({
            message: 'Pickup request accepted successfully',
            pickup: pickup.toJSON()
        });
    } catch (error) {
        console.error('acceptPickupRequest error:', error);
        res.status(500).json({ message: 'Error accepting pickup request', error: error.message });
    }
};
const updatePickupStatus = async (req, res) => {
    try {
        const requestId = req.params.id;
        const { status } = req.body;
        const collectorId = req.user.userId;

        // Validate status
        const validStatuses = ['Accepted', 'In Progress', 'Completed'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({
                message: 'Invalid status. Valid statuses are: ' + validStatuses.join(', ')
            });
        }

        const pickup = await PickupRequest.findById(requestId);

        if (!pickup) {
            return res.status(404).json({ message: 'Pickup request not found' });
        }

        // Ensure only the assigned collector can update the status
        if (pickup.collectorId.toString() !== collectorId) {
            return res.status(403).json({ message: 'You are not authorized to update this pickup' });
        }

        // Update the status
        pickup.status = status;

        // Add timestamps for different status transitions
        if (status === 'In Progress') {
            pickup.startedAt = new Date();
        } else if (status === 'Completed') {
            pickup.completedAt = new Date();
        }

        await pickup.save();

        // Notify customer about status update via websocket (optional)
        try {
            const { getIO } = require('../websocket');
            const io = getIO();

            if (io && typeof io.to === 'function') {
                io.to(`user:${pickup.customerId.toString()}`).emit('pickup:statusUpdate', {
                    type: 'pickupStatusUpdated',
                    data: pickup.toJSON()
                });
            }
        } catch (socketError) {
            console.warn('WebSocket notification failed (this is okay):', socketError.message);
        }

        res.json({
            message: `Pickup status updated to ${status}`,
            pickup: pickup.toJSON()
        });
    } catch (error) {
        console.error('updatePickupStatus error:', error);
        res.status(500).json({ message: 'Error updating pickup status', error: error.message });
    }
};


const cancelPickupRequest = async (req, res) => {
    try {
        const requestId = req.params.id;
        const collectorId = req.user.userId;

        const pickup = await PickupRequest.findById(requestId);

        if (!pickup) {
            return res.status(404).json({ message: 'Pickup request not found' });
        }

        if (pickup.collectorId.toString() !== collectorId) {
            return res.status(403).json({ message: 'Not authorized to cancel this pickup' });
        }

        // Only allow cancel if status is Accepted or In Progress (optional)
        if (!['Accepted', 'In Progress'].includes(pickup.status)) {
            return res.status(400).json({ message: 'Pickup cannot be canceled at this stage' });
        }

        // Reset the status to Pending and remove collector assignment
        pickup.status = 'Pending';
        pickup.collectorId = null;
        pickup.acceptedAt = null;
        pickup.startedAt = null;
        pickup.completedAt = null;

        await pickup.save();

        // Notify via WebSocket (optional)
        try {
            const { getIO } = require('../websocket');
            const io = getIO();

            if (io && typeof io.to === 'function') {
                io.to(`user:${pickup.customerId.toString()}`).emit('pickup:statusUpdate', {
                    type: 'pickupCancelled',
                    data: pickup.toJSON(),
                });
                io.emit('pickup:becamePending', {
                    type: 'pickupPending',
                    data: pickup.toJSON(),
                });
            }
        } catch (socketError) {
            console.warn('WebSocket notification failed:', socketError.message);
        }

        res.json({ message: 'Pickup cancelled successfully', pickup: pickup.toJSON() });
    } catch (error) {
        console.error('cancelPickupRequest error:', error);
        res.status(500).json({ message: 'Error cancelling pickup', error: error.message });
    }
};

const getInProgressPickupsForCollector = async (req, res) => {
    try {
        const collectorId = req.user.userId;
        const pickups = await PickupRequest.find({
            status: 'In Progress',
            collectorId
        }).sort({ createdAt: -1 });

        const pickupsWithCustomer = await Promise.all(
            pickups.map(async (pickup) => {
                try {
                    const customerResponse = await axios.get(
                        `${process.env.USER_SERVICE_URL}/api/users/customer/requested/${pickup.customerId}`
                    );

                    const customer = customerResponse.data.customer;

                    return {
                        ...pickup.toObject(),
                        customerDetails: customer,
                    };
                } catch (customerError) {
                    console.error(
                        `Failed to fetch customer for pickup ${pickup._id}:`,
                        customerError.message
                    );
                    return {
                        ...pickup.toObject(),
                        customerDetails: null,
                    };
                }
            })
        );

        res.status(200).json(pickupsWithCustomer);
    } catch (error) {
        console.error('Error fetching in-progress pickups:', error.message);
        res.status(500).json({ message: 'Error fetching in-progress pickups', error: error.message });
    }
};

const startPickup = async (req, res) => {
    try {
        const requestId = req.params.id;
        const collectorId = req.user.userId; // from auth middleware

        const pickup = await PickupRequest.findById(requestId);

        if (!pickup) {
            return res.status(404).json({ message: 'Pickup request not found' });
        }

        // Ensure only the assigned collector can start it
        if (pickup.collectorId.toString() !== collectorId) {
            return res.status(403).json({ message: 'You are not authorized to start this pickup' });
        }

        // Only start if it's currently accepted
        if (pickup.status !== 'Accepted') {
            return res.status(400).json({ message: 'Pickup can only be started from Accepted status' });
        }

        pickup.status = 'In Progress';
        pickup.startedAt = new Date();
        await pickup.save();

        // Notify customer about the start
        try {
            const { getIO } = require('../websocket');
            const io = getIO();

            if (io && typeof io.to === 'function') {
                io.to(`user:${pickup.customerId.toString()}`).emit('pickup:statusUpdate', {
                    type: 'pickupStarted',
                    data: pickup.toJSON()
                });
            }
        } catch (socketError) {
            console.warn('WebSocket notification failed:', socketError.message);
        }

        res.json({
            message: 'Pickup started successfully',
            pickup: pickup.toJSON()
        });
    } catch (error) {
        console.error('startPickup error:', error);
        res.status(500).json({ message: 'Error starting pickup', error: error.message });
    }
};

const getCompletedPickupsForCollector = async (req, res) => {
    try {
        const collectorId = req.user.userId;
        const pickups = await PickupRequest.find({
            status: 'Completed',
            collectorId
        }).sort({ createdAt: -1 });

        const pickupsWithCustomer = await Promise.all(
            pickups.map(async (pickup) => {
                try {
                    const customerResponse = await axios.get(
                        `${process.env.USER_SERVICE_URL}/api/users/customer/requested/${pickup.customerId}`
                    );

                    const customer = customerResponse.data.customer;

                    return {
                        ...pickup.toObject(),
                        customerDetails: customer,
                    };
                } catch (customerError) {
                    console.error(
                        `Failed to fetch customer for pickup ${pickup._id}:`,
                        customerError.message
                    );
                    return {
                        ...pickup.toObject(),
                        customerDetails: null,
                    };
                }
            })
        );

        res.status(200).json(pickupsWithCustomer);
    } catch (error) {
        console.error('Error fetching completed pickups:', error.message);
        res.status(500).json({ message: 'Error fetching completed pickups', error: error.message });
    }
};

const getAllRequests = async (req, res) => {
    try {
        const customerId = req.user.userId;

        // Fetch all requests for the customer, regardless of status
        const requests = await PickupRequest.find({ customerId: customerId })
            .sort({ createdAt: -1 }); // Optional: latest first

        res.json(requests);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching requests', error: error.message });
    }
};

const getCustomerActivitiesByStatus = async (req, res) => {
    try {
        const customerId = req.user.userId;
        let { status } = req.params;

        console.log("==== getCustomerActivitiesByStatus() ====");
        console.log("Raw status param from frontend:", status);
        console.log("Customer ID:", customerId);

        // Normalize frontend values → DB enum values
        const statusMap = {
            'pending': 'Pending',
            'accepted': 'Accepted',
            'in progress': 'In Progress',
            'completed': 'Completed'
        };

        const normalizedStatus = statusMap[status?.toLowerCase()];
        console.log("Normalized status (for DB query):", normalizedStatus);

        if (!normalizedStatus) {
            console.warn(`⚠️ Invalid status received: "${status}"`);
            return res.status(400).json({ message: `Invalid status: ${status}` });
        }

        // Query DB
        const requests = await PickupRequest.find({ customerId, status: normalizedStatus })
            .sort({ createdAt: -1 });

        console.log(`DB Query: { customerId: ${customerId}, status: "${normalizedStatus}" }`);
        console.log(`Found ${requests.length} requests`);

        // If Accepted / In Progress → attach collector info
        if (['Accepted', 'In Progress'].includes(normalizedStatus)) {
            console.log("Fetching collector info for each request...");
            for (let request of requests) {
                if (request.collectorId) {
                    console.log(`Request ${request._id} has collectorId: ${request.collectorId}`);
                    try {
                        const collectorResponse = await axios.get(
                            `${process.env.USER_SERVICE_URL}/api/users/collectors/requested/${request.collectorId}`
                        );
                        request.collector = collectorResponse.data.collector;
                        console.log(`✅ Collector info attached for request ${request._id}`);
                    } catch (e) {
                        console.error(`❌ Failed to fetch collector ${request.collectorId}:`, e.message);
                        request.collector = null;
                    }
                } else {
                    console.log(`Request ${request._id} has no collector assigned yet.`);
                    request.collector = null;
                }
            }
        }

        console.log("==== End getCustomerActivitiesByStatus() ====");
        res.json(requests);

    } catch (error) {
        console.error("🔥 Error in getCustomerActivitiesByStatus():", error);
        res.status(500).json({ message: "Error fetching activities", error: error.message });
    }
};




const updateCollectorLocation = async (req, res) => {
    try {
        const { id } = req.params; // requestId
        const { latitude, longitude } = req.body;

        console.log('Updating collector location...');
        console.log('Request ID:', id);
        console.log('Latitude:', latitude, 'Longitude:', longitude);

        if (
            typeof latitude !== 'number' ||
            typeof longitude !== 'number' ||
            latitude < -90 || latitude > 90 ||
            longitude < -180 || longitude > 180
        ) {
            return res.status(400).json({ message: 'Invalid coordinates' });
        }

        const pickup = await PickupRequest.findByIdAndUpdate(
            id,
            {
                collectorLocation: {
                    type: 'Point',
                    coordinates: [longitude, latitude],
                },
            },
            { new: true }
        );

        console.log('Updated collector location:', pickup.collectorLocation);

        res.json({ success: true, location: pickup.collectorLocation });
    } catch (error) {
        console.error('Error updating location:', error);
        res.status(500).json({ message: 'Error updating location', error: error.message });
    }
};


// const updateCollectorToken = async (req, res) => {
//     try {
//         const { token } = req.body;
//         if (!token) {
//             return res.status(400).json({ message: "FCM token is required" });
//         }

//         await Collector.findByIdAndUpdate(req.user.userId, { fcmToken: token });
//         res.status(200).json({ message: "Token updated successfully" });
//     } catch (error) {
//         console.error(error);
//         res.status(500).json({ message: "Error updating token" });
//     }
// };





module.exports = {
    createPickupRequest,
    getPendingRequests,
    acceptPickupRequest,
    getAllCustomersPendingRequests,
    getAcceptedPickupsForCollector,
    updatePickupStatus,
    cancelPickupRequest,
    getInProgressPickupsForCollector,
    startPickup,
    getCompletedPickupsForCollector,
    getAllRequests,
    updateCollectorLocation,
    getCustomerActivitiesByStatus

};
