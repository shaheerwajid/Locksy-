/*
 * Cache Middleware for Metadata Server
 * Implements cache-aside pattern for metadata operations
 */

const cacheService = require('../../cache/cacheService');

/**
 * Cache-aside middleware for GET requests
 * Checks cache first, then DB, then updates cache
 */
const cacheAside = (options = {}) => {
  const {
    ttl = 3600, // Default 1 hour
    keyGenerator = (req) => {
      // Default key: method:path:query:params
      const key = `${req.method}:${req.path}`;
      const query = JSON.stringify(req.query);
      const params = JSON.stringify(req.params);
      return `${key}:${query}:${params}`;
    },
    skipCache = false, // Function to determine if cache should be skipped
  } = options;

  return async (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }

    // Check if cache should be skipped
    if (skipCache && skipCache(req)) {
      return next();
    }

    try {
      const cacheKey = keyGenerator(req);
      
      // Try to get from cache
      const cached = await cacheService.get(cacheKey);
      
      if (cached !== null) {
        // Cache hit
        res.setHeader('X-Cache', 'HIT');
        return res.json({
          ...cached,
          cached: true
        });
      }

      // Cache miss - continue to controller
      // Store original json method
      const originalJson = res.json.bind(res);
      
      // Override json to cache response
      res.json = function(data) {
        // Cache the response (async, don't block)
        if (data && data.ok !== false) {
          cacheService.set(cacheKey, data, ttl).catch(err => {
            console.error('Cache set error:', err.message);
          });
        }
        res.setHeader('X-Cache', 'MISS');
        return originalJson(data);
      };

      next();
    } catch (error) {
      console.error('Cache middleware error:', error.message);
      // Continue without caching on error
      next();
    }
  };
};

/**
 * Cache invalidation middleware
 * Invalidates cache on write operations
 */
const invalidateCache = (patterns = []) => {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json.bind(res);
    
    // Override json to invalidate cache after successful write
    res.json = function(data) {
      if (data && data.ok !== false) {
        // Invalidate cache patterns (async, don't block)
        Promise.all(
          patterns.map(pattern => 
            cacheService.deletePattern(pattern).catch(err => {
              console.error(`Cache invalidation error for pattern ${pattern}:`, err.message);
            })
          )
        ).catch(err => {
          console.error('Cache invalidation error:', err.message);
        });
      }
      return originalJson(data);
    };

    next();
  };
};

module.exports = {
  cacheAside,
  invalidateCache
};


