/*
 * Caching Serverless Function
 * Implements response caching for frequently accessed data
 */

const cacheService = require('../services/cache/cacheService');

const cacheFunction = async (req, res, next) => {
    // Skip caching for POST, PUT, DELETE requests
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
        return next();
    }
    
    // Cacheable endpoints
    const cacheablePaths = [
        '/api/usuarios',
        '/api/grupos',
        '/api/contactos'
    ];
    
    // Check if this is a cacheable request
    const isCacheable = cacheablePaths.some(path => req.path.startsWith(path));
    
    if (isCacheable) {
        try {
            // Generate cache key
            const cacheKey = `cache:${req.method}:${req.originalUrl}:${req.user?.uid || 'anonymous'}`;
            
            // Try to get from cache
            const cached = await cacheService.get(cacheKey);
            
            if (cached) {
                // Set cache headers
                res.set('Cache-Control', 'private, max-age=300');
                res.set('X-Cache', 'HIT');
                res.set('X-Cache-Key', cacheKey);
                return res.json(cached);
            }
            
            // Cache miss - store original json function
            const originalJson = res.json.bind(res);
            
            // Override json to cache response
            res.json = function (data) {
                // Cache the response (5 minutes TTL)
                cacheService.set(cacheKey, data, 300).catch((err) => {
                    console.error('Cache: Error caching response:', err.message);
                });
                
                // Set cache headers
                res.set('Cache-Control', 'private, max-age=300');
                res.set('X-Cache', 'MISS');
                res.set('X-Cache-Key', cacheKey);
                
                // Call original json
                return originalJson(data);
            };
        } catch (error) {
            console.error('Cache function error:', error);
            // Continue without caching on error
        }
    }
    
    next();
};

module.exports = cacheFunction;

