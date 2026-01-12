/*
 * Rate Limiting Middleware
 * Controls request rate per user/IP
 * Part of Serverless Functions layer
 */

const rateLimit = require('express-rate-limit');
let RedisStore, Redis;
let redisClient = null;

// Try to initialize Redis for rate limiting (optional, falls back to memory store)
try {
    RedisStore = require('rate-limit-redis');
    Redis = require('ioredis');
    
    // Initialize Redis client for rate limiting (lazy connection)
    if (process.env.REDIS_URL || process.env.REDIS_HOST) {
        redisClient = process.env.REDIS_URL 
            ? new Redis(process.env.REDIS_URL, { lazyConnect: true })
            : new Redis({
                host: process.env.REDIS_HOST || 'localhost',
                port: parseInt(process.env.REDIS_PORT || '6379'),
                password: process.env.REDIS_PASSWORD || undefined,
                lazyConnect: true
            });
        
        // ioredis connects automatically; optionally verify connectivity in background
        redisClient.on('error', err => {
            console.warn('Redis connection error, falling back to memory store for rate limiting:', err.message);
            redisClient = null;
        });
    }
} catch (error) {
    console.warn('Redis packages not available, using memory store for rate limiting');
    redisClient = null;
}

// Helper to create rate limiter with Redis store if available, otherwise memory store
const createLimiter = (options) => {
    const limiterOptions = {
        windowMs: options.windowMs,
        max: options.max,
        message: options.message,
        standardHeaders: true,
        legacyHeaders: false,
        ...options.extraOptions
    };
    
    // Use Redis store if available, otherwise use default memory store
    if (redisClient && RedisStore && process.env.USE_REDIS_RATE_LIMIT === 'true') {
        try {
            limiterOptions.store = new RedisStore({
                client: redisClient,
                prefix: options.prefix || 'rl:'
            });
        } catch (err) {
            console.warn('RateLimiter: Failed to initialize Redis store, using memory store:', err.message);
        }
    }
    
    return rateLimit(limiterOptions);
};

// General API rate limiter
const apiLimiter = createLimiter({
    prefix: 'rl:api:',
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});

// Stricter rate limiter for login endpoints
const loginLimiter = createLimiter({
    prefix: 'rl:login:',
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // Limit each IP to 5 login attempts per windowMs
    message: 'Too many login attempts, please try again later.',
    extraOptions: {
        skipSuccessfulRequests: true // Don't count successful logins
    }
});

// File upload rate limiter
const uploadLimiter = createLimiter({
    prefix: 'rl:upload:',
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 50, // Limit each IP to 50 uploads per hour
    message: 'Too many file uploads, please try again later.'
});

// Per-user rate limiter (requires authentication)
const userLimiter = createLimiter({
    prefix: 'rl:user:',
    windowMs: 60 * 1000, // 1 minute
    max: 60, // 60 requests per minute per user
    extraOptions: {
        keyGenerator: (req) => {
            // Use user ID from token if available
            return req.uid || req.ip;
        }
    }
});

// Apply rate limiting based on route
const rateLimiterMiddleware = (req, res, next) => {
    // Login routes - strict limit
    if (req.path.startsWith('/api/login')) {
        return loginLimiter(req, res, next);
    }
    
    // Upload routes - upload limit
    if (req.path.startsWith('/api/archivos') && req.method === 'POST') {
        return uploadLimiter(req, res, next);
    }
    
    // Authenticated routes - user limit
    if (req.uid) {
        return userLimiter(req, res, next);
    }
    
    // Default - API limit
    return apiLimiter(req, res, next);
};

module.exports = rateLimiterMiddleware;

