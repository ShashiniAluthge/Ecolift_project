const jwt = require('jsonwebtoken');

const authenticate = async (req, res, next) => {
    const token = req.header('Authorization')?.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ message: "No token provided" });
    }

    try {
        // Direct JWT verification (no API call)
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        
        req.user = {
            userId: decoded.userId,
            role: decoded.role
        };
        
        next();
    } catch (err) {
        res.status(401).json({ message: "Invalid token" });
    }
};

module.exports = authenticate;