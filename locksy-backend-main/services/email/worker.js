/*
 * Email Worker Service
 * Starts the email consumer to process queued emails
 */

const EmailConsumer = require('./consumer');

let emailConsumer = null;

/**
 * Start email worker
 */
function startEmailWorker() {
  if (emailConsumer) {
    console.log('Email Worker: Already running');
    return;
  }

  try {
    emailConsumer = new EmailConsumer();
    emailConsumer.start();
    console.log('Email Worker: Started');
  } catch (error) {
    console.error('Email Worker: Failed to start', error.message);
  }
}

/**
 * Stop email worker
 */
async function stopEmailWorker() {
  if (emailConsumer) {
    await emailConsumer.stop();
    emailConsumer = null;
    console.log('Email Worker: Stopped');
  }
}

module.exports = {
  startEmailWorker,
  stopEmailWorker,
};

