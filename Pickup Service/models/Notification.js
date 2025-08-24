const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
    collectorId: { type: mongoose.Schema.Types.ObjectId, ref: 'Collector', index: true, required: true },
    title: { type: String, required: true },
    body: { type: String, required: true },
    data: { type: Object, default: {} },
    type: { type: String, default: 'GENERAL' }, // e.g. INSTANT_PICKUP
    read: { type: Boolean, default: false },
}, { timestamps: true });

NotificationSchema.index({ collectorId: 1, createdAt: -1 });
module.exports = mongoose.model('Notification', NotificationSchema);
