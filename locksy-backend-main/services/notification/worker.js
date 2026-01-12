/*
 * Notification Worker Service
 * Starts the notification consumer to process queued notifications
 */

const NotificationConsumer = require('./consumer');

let notificationConsumer = null;

/**
 * Start notification worker
 */
function startNotificationWorker() {
  if (notificationConsumer) {
    console.log('Notification Worker: Already running');
    return;
  }

  try {
    notificationConsumer = new NotificationConsumer();
    notificationConsumer.start();
    console.log('Notification Worker: Started');
  } catch (error) {
    console.error('Notification Worker: Failed to start', error.message);
  }
}

/**
 * Stop notification worker
 */
async function stopNotificationWorker() {
  if (notificationConsumer) {
    await notificationConsumer.stop();
    notificationConsumer = null;
    console.log('Notification Worker: Stopped');
  }
}

module.exports = {
  startNotificationWorker,
  stopNotificationWorker,
};

