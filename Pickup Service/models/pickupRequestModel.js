const mongoose = require('mongoose');

const pickupRequestSchema = new mongoose.Schema({
    customerId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    location: {
        type: {
            type: String,
            enum: ['Point'],
            required: true
        },
        coordinates: {
            type: [Number],
            required: true,
            validate: {
                validator: function (v) {
                    return v.length === 2 &&
                        v[0] >= -180 && v[0] <= 180 &&
                        v[1] >= -90 && v[1] <= 90;
                },
                message: 'Invalid coordinates format [longitude, latitude]'
            }
        }
    },
    items: {
        type: [
            {
                type: { type: String, required: true },
                quantity: { type: Number, required: true },
                description: { type: String }
            }
        ],
        required: true,
        validate: {
            validator: function (v) {
                return v.length > 0 && v.every(item =>
                    typeof item.type === 'string' && item.type.trim() !== '' &&
                    typeof item.quantity === 'number'
                );
            },
            message: 'Each item must have a nonempty type and a valid quantity, and at least one item is required'
        }
    },
    scheduledTime: {
        type: Date,
        required: function () {
            return this.requestType === 'scheduled';
        },
        validate: {
            validator: function (v) {
                if (this.requestType === 'scheduled') {
                    return v > Date.now();
                }
                return true; // No validation for instant requests
            },
            message: 'Scheduled time must be in the future'
        }
    },
    status: {
        type: String,
        enum: ['Pending', 'Accepted', 'In Progress', 'Completed'],
        default: 'Pending'
    },
    collectorId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    collectorLocation: {
        type: {
            type: String,
            enum: ['Point'],
            default: 'Point'
        },
        coordinates: {
            type: [Number],
            default: [0, 0], // or just leave empty but not required
            validate: {
                validator: function (v) {
                    return v.length === 2 &&
                        v[0] >= -180 && v[0] <= 180 &&
                        v[1] >= -90 && v[1] <= 90;
                },
                message: 'Invalid collector coordinates format [longitude, latitude]'
            }
        }
    },

    requestType: {
        type: String,
        enum: ['instant', 'scheduled'],
        required: true
    }
}, {
    timestamps: true
});

// Geospatial index for proximity searches
pickupRequestSchema.index({ location: '2dsphere' });

// Index for common query patterns
pickupRequestSchema.index({ status: 1, scheduledTime: 1 });

module.exports = mongoose.model('PickupRequest', pickupRequestSchema);
