/*
 * Data Warehouse Service
 * Main service for data warehouse operations
 */

// CRITICAL: Set SKIP_MAIN_SERVER BEFORE requiring database config
// This prevents main index.js from executing when database config is required
process.env.SKIP_MAIN_SERVER = process.env.SKIP_MAIN_SERVER || 'true';

const express = require('express');
const bodyParser = require('body-parser');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const helmet = require('helmet');

// Initialize database connection (async - don't block)
const mongoose = require('mongoose');
async function initializeDatabase() {
  try {
    if (mongoose.connection.readyState === 0) {
      await require('../../database/config').dbConnection();
    }
  } catch (error) {
    console.error('Data Warehouse: Database initialization error:', error.message);
    // Don't throw - continue without database
  }
}
initializeDatabase().catch(err => console.error('Data Warehouse: Database init failed:', err));

// Initialize Redis cache
try {
  const { initializeRedis } = require('../cache/redisClient');
  initializeRedis();
  console.log('Data Warehouse: Redis initialized');
} catch (error) {
  console.warn('Data Warehouse: Redis initialization failed:', error.message);
}

// Initialize RabbitMQ
try {
  const { initializeQueues } = require('../queue/rabbitmq');
  initializeQueues().then(() => {
    console.log('Data Warehouse: Queues initialized');
  }).catch(err => {
    console.warn('Data Warehouse: Queue initialization failed:', err.message);
  });
} catch (error) {
  console.warn('Data Warehouse: Queue initialization failed:', error.message);
}

const app = express();
const PORT = process.env.WAREHOUSE_PORT || 3009;

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
    service: 'data-warehouse',
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

// Start scheduler
if (process.env.ENABLE_SCHEDULER !== 'false') {
  try {
    const scheduler = require('./scheduler');
    scheduler.start();
    console.log('Data Warehouse: Scheduler started');
  } catch (error) {
    console.warn('Data Warehouse: Scheduler not available:', error.message);
  }
}

// Start server
app.listen(PORT, () => {
  console.log(`Data Warehouse running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;


