/*
 * Analytics Queue Consumer
 * Consumes analytics events from RabbitMQ
 */

const { getQueueChannel, assertQueue } = require('../queue/rabbitmq');
const analyticsProcessor = require('./processor');

class AnalyticsConsumer {
  constructor() {
    this.isConsuming = false;
    this.processedCount = 0;
    this.failedCount = 0;
  }

  /**
   * Start consuming analytics events
   */
  async start() {
    if (this.isConsuming) {
      console.log('AnalyticsConsumer: Already consuming');
      return;
    }

    try {
      const queueName = 'analytics_queue';
      
      // Ensure queue exists
      await assertQueue(queueName, {
        durable: true,
        arguments: {
          'x-dead-letter-exchange': '',
          'x-dead-letter-routing-key': 'analytics_queue_dlq'
        }
      });

      // Get channel
      const channel = await getQueueChannel(queueName);
      if (!channel) {
        throw new Error('Could not get queue channel');
      }

      // Set prefetch for batch processing
      channel.prefetch(10); // Process up to 10 events at a time

      console.log(`AnalyticsConsumer: Starting consumer for ${queueName}`);

      // Consume messages
      channel.consume(queueName, async (msg) => {
        if (!msg) {
          return;
        }

        try {
          const event = JSON.parse(msg.content.toString());
          console.log(`AnalyticsConsumer: Processing event:`, event.type);

          // Process analytics event
          await this.processEvent(event);

          // Acknowledge message
          channel.ack(msg);
          this.processedCount++;
        } catch (error) {
          console.error('AnalyticsConsumer: Error processing event:', error.message);
          this.failedCount++;

          // Reject message and requeue (up to retry limit)
          const retryCount = (msg.properties.headers?.['x-retry-count'] || 0) + 1;
          if (retryCount < 3) {
            // Update retry count in headers
            msg.properties.headers = msg.properties.headers || {};
            msg.properties.headers['x-retry-count'] = retryCount;
            channel.nack(msg, false, true); // Requeue
            console.log(`AnalyticsConsumer: Requeuing event (retry ${retryCount}/3)`);
          } else {
            // Send to DLQ after max retries
            channel.nack(msg, false, false);
            console.error('AnalyticsConsumer: Event failed after max retries, sending to DLQ');
          }
        }
      }, {
        noAck: false
      });

      this.isConsuming = true;
      console.log('AnalyticsConsumer: Consumer started successfully');
    } catch (error) {
      console.error('AnalyticsConsumer: Failed to start consumer:', error.message);
      throw error;
    }
  }

  /**
   * Stop consuming
   */
  stop() {
    this.isConsuming = false;
    console.log('AnalyticsConsumer: Stopped consuming');
  }

  /**
   * Process analytics event
   * @param {Object} event - Analytics event
   */
  async processEvent(event) {
    try {
      const { type, data, timestamp } = event;

      // Process event using analytics processor
      await analyticsProcessor.processEvent({
        type,
        data,
        timestamp: timestamp || new Date().toISOString()
      });

      return true;
    } catch (error) {
      console.error('AnalyticsConsumer: Event processing error:', error.message);
      throw error;
    }
  }

  /**
   * Get consumer statistics
   * @returns {Object} Statistics
   */
  getStats() {
    return {
      isConsuming: this.isConsuming,
      processedCount: this.processedCount,
      failedCount: this.failedCount
    };
  }
}

// Export singleton instance
const analyticsConsumer = new AnalyticsConsumer();
module.exports = analyticsConsumer;


