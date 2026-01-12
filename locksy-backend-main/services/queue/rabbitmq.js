/*
 * RabbitMQ Connection Manager
 * Handles RabbitMQ connection, channel creation, and queue declarations
 */

const amqp = require('amqplib');
const config = require('../../config');

// Shared queue configuration to keep arguments consistent everywhere
const QUEUE_CONFIGS = {
  notification_queue: {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': '',
      'x-dead-letter-routing-key': 'notification_queue_dlq',
    },
  },
  notification_queue_dlq: {
    durable: true,
  },
  email_queue: {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': '',
      'x-dead-letter-routing-key': 'email_queue_dlq',
    },
  },
  email_queue_dlq: {
    durable: true,
  },
  video_processing_queue: {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': '',
      'x-dead-letter-routing-key': 'video_processing_queue_dlq',
    },
  },
  video_processing_queue_dlq: {
    durable: true,
  },
  analytics_queue: {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': '',
      'x-dead-letter-routing-key': 'analytics_queue_dlq',
    },
  },
  analytics_queue_dlq: {
    durable: true,
  },
  feed_generation_queue: {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': '',
      'x-dead-letter-routing-key': 'feed_generation_queue_dlq',
    },
  },
  feed_generation_queue_dlq: {
    durable: true,
  },
};

let connection = null;
let channel = null;
const channels = {}; // Store multiple channels for different queues

/**
 * Connect to RabbitMQ
 */
async function connect() {
  if (connection) {
    return connection;
  }

  try {
    const rabbitmqConfig = config.queue.rabbitmq;
    const url = rabbitmqConfig.url || `amqp://${rabbitmqConfig.user}:${rabbitmqConfig.password}@localhost:5672`;
    
    console.log('RabbitMQ: Connecting...');
    connection = await amqp.connect(url);
    
    connection.on('error', (err) => {
      console.error('RabbitMQ: Connection error', err.message);
      connection = null;
      channel = null;
    });

    connection.on('close', () => {
      console.log('RabbitMQ: Connection closed');
      connection = null;
      channel = null;
      // Attempt to reconnect after 5 seconds
      setTimeout(connect, 5000);
    });

    console.log('RabbitMQ: Connected');
    return connection;
  } catch (error) {
    console.error('RabbitMQ: Connection failed', error.message);
    connection = null;
    return null;
  }
}

/**
 * Get or create channel
 */
async function getChannel() {
  if (channel && !channel.connection.destroyed) {
    return channel;
  }

  try {
    const conn = await connect();
    if (!conn) {
      return null;
    }

    channel = await conn.createChannel();
    console.log('RabbitMQ: Channel created');
    return channel;
  } catch (error) {
    console.error('RabbitMQ: Channel creation failed', error.message);
    return null;
  }
}

/**
 * Get or create a named channel for a specific queue
 */
async function getQueueChannel(queueName) {
  if (channels[queueName] && !channels[queueName].connection.destroyed) {
    return channels[queueName];
  }

  try {
    const conn = await connect();
    if (!conn) {
      return null;
    }

    const ch = await conn.createChannel();
    channels[queueName] = ch;
    console.log(`RabbitMQ: Channel created for queue ${queueName}`);
    return ch;
  } catch (error) {
    console.error(`RabbitMQ: Channel creation failed for ${queueName}`, error.message);
    return null;
  }
}

/**
 * Assert queue exists (create if it doesn't)
 */
async function assertQueue(queueName, options = {}) {
  try {
    const ch = await getQueueChannel(queueName);
    if (!ch) {
      return false;
    }

    const normalizedOptions = {
      durable: true, // Queue survives broker restart
      ...(QUEUE_CONFIGS[queueName] || {}),
      ...options,
    };

    await ch.assertQueue(queueName, normalizedOptions);
    console.log(`RabbitMQ: Queue ${queueName} asserted`);
    return true;
  } catch (error) {
    // If queue exists with different arguments, try to delete and recreate
    if (error.message && error.message.includes('PRECONDITION_FAILED')) {
      try {
        console.log(`RabbitMQ: Queue ${queueName} exists with different config, deleting and recreating...`);
        const conn = await connect();
        if (!conn) {
          return false;
        }
        
        // Get a fresh channel for deletion
        const deleteCh = await conn.createChannel();
        try {
          await deleteCh.deleteQueue(queueName, { ifEmpty: false });
          console.log(`RabbitMQ: Queue ${queueName} deleted`);
        } catch (deleteErr) {
          // Queue might not exist, that's OK
          if (!deleteErr.message.includes('NOT_FOUND')) {
            console.warn(`RabbitMQ: Error deleting queue ${queueName}:`, deleteErr.message);
          }
        } finally {
          await deleteCh.close();
        }
        
        // Now recreate with correct config
        const recreateCh = await getQueueChannel(queueName);
        if (recreateCh) {
          await recreateCh.assertQueue(queueName, normalizedOptions);
          console.log(`RabbitMQ: Queue ${queueName} recreated with correct configuration`);
          return true;
        }
      } catch (deleteError) {
        console.error(`RabbitMQ: Failed to recreate queue ${queueName}`, deleteError.message);
        return false;
      }
    }
    console.error(`RabbitMQ: Failed to assert queue ${queueName}`, error.message);
    return false;
  }
}

/**
 * Initialize all queues
 */
async function initializeQueues() {
  for (const [queueName, config] of Object.entries(QUEUE_CONFIGS)) {
    await assertQueue(queueName, config);
  }

  console.log('RabbitMQ: All queues initialized');
}

/**
 * Check if RabbitMQ is connected
 */
function isConnected() {
  return connection && !connection.connection.destroyed;
}

/**
 * Close connection
 */
async function close() {
  if (channel) {
    await channel.close();
    channel = null;
  }

  for (const queueName in channels) {
    try {
      await channels[queueName].close();
    } catch (error) {
      console.error(`RabbitMQ: Error closing channel for ${queueName}`, error.message);
    }
    delete channels[queueName];
  }

  if (connection) {
    await connection.close();
    connection = null;
  }

  console.log('RabbitMQ: Connection closed');
}

module.exports = {
  connect,
  getChannel,
  getQueueChannel,
  assertQueue,
  initializeQueues,
  isConnected,
  close,
};

