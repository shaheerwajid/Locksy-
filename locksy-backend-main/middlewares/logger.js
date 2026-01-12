/*
 * Structured Logging Middleware
 * Adds request ID and logging context to requests
 */

const { v4: uuidv4 } = require('uuid');
const { createContextLogger } = require('../services/logging/logger');

/**
 * Request logging middleware
 */
function loggerMiddleware(req, res, next) {
  // Generate or use existing request ID
  const requestId = req.headers['x-request-id'] || uuidv4();
  
  // Add request ID to request and response
  req.requestId = requestId;
  req.logger = createContextLogger(requestId, req.user?.uid);
  res.setHeader('X-Request-ID', requestId);

  // Log request
  req.logger.info('Incoming request', {
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });

  // Log response
  const startTime = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    req.logger.info('Request completed', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
  });

  next();
}

module.exports = loggerMiddleware;

