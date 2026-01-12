/*
 * Notification Producer
 * Queues push notifications for async processing
 */

const producer = require('../queue/producer');

/**
 * Queue notification for sending
 */
async function queueNotification(notificationData) {
  const {
    userId,
    title,
    body,
    data = {},
    priority = 'normal',
    ttl = 3600, // 1 hour default TTL
  } = notificationData;

  return await producer.sendNotification({
    userId,
    title,
    body,
    data,
    priority,
    ttl,
  });
}

module.exports = {
  queueNotification,
};

