require('dotenv').config() // Load the dotenv library to read the .env file
const express = require('express'); // Import express library
const mongoose = require('mongoose'); // Import mongoose library
const cors = require('cors'); // Import CORS library
const { connectRedis } = require('./services/redisService');

const app = express(); // Create a new express application
const userRoutes = require('./routes/userRoutes'); // Import routes

app.use(cors()); // Use CORS to allow requests from different origins


// middleware
app.use(express.json());

app.use((req, res, next) => {
    console.log(req.path);
    console.log(req.headers);
    next();
})

app.use('/api/users', userRoutes);

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI)
    .then(() => {
        console.log('Connected to MongoDB');
        // Connect to Redis after MongoDB connection is established
        // connectRedis();

        const port = process.env.PORT

        // Define a route for the root of the app
        app.listen(port, () => {
            console.log(`User Service running on port ${port} and connected to user database successfully!`)
        })
    })
    .catch(err => console.error('MongoDB connection error:', err));



