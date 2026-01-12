/*
 * Email Producer
 * Queues emails for async sending
 */

const producer = require('../queue/producer');

/**
 * Queue email for sending
 */
async function queueEmail(emailData) {
  const {
    to,
    subject,
    html,
    text,
    from,
    attachments = [],
    priority = 'normal',
  } = emailData;

  return await producer.sendEmail({
    to,
    subject,
    html,
    text,
    from,
    attachments,
    priority,
  });
}

module.exports = {
  queueEmail,
};

