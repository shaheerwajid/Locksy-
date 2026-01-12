/*
 * API Gateway Service
 * Acts as the single entry point for all API requests
 * Routes requests to appropriate backend services based on Control/Data path
 */

const express = require('express');

// Middleware imports
const authMiddleware = require('./middleware/auth');
const rateLimiterMiddleware = require('./middleware/rateLimiter');
const validatorMiddleware = require('./middleware/validator');
const transformerMiddleware = require('./middleware/transformer');
const loggerMiddleware = require('./middleware/logger');
const monitorMiddleware = require('./middleware/monitor');

// Route imports
const controlRoutes = require('./routes/control');
const dataRoutes = require('./routes/data');
const proxyRoutes = require('./routes/proxy');

// Serverless Functions
const serverlessFunctions = require('../functions');

const app = express();

// NOTE: Body parser is NOT needed here because the main app (index.js) already has body parser
// The gateway receives requests with req.body already parsed by the main app's body parser
// This avoids double parsing and stream consumption issues

// Health check routes (MUST be FIRST, before ALL middleware to bypass authentication)
// These routes are public and should not go through auth/rate limiting
app.get('/health', (req, res) => {
    res.json({
        ok: true,
        status: 'healthy',
        timestamp: new Date().toISOString()
    });
});

app.get('/health/ready', async (req, res) => {
    try {
        const mongoose = require('mongoose');
        const dbStatus = mongoose.connection.readyState === 1;
        
        if (dbStatus) {
            res.json({
                ok: true,
                status: 'ready',
                checks: {
                    database: 'connected'
                }
            });
        } else {
            res.status(503).json({
                ok: false,
                status: 'not ready',
                checks: {
                    database: 'disconnected'
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

app.get('/health/live', (req, res) => {
    res.json({
        ok: true,
        status: 'alive'
    });
});

// Apply serverless functions layer (cross-cutting concerns)
// Note: Health routes above bypass these functions
// Order matters: logger → reverse proxy → monitor → auth → authorize → cache → transform
app.use(serverlessFunctions.loggerFunction);
app.use(serverlessFunctions.reverseProxyFunction);
app.use(serverlessFunctions.monitorFunction);
app.use(serverlessFunctions.authFunction);
app.use(serverlessFunctions.authorizeFunction);
app.use(serverlessFunctions.cacheFunction);
app.use(serverlessFunctions.transformFunction);

// CDN integration for static files (before routes)
try {
  const cdnService = require('../services/cdn/cdnService');
  const { cdnStaticMiddleware, injectCDNUrls } = require('../middlewares/cdn-static');
  
  if (cdnService.isEnabled()) {
    // Inject CDN URLs into HTML responses
    app.use(injectCDNUrls);
    // Redirect static file requests to CDN
    app.use(cdnStaticMiddleware);
  }
} catch (error) {
  // CDN middleware not available, continue without it
}

// Gateway middleware chain
app.use(loggerMiddleware); // Logging first
app.use(monitorMiddleware); // Monitoring
app.use(rateLimiterMiddleware); // Rate limiting
app.use(authMiddleware); // Authentication (after rate limiting)
app.use(validatorMiddleware); // Request validation

// Control Path Routes (Metadata operations)
// Routes: /api/login, /api/usuarios, /api/grupos, /api/contactos, /api/mensajes, /api/solicitudes
app.use('/api', controlRoutes);

// Data Path Routes (File operations)
// Routes: /api/archivos
app.use('/api/archivos', dataRoutes);

// Proxy routes for other services
app.use('/', proxyRoutes);

// Error handling middleware (must be last)
app.use((err, req, res, next) => {
    console.error('Gateway Error:', err);
    res.status(err.status || 500).json({
        ok: false,
        msg: err.message || 'Internal server error',
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
});

module.exports = app;

