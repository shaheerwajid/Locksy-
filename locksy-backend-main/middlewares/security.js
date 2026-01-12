/*
 * Security Middleware
 * Implements security headers and protections using Helmet
 */

const helmet = require('helmet');
const config = require('../config');

/**
 * Security headers middleware
 */
function securityMiddleware() {
  return helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"],
      },
    },
    crossOriginEmbedderPolicy: false, // Disable if needed for file uploads
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
  });
}

/**
 * CORS configuration middleware
 */
function corsMiddleware() {
  return (req, res, next) => {
    const origin = req.headers.origin;
    const allowedOrigins = process.env.ALLOWED_ORIGINS 
      ? process.env.ALLOWED_ORIGINS.split(',')
      : ['*'];

    if (allowedOrigins.includes('*') || (origin && allowedOrigins.includes(origin))) {
      res.header('Access-Control-Allow-Origin', origin || '*');
    }

    res.header('Access-Control-Allow-Headers', 'x-token, Content-Type, firebaseid, Authorization, X-Request-ID');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH');
    res.header('Access-Control-Expose-Headers', 'X-Request-ID, X-Cache, X-Cache-Key');
    res.header('X-Content-Type-Options', 'nosniff');
    res.header('X-Frame-Options', 'DENY');
    res.header('X-XSS-Protection', '1; mode=block');

    if (req.method === 'OPTIONS') {
      return res.sendStatus(200);
    }

    next();
  };
}

/**
 * Rate limiting headers
 */
function rateLimitHeaders(req, res, next) {
  res.header('X-RateLimit-Limit', req.rateLimit?.limit || 'N/A');
  res.header('X-RateLimit-Remaining', req.rateLimit?.remaining || 'N/A');
  res.header('X-RateLimit-Reset', req.rateLimit?.resetTime || 'N/A');
  next();
}

module.exports = {
  securityMiddleware,
  corsMiddleware,
  rateLimitHeaders,
};

