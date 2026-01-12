/*
 * Redis Connection Pool
 * Manages Redis connection with connection pooling and error handling
 */

const Redis = require('ioredis');
const config = require('../../config');

let redisClient = null;

/**
 * Initialize Redis client with connection pooling
 */
function initializeRedis() {
  if (redisClient) {
    return redisClient;
  }

  try {
    const redisConfig = {
      host: config.redis.host,
      port: config.redis.port,
      password: config.redis.password,
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
      maxRetriesPerRequest: 3,
      enableReadyCheck: true,
      enableOfflineQueue: false,
      lazyConnect: true,
      // Connection pool settings
      family: 4, // Use IPv4
      keepAlive: 30000,
    };

    // Use URL if provided, otherwise use host/port
    if (config.redis.url) {
      redisClient = new Redis(config.redis.url, redisConfig);
    } else {
      redisClient = new Redis(redisConfig);
    }

    // Event handlers
    redisClient.on('connect', () => {
      console.log('Redis: Connecting...');
    });

    redisClient.on('ready', () => {
      console.log('Redis: Ready');
    });

    redisClient.on('error', (err) => {
      console.error('Redis: Connection error', err.message);
    });

    redisClient.on('close', () => {
      console.log('Redis: Connection closed');
    });

    redisClient.on('reconnecting', (delay) => {
      console.log(`Redis: Reconnecting in ${delay}ms...`);
    });

    // Connect to Redis
    redisClient.connect().catch((err) => {
      console.warn('Redis: Initial connection failed, will retry:', err.message);
    });

    return redisClient;
  } catch (error) {
    console.error('Redis: Failed to initialize', error);
    return null;
  }
}

/**
 * Get Redis client instance
 */
function getRedisClient() {
  if (!redisClient) {
    return initializeRedis();
  }
  return redisClient;
}

/**
 * Check if Redis is connected
 */
function isConnected() {
  return redisClient && redisClient.status === 'ready';
}

/**
 * Close Redis connection
 */
async function closeRedis() {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
}

module.exports = {
  initializeRedis,
  getRedisClient,
  isConnected,
  closeRedis,
};

