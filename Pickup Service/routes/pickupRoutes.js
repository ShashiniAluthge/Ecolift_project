const express = require('express');
const { createPickupRequest, getPendingRequests, acceptPickupRequest,
    getAllCustomersPendingRequests, getAcceptedPickupsForCollector, updatePickupStatus,
    cancelPickupRequest, getInProgressPickupsForCollector, startPickup,
    getCompletedPickupsForCollector, updateCollectorToken, getAllRequests, updateCollectorLocation, getCustomerActivitiesByStatus } = require('../controllers/pickupController');
const authenticateMiddleware = require("../middlewares/authMiddleware");


const router = express.Router();




router.use(authenticateMiddleware);

// === PICKUP ROUTES ===
router.post('/', createPickupRequest);
router.get('/pending', getPendingRequests);
router.get('/allPendings', getAllCustomersPendingRequests);
router.get('/accepted', getAcceptedPickupsForCollector);
router.put('/:id/accept', acceptPickupRequest);
router.put('/:id/status', updatePickupStatus);
router.put('/:id/cancel', cancelPickupRequest);
router.get('/inProgress', getInProgressPickupsForCollector);
router.put('/:id/start', startPickup);
router.get('/completed', getCompletedPickupsForCollector);
router.get('/all', getAllRequests);
router.get('/activities/:status', getCustomerActivitiesByStatus);


router.put('/:id/location', updateCollectorLocation)





module.exports = router;