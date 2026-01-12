/*
 * Message Producer
 * Sends messages to RabbitMQ queues
 */

const { getQueueChannel, isConnected } = require('./rabbitmq');

class MessageProducer {
  /**
   * Send message to queue
   */
  async sendToQueue(queueName, message, options = {}) {
    if (!isConnected()) {
      console.warn(`RabbitMQ: Not connected, message to ${queueName} will be lost`);
      return false;
    }

    try {
      // Don't assert queue here - it should already be created by initializeQueues()
      // Just try to send. If queue doesn't exist, it will fail gracefully.
      // This avoids PRECONDITION_FAILED errors from trying to recreate queues with different configs

      // Get channel for this queue
      const channel = await getQueueChannel(queueName);
      if (!channel) {
        return false;
      }

      // Serialize message
      const messageBuffer = Buffer.from(JSON.stringify(message));

      // Default options
      const publishOptions = {
        persistent: true, // Message survives broker restart
        ...options
      };

      // Send message
      const sent = channel.sendToQueue(queueName, messageBuffer, publishOptions);
      
      if (sent) {
        console.log(`RabbitMQ: Message sent to ${queueName}`);
        return true;
      } else {
        console.warn(`RabbitMQ: Message buffer full for ${queueName}`);
        return false;
      }
    } catch (error) {
      console.error(`RabbitMQ: Error sending message to ${queueName}`, error.message);
      return false;
    }
  }

  /**
   * Send notification message
   */
  async sendNotification(notificationData) {
    return this.sendToQueue('notification_queue', {
      type: 'notification',
      data: notificationData,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Send video processing task
   */
  async sendVideoProcessing(videoData) {
    return this.sendToQueue('video_processing_queue', {
      type: 'video_processing',
      data: videoData,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Send email message
   */
  async sendEmail(emailData) {
    return this.sendToQueue('email_queue', {
      type: 'email',
      data: emailData,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Send analytics event
   */
  async sendAnalytics(analyticsData) {
    return this.sendToQueue('analytics_queue', {
      type: 'analytics',
      data: analyticsData,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Send to dead letter queue
   */
  async sendToDLQ(queueName, message, error) {
    const dlqName = `${queueName}_dlq`;
    return this.sendToQueue(dlqName, {
      originalQueue: queueName,
      originalMessage: message,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
}

// Export singleton instance
const producer = new MessageProducer();
module.exports = producer;

