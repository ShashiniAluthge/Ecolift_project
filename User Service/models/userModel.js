const mongoose = require('mongoose');
const schema = mongoose.Schema;
const userSchema = new schema({
    name: {
        type: String,
        required: true,
    },
    phone: {
        type: String,
        required: true,
        unique: true,
    },
    email: {
        type: String,
        required: true,
        unique: true,
    },
    password: {
        type: String,
        required: true,
    },
    role: {
        type: String,
        enum: ['customer', 'collector'],
        required: true,
    },
    address: {
        addressNo: { type: String },
        street: { type: String },
        city: { type: String },
        district: { type: String },
    },
    // Optional location field - not required during registration
    location: {
        type: {
            type: String,
            enum: ['Point'],
        },
        coordinates: {
            type: [Number],
            validate: {
                validator: function (v) {
                    // Only validate if coordinates are provided
                    if (!v || v.length === 0) return true;
                    return v.length === 2 &&
                        v[0] >= -180 && v[0] <= 180 &&
                        v[1] >= -90 && v[1] <= 90;
                },
                message: 'Invalid coordinates format [longitude, latitude]'
            }
        }
    },
    nicNumber: {
        type: String,
        required: function () { return this.role === 'collector'; }
    },
    vehicleInfo: {
        type: {
            type: String,
            required: function () { return this.role === 'collector'; }
        },
        number: {
            type: String,
            required: function () { return this.role === 'collector'; }
        },
        capacity: {
            type: Number,
            required: function () { return this.role === 'collector'; }
        }
    },
    wasteTypes: {
        type: [String],
        required: function () { return this.role === 'collector'; },
        validate: {
            validator: function (v) {
                // Skip validation if not a collector
                if (this.role !== 'collector') return true;
                // Otherwise ensure at least one waste type
                return v && v.length > 0;
            },
            message: 'At least one waste type must be specified'
        }
    },
    fcmToken: { type: String, default: null, index: true },
}, { timestamps: true });

userSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('User', userSchema);