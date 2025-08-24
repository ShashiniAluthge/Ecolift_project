const express = require('express');
const {
    register,
    login,
    updateCollectorLocation,
    getNearbyCollectors,
    getNearbyActiveCollectors,
    getAllCollectors,
    getRequestedCustomerById,
    getRequestedCollectorById,
    getCollectorLocation
} = require('../controllers/userControllers');
const authenticate = require('../middlewares/authMiddleware');

const router = express.Router();

// Public routes
router.post('/register', register);
router.post('/login', login);

// Protected routes
router.get('/profile', authenticate, (req, res) => {
    res.json({ message: 'Profile data', user: req.user });
});

// Collector routes
router.patch('/collectors/location', authenticate, updateCollectorLocation);
router.get('/collectors/location', authenticate, getCollectorLocation);
router.get('/collectors/nearby', authenticate, getNearbyCollectors);
router.get('/collectors/active-nearby', authenticate, getNearbyActiveCollectors);
router.get('/collectors/all', getAllCollectors);
router.get('/customer/requested/:id', getRequestedCustomerById);
router.get('/collectors/requested/:id', getRequestedCollectorById);


module.exports = router;