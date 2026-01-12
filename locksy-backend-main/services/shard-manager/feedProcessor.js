/*
 * Feed Generation Processor
 * Consumes from Feed Generation Queue and distributes tasks across shards
 */

const { getQueueChannel, assertQueue } = require('../queue/rabbitmq');
const shardRouter = require('./shardRouter');
const cacheService = require('../cache/cacheService');
const feedAggregator = require('../feed/aggregator');
const mongoose = require('mongoose');

/**
 * Start feed generation consumer
 */
async function startFeedGenerationConsumer() {
  try {
    const queueName = 'feed_generation_queue';
    
    // Ensure queue exists
    await assertQueue(queueName, { durable: true });

    // Get channel
    const channel = await getQueueChannel(queueName);
    if (!channel) {
      throw new Error('Could not get queue channel');
    }

    // Set prefetch to process one message at a time
    channel.prefetch(1);

    console.log(`FeedProcessor: Starting consumer for ${queueName}`);

    // Consume messages
    channel.consume(queueName, async (msg) => {
      if (!msg) {
        return;
      }

      try {
        const task = JSON.parse(msg.content.toString());
        console.log(`FeedProcessor: Processing feed generation task:`, task.type);

        // Process feed generation task
        await processFeedGenerationTask(task);

        // Acknowledge message
        channel.ack(msg);
      } catch (error) {
        console.error('FeedProcessor: Error processing task:', error.message);
        
        // Reject message and requeue (up to retry limit)
        const retryCount = (msg.properties.headers?.['x-retry-count'] || 0) + 1;
        if (retryCount < 3) {
          channel.nack(msg, false, true); // Requeue
        } else {
          // Send to DLQ after max retries
          channel.nack(msg, false, false);
          console.error('FeedProcessor: Task failed after max retries, sending to DLQ');
        }
      }
    }, {
      noAck: false
    });

    console.log('FeedProcessor: Consumer started successfully');
  } catch (error) {
    console.error('FeedProcessor: Failed to start consumer:', error.message);
    throw error;
  }
}

/**
 * Process feed generation task
 * @param {Object} task - Feed generation task
 */
async function processFeedGenerationTask(task) {
  try {
    const { type, userId, data } = task;

    switch (type) {
      case 'user_feed':
        await generateUserFeed(userId, data);
        break;
      case 'group_feed':
        await generateGroupFeed(data.groupId, data);
        break;
      case 'activity_feed':
        await generateActivityFeed(userId, data);
        break;
      default:
        console.warn(`FeedProcessor: Unknown task type: ${type}`);
    }
  } catch (error) {
    console.error('FeedProcessor: Error processing feed task:', error.message);
    throw error;
  }
}

/**
 * Generate user feed
 * @param {string} userId - User ID
 * @param {Object} options - Generation options
 */
async function generateUserFeed(userId, options = {}) {
  try {
    // Use feed aggregator to generate and cache feed
    const feed = await feedAggregator.aggregateUserFeed(userId, options);
    console.log(`FeedProcessor: Generated feed for user ${userId}`);
    return feed;
  } catch (error) {
    console.error('FeedProcessor: Error generating user feed:', error.message);
    throw error;
  }
}

/**
 * Generate group feed
 * @param {string} groupId - Group ID
 * @param {Object} options - Generation options
 */
async function generateGroupFeed(groupId, options = {}) {
  try {
    // Use feed aggregator to generate and cache feed
    const feed = await feedAggregator.aggregateGroupFeed(groupId, options);
    console.log(`FeedProcessor: Generated feed for group ${groupId}`);
    return feed;
  } catch (error) {
    console.error('FeedProcessor: Error generating group feed:', error.message);
    throw error;
  }
}

/**
 * Generate activity feed
 * @param {string} userId - User ID
 * @param {Object} options - Generation options
 */
async function generateActivityFeed(userId, options = {}) {
  try {
    // Use feed aggregator to generate and cache activity feed
    const feed = await feedAggregator.aggregateActivityFeed(userId, options);
    console.log(`FeedProcessor: Generated activity feed for user ${userId}`);
    return feed;
  } catch (error) {
    console.error('FeedProcessor: Error generating activity feed:', error.message);
    throw error;
  }
}

module.exports = {
  startFeedGenerationConsumer,
  processFeedGenerationTask
};

