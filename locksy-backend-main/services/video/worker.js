/*
 * Video Processing Worker
 * Worker instance for processing videos from queue
 */

const videoProcessingConsumer = require('./consumer');

// Initialize database connection
require('../../database/config').dbConnection();

// Initialize Redis cache
try {
  const { initializeRedis } = require('../cache/redisClient');
  initializeRedis();
  console.log('Video Worker: Redis initialized');
} catch (error) {
  console.warn('Video Worker: Redis initialization failed:', error.message);
}

// Initialize storage
try {
  const { initializeStorage } = require('../storage/storageClient');
  initializeStorage();
  console.log('Video Worker: Storage initialized');
} catch (error) {
  console.warn('Video Worker: Storage initialization failed:', error.message);
}

// Initialize RabbitMQ
try {
  const { initializeQueues } = require('../queue/rabbitmq');
  initializeQueues().then(() => {
    console.log('Video Worker: Queues initialized');
  }).catch(err => {
    console.warn('Video Worker: Queue initialization failed:', err.message);
  });
} catch (error) {
  console.warn('Video Worker: Queue initialization failed:', error.message);
}

// Start consumer
const workerId = process.env.WORKER_ID || `worker-${process.pid}`;
console.log(`Video Worker ${workerId}: Starting...`);

videoProcessingConsumer.start().then(() => {
  console.log(`Video Worker ${workerId}: Started successfully`);
}).catch((error) => {
  console.error(`Video Worker ${workerId}: Failed to start:`, error.message);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log(`Video Worker ${workerId}: Received SIGTERM, shutting down...`);
  videoProcessingConsumer.stop();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log(`Video Worker ${workerId}: Received SIGINT, shutting down...`);
  videoProcessingConsumer.stop();
  process.exit(0);
});

// Health check endpoint (optional, for monitoring)
const express = require('express');
const healthApp = express();
const healthPort = parseInt(process.env.HEALTH_PORT || '3007');

healthApp.get('/health', (req, res) => {
  const stats = videoProcessingConsumer.getStats();
  res.json({
    ok: true,
    workerId,
    service: 'video-worker',
    status: stats.isConsuming ? 'running' : 'stopped',
    stats
  });
});

healthApp.listen(healthPort, () => {
  console.log(`Video Worker ${workerId}: Health check on port ${healthPort}`);
});

module.exports = videoProcessingConsumer;


