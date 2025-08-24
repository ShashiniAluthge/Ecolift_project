const jwt = require('jsonwebtoken');

const authenticate = async (req, res, next) => {
    const token = req.header('Authorization')?.split(' ')[1];
    
    if (!token) {
        console.log('No token provided');
        return res.status(401).json({ message: "No token provided" });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        console.log('Decoded token:', decoded); // Add this line
        
        req.user = {
            userId: decoded.userId,
            role: decoded.role
        };
        
        next();
    } catch (err) {
        console.log('Token verification failed:', err.message);
        res.status(401).json({ message: "Invalid token" });
    }
};

module.exports = authenticate;