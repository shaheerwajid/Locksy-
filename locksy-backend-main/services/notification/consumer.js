/*
 * Notification Consumer
 * Processes queued notifications and sends via FCM
 */

const MessageConsumer = require('../queue/consumer');
const admin = require('firebase-admin');

class NotificationConsumer extends MessageConsumer {
  constructor() {
    super('notification_queue', {
      prefetch: 10, // Process up to 10 notifications at a time
      maxRetries: 3,
    });
  }

  /**
   * Process notification message
   */
  async processMessage(message, handler) {
    try {
      const { data } = message;
      const { userId, title, body, data: notificationData, priority, ttl } = data;

      // Get user's FCM token from database
      const Usuario = require('../../models/usuario');
      const user = await Usuario.findById(userId);

      if (!user || !user.firebaseid) {
        console.warn(`Notification: User ${userId} not found or no FCM token`);
        return true; // Acknowledge to remove from queue
      }

      // Prepare FCM message
      const fcmMessage = {
        token: user.firebaseid,
        notification: {
          title,
          body,
        },
        data: notificationData,
        android: {
          priority: priority === 'high' ? 'high' : 'normal',
          ttl: ttl * 1000, // Convert to milliseconds
        },
        apns: {
          headers: {
            'apns-priority': priority === 'high' ? '10' : '5',
          },
        },
      };

      // Send notification
      try {
        const response = await admin.messaging().send(fcmMessage);
        console.log(`Notification: Successfully sent to user ${userId}: ${response}`);
        return true;
      } catch (fcmError) {
        console.error(`Notification: FCM error for user ${userId}:`, fcmError.message);
        
        // If token is invalid, remove it from user
        if (fcmError.code === 'messaging/invalid-registration-token' || 
            fcmError.code === 'messaging/registration-token-not-registered') {
          await Usuario.findByIdAndUpdate(userId, { $unset: { firebaseid: 1 } });
          console.log(`Notification: Removed invalid FCM token for user ${userId}`);
        }
        
        // Retry for other errors
        return false;
      }
    } catch (error) {
      console.error('Notification: Error processing notification', error);
      return false;
    }
  }
}

module.exports = NotificationConsumer;

