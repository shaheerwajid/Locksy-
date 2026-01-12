/*
 * Metadata Server Service
 * Handles Control path requests - metadata CRUD operations
 * Implements cache-aside pattern: Check Redis → DB → Update Cache
 */

const express = require('express');
const bodyParser = require('body-parser');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const helmet = require('helmet');

// CRITICAL: Set SKIP_MAIN_SERVER BEFORE requiring database config
// This prevents main index.js from executing when database config is required
process.env.SKIP_MAIN_SERVER = 'true';

// Initialize database connection
const mongoose = require('mongoose');

// Async function to initialize database and models
async function initializeDatabase() {
  if (mongoose.connection.readyState === 0) {
    await require('../../database/config').dbConnection();
  }
  
  // Wait for connection to be ready
  if (mongoose.connection.readyState === 0 || mongoose.connection.readyState === 2) {
    await new Promise((resolve) => {
      if (mongoose.connection.readyState === 1) {
        resolve();
      } else {
        mongoose.connection.once('connected', resolve);
        mongoose.connection.once('error', resolve); // Continue even on error
      }
    });
  }
  
  // Load models in dependency order after connection is ready
  // Load base models first (no dependencies)
  require('../../models/usuario');
  require('../../models/grupo');
  // Then load models that depend on the above
  require('../../models/grupo_usuario');
  require('../../models/mensaje');
  require('../../models/contacto');
  require('../../models/solicitud');
}

// Initialize Redis cache
try {
  const { initializeRedis } = require('../cache/redisClient');
  initializeRedis();
  console.log('Metadata Server: Redis initialized');
} catch (error) {
  console.warn('Metadata Server: Redis initialization failed:', error.message);
}

// Initialize logger (BEFORE database to avoid side effects)
// Don't replace console until after we ensure we're not loading main index.js
try {
  // Only initialize logger, don't replace console yet to avoid conflicts
  const logger = require('../logging/logger');
  if (logger.replaceConsole && !process.env.METADATA_SERVER_SKIP_LOGGER) {
    logger.replaceConsole();
  }
} catch (error) {
  console.warn('Metadata Server: Logger initialization failed:', error.message);
}

// Initialize tracing
try {
  const { initializeTracing } = require('../tracing/tracer');
  initializeTracing();
} catch (error) {
  console.warn('Metadata Server: Tracing initialization failed:', error.message);
}

const app = express();
const PORT = process.env.METADATA_SERVER_PORT || 3004;

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

// Tracing middleware
try {
  const tracingMiddleware = require('../../middlewares/tracing');
  app.use(tracingMiddleware);
} catch (error) {
  console.warn('Metadata Server: Tracing middleware not available:', error.message);
}

// Health check endpoints
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'metadata-server',
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

// Routes will be loaded after database initialization
let routesLoaded = false;
function loadRoutes() {
  if (!routesLoaded) {
    app.use('/api', require('./routes'));
    routesLoaded = true;
  }
}

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

// Start server after database is initialized
initializeDatabase().then(() => {
  // Load routes after database and models are ready
  loadRoutes();
  
  // Start search indexing worker
  try {
    const { startSearchIndexingWorker } = require('../search/worker');
    startSearchIndexingWorker();
  } catch (error) {
    console.warn('Metadata Server: Search indexing worker not available:', error.message);
  }
  
  app.listen(PORT, () => {
    console.log(`Metadata Server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}).catch(err => {
  console.error('Metadata Server: Failed to initialize database:', err.message);
  // Start server anyway - routes will fail gracefully if models aren't loaded
  loadRoutes();
  app.listen(PORT, () => {
    console.log(`Metadata Server running on port ${PORT} (database initialization failed)`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.warn('Metadata Server: Some features may not work until database is connected');
  });
});

// Prevent process from exiting on unhandled errors
process.on('uncaughtException', (err) => {
  console.error('Metadata Server: Uncaught Exception:', err);
  // Don't exit - keep server running
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Metadata Server: Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit - keep server running
});

module.exports = app;

