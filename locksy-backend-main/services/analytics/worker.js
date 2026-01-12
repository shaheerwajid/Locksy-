/*
 * Analytics Worker
 * Worker instance for processing analytics events from queue
 */

const analyticsConsumer = require('./consumer');

// Initialize database connection
require('../../database/config').dbConnection();

// Initialize Redis cache
try {
  const { initializeRedis } = require('../cache/redisClient');
  initializeRedis();
  console.log('Analytics Worker: Redis initialized');
} catch (error) {
  console.warn('Analytics Worker: Redis initialization failed:', error.message);
}

// Initialize RabbitMQ
try {
  const { initializeQueues } = require('../queue/rabbitmq');
  initializeQueues().then(() => {
    console.log('Analytics Worker: Queues initialized');
  }).catch(err => {
    console.warn('Analytics Worker: Queue initialization failed:', err.message);
  });
} catch (error) {
  console.warn('Analytics Worker: Queue initialization failed:', error.message);
}

// Start consumer
const workerId = process.env.WORKER_ID || `analytics-worker-${process.pid}`;
console.log(`Analytics Worker ${workerId}: Starting...`);

analyticsConsumer.start().then(() => {
  console.log(`Analytics Worker ${workerId}: Started successfully`);
}).catch((error) => {
  console.error(`Analytics Worker ${workerId}: Failed to start:`, error.message);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log(`Analytics Worker ${workerId}: Received SIGTERM, shutting down...`);
  analyticsConsumer.stop();
  
  // Flush remaining events
  try {
    const analyticsProcessor = require('./processor');
    await analyticsProcessor.flush();
  } catch (error) {
    console.error('Analytics Worker: Error flushing events:', error.message);
  }
  
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log(`Analytics Worker ${workerId}: Received SIGINT, shutting down...`);
  analyticsConsumer.stop();
  
  // Flush remaining events
  try {
    const analyticsProcessor = require('./processor');
    await analyticsProcessor.flush();
  } catch (error) {
    console.error('Analytics Worker: Error flushing events:', error.message);
  }
  
  process.exit(0);
});

// Health check endpoint (optional, for monitoring)
const express = require('express');
const healthApp = express();
const healthPort = parseInt(process.env.HEALTH_PORT || '3008');

healthApp.get('/health', (req, res) => {
  const stats = analyticsConsumer.getStats();
  res.json({
    ok: true,
    workerId,
    service: 'analytics-worker',
    status: stats.isConsuming ? 'running' : 'stopped',
    stats
  });
});

healthApp.listen(healthPort, () => {
  console.log(`Analytics Worker ${workerId}: Health check on port ${healthPort}`);
});

module.exports = analyticsConsumer;


