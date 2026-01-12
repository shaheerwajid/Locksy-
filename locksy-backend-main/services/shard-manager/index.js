/*
 * Shard Manager Service
 * Manages data distribution across shards
 * Routes requests to correct shard
 * Monitors shard health
 */

const express = require('express');
const bodyParser = require('body-parser');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const helmet = require('helmet');

// Initialize database connection
require('../../database/config').dbConnection();

// Initialize Redis cache
try {
  const { initializeRedis } = require('../cache/redisClient');
  initializeRedis();
  console.log('Shard Manager: Redis initialized');
} catch (error) {
  console.warn('Shard Manager: Redis initialization failed:', error.message);
}

// Initialize RabbitMQ for feed generation queue
try {
  const { initializeQueues } = require('../queue/rabbitmq');
  initializeQueues().then(() => {
    console.log('Shard Manager: Queues initialized');
  }).catch(err => {
    console.warn('Shard Manager: Queue initialization failed:', err.message);
  });
} catch (error) {
  console.warn('Shard Manager: Queue initialization failed:', error.message);
}

const app = express();
const PORT = process.env.SHARD_MANAGER_PORT || 3006;

// Middleware
app.use(compression());
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));
app.use(cookieParser());

// Request logging middleware
app.use((req, res, next) => {
  const requestId = require('uuid').v4();
  req.requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} [${requestId}]`);
  next();
});

// Health check endpoints
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'shard-manager',
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

app.get('/health/ready', async (req, res) => {
  try {
    const mongoose = require('mongoose');
    const { isConnected } = require('../cache/redisClient');
    
    const dbStatus = mongoose.connection.readyState === 1;
    const redisStatus = isConnected();
    
    if (dbStatus && redisStatus) {
      res.json({
        ok: true,
        status: 'ready',
        checks: {
          database: 'connected',
          cache: 'connected'
        }
      });
    } else {
      res.status(503).json({
        ok: false,
        status: 'not ready',
        checks: {
          database: dbStatus ? 'connected' : 'disconnected',
          cache: redisStatus ? 'connected' : 'disconnected'
        }
      });
    }
  } catch (error) {
    res.status(503).json({
      ok: false,
      status: 'not ready',
      error: error.message
    });
  }
});

// Routes
app.use('/api', require('./routes'));

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(`[${req.requestId}] Error:`, err);
  res.status(err.status || 500).json({
    ok: false,
    msg: err.message || 'Internal server error',
    requestId: req.requestId,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// Start feed generation consumer
if (process.env.ENABLE_FEED_GENERATION !== 'false') {
  try {
    const { startFeedGenerationConsumer } = require('./feedProcessor');
    startFeedGenerationConsumer().then(() => {
      console.log('Shard Manager: Feed generation consumer started');
    }).catch(err => {
      console.error('Shard Manager: Failed to start feed generation consumer:', err.message);
    });
  } catch (error) {
    console.warn('Shard Manager: Feed generation not available:', error.message);
  }
}

// Start server
app.listen(PORT, () => {
  console.log(`Shard Manager running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;


