/*
 * Video Processing Queue Consumer
 * Consumes video processing tasks from RabbitMQ
 */

const { getQueueChannel, assertQueue } = require('../queue/rabbitmq');
const videoProcessor = require('./processor');

class VideoProcessingConsumer {
  constructor() {
    this.isConsuming = false;
    this.processedCount = 0;
    this.failedCount = 0;
  }

  /**
   * Start consuming video processing tasks
   */
  async start() {
    if (this.isConsuming) {
      console.log('VideoProcessingConsumer: Already consuming');
      return;
    }

    try {
      const queueName = 'video_processing_queue';
      
      // Ensure queue exists
      await assertQueue(queueName, {
        durable: true,
        arguments: {
          'x-dead-letter-exchange': '',
          'x-dead-letter-routing-key': 'video_processing_queue_dlq'
        }
      });

      // Get channel
      const channel = await getQueueChannel(queueName);
      if (!channel) {
        throw new Error('Could not get queue channel');
      }

      // Set prefetch to process one video at a time (videos are CPU-intensive)
      channel.prefetch(1);

      console.log(`VideoProcessingConsumer: Starting consumer for ${queueName}`);

      // Consume messages
      channel.consume(queueName, async (msg) => {
        if (!msg) {
          return;
        }

        try {
          const task = JSON.parse(msg.content.toString());
          console.log(`VideoProcessingConsumer: Processing video:`, task.data?.fileName || task.data?.fileId);

          // Process video
          await this.processVideo(task.data);

          // Acknowledge message
          channel.ack(msg);
          this.processedCount++;
          
          console.log(`VideoProcessingConsumer: Video processed successfully (Total: ${this.processedCount})`);
        } catch (error) {
          console.error('VideoProcessingConsumer: Error processing video:', error.message);
          this.failedCount++;

          // Reject message and requeue (up to retry limit)
          const retryCount = (msg.properties.headers?.['x-retry-count'] || 0) + 1;
          if (retryCount < 3) {
            // Update retry count in headers
            msg.properties.headers = msg.properties.headers || {};
            msg.properties.headers['x-retry-count'] = retryCount;
            channel.nack(msg, false, true); // Requeue
            console.log(`VideoProcessingConsumer: Requeuing video (retry ${retryCount}/3)`);
          } else {
            // Send to DLQ after max retries
            channel.nack(msg, false, false);
            console.error('VideoProcessingConsumer: Video failed after max retries, sending to DLQ');
          }
        }
      }, {
        noAck: false
      });

      this.isConsuming = true;
      console.log('VideoProcessingConsumer: Consumer started successfully');
    } catch (error) {
      console.error('VideoProcessingConsumer: Failed to start consumer:', error.message);
      throw error;
    }
  }

  /**
   * Stop consuming
   */
  stop() {
    this.isConsuming = false;
    console.log('VideoProcessingConsumer: Stopped consuming');
  }

  /**
   * Process video
   * @param {Object} videoData - Video data
   */
  async processVideo(videoData) {
    try {
      const { fileId, originalPath, fileName, mimeType, size, uploadedBy } = videoData;

      if (!fileId && !originalPath) {
        throw new Error('File ID or original path is required');
      }

      // Process video using video processor
      // Generate video ID if not provided
      const videoId = fileId || require('crypto').randomBytes(16).toString('hex');
      
      const result = await videoProcessor.processVideo(
        originalPath || fileId,
        videoId,
        {
          resolutions: ['720p', '1080p']
        }
      );

      console.log(`VideoProcessingConsumer: Video processed:`, {
        fileId,
        fileName,
        resolutions: result.resolutions?.length || 0,
        thumbnail: result.thumbnail ? 'generated' : 'none'
      });

      return result;
    } catch (error) {
      console.error('VideoProcessingConsumer: Video processing error:', error.message);
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
const videoProcessingConsumer = new VideoProcessingConsumer();
module.exports = videoProcessingConsumer;

