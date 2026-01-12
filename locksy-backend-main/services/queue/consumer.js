/*
 * Message Consumer
 * Base class for consuming messages from RabbitMQ queues
 */

const { getQueueChannel, isConnected } = require('./rabbitmq');
const producer = require('./producer');

class MessageConsumer {
  constructor(queueName, options = {}) {
    this.queueName = queueName;
    this.options = {
      prefetch: 1, // Process one message at a time
      ...options
    };
    this.consumerTag = null;
    this.isConsuming = false;
  }

  /**
   * Start consuming messages
   */
  async start(handler) {
    if (this.isConsuming) {
      console.log(`Consumer: Already consuming from ${this.queueName}`);
      return;
    }

    if (!isConnected()) {
      console.warn(`Consumer: RabbitMQ not connected, cannot consume from ${this.queueName}`);
      return;
    }

    try {
      // Don't assert queue here - it should already be created by initializeQueues()
      // Just try to get the channel and consume. If queue doesn't exist, it will fail gracefully.
      // This avoids PRECONDITION_FAILED errors from trying to recreate queues with different configs

      // Wait a bit for queues to be fully initialized
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Get channel
      const channel = await getQueueChannel(this.queueName);
      if (!channel) {
        console.warn(`Consumer: Could not get channel for ${this.queueName}`);
        return;
      }

      // Set prefetch
      await channel.prefetch(this.options.prefetch);

      // Start consuming (this will fail if queue doesn't exist, which is OK)
      const result = await channel.consume(
        this.queueName,
        async (message) => {
          if (!message) {
            return;
          }

          try {
            // Parse message
            const content = JSON.parse(message.content.toString());
            
            // Process message
            const success = await this.processMessage(content, handler);

            if (success) {
              // Acknowledge message
              channel.ack(message);
            } else {
              // Reject and requeue
              channel.nack(message, false, true);
            }
          } catch (error) {
            console.error(`Consumer: Error processing message from ${this.queueName}`, error);
            
            // Parse original message if possible
            let originalMessage = null;
            try {
              originalMessage = JSON.parse(message.content.toString());
            } catch (e) {
              // Ignore parse errors
            }

            // Send to dead letter queue after max retries
            const retryCount = message.properties.headers?.['x-retry-count'] || 0;
            const maxRetries = this.options.maxRetries || 3;

            if (retryCount >= maxRetries) {
              // Send to DLQ
              await producer.sendToDLQ(this.queueName, originalMessage, error);
              channel.ack(message); // Remove from queue
            } else {
              // Retry with incremented count
              const headers = message.properties.headers || {};
              headers['x-retry-count'] = retryCount + 1;
              channel.nack(message, false, true);
            }
          }
        },
        {
          noAck: false, // Manual acknowledgment
        }
      );

      this.consumerTag = result.consumerTag;
      this.isConsuming = true;
      console.log(`Consumer: Started consuming from ${this.queueName} (tag: ${this.consumerTag})`);
    } catch (error) {
      console.error(`Consumer: Failed to start consuming from ${this.queueName}`, error.message);
      this.isConsuming = false;
    }
  }

  /**
   * Process message (to be overridden by subclasses)
   */
  async processMessage(message, handler) {
    if (handler && typeof handler === 'function') {
      return await handler(message);
    }
    return false;
  }

  /**
   * Stop consuming
   */
  async stop() {
    if (!this.isConsuming || !this.consumerTag) {
      return;
    }

    try {
      const channel = await getQueueChannel(this.queueName);
      if (channel) {
        await channel.cancel(this.consumerTag);
        this.consumerTag = null;
        this.isConsuming = false;
        console.log(`Consumer: Stopped consuming from ${this.queueName}`);
      }
    } catch (error) {
      console.error(`Consumer: Error stopping consumer for ${this.queueName}`, error.message);
    }
  }
}

module.exports = MessageConsumer;

