/*
 * Response Caching Middleware
 * Implements cache-aside pattern for GET requests
 */

const cacheService = require('../services/cache/cacheService');

/**
 * Cache middleware - cache GET responses
 */
function cacheMiddleware(options = {}) {
  const {
    ttl = 300, // 5 minutes default
    generateKey = (req) => `cache:${req.method}:${req.originalUrl}`,
    skipCache = (req, res) => false,
  } = options;

  return async (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }

    // Skip if explicitly disabled
    if (skipCache(req, res)) {
      return next();
    }

    try {
      // Generate cache key
      const cacheKey = generateKey(req);

      // Try to get from cache
      const cached = await cacheService.get(cacheKey);

      if (cached) {
        // Set cache headers
        res.set('X-Cache', 'HIT');
        res.set('X-Cache-Key', cacheKey);
        return res.json(cached);
      }

      // Cache miss - store original json function
      const originalJson = res.json.bind(res);

      // Override json to cache response
      res.json = function (data) {
        // Cache the response
        cacheService.set(cacheKey, data, ttl).catch((err) => {
          console.error('Cache: Error caching response:', err.message);
        });

        // Set cache headers
        res.set('X-Cache', 'MISS');
        res.set('X-Cache-Key', cacheKey);

        // Call original json
        return originalJson(data);
      };

      next();
    } catch (error) {
      console.error('Cache middleware error:', error);
      next();
    }
  };
}

/**
 * Cache invalidation middleware
 */
function invalidateCache(pattern) {
  return async (req, res, next) => {
    try {
      if (pattern) {
        await cacheService.deletePattern(pattern);
      }
      next();
    } catch (error) {
      console.error('Cache invalidation error:', error);
      next();
    }
  };
}

module.exports = {
  cacheMiddleware,
  invalidateCache,
};

