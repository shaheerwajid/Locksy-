/*
 * Monitoring Middleware
 * Tracks metrics for API performance
 * Part of Serverless Functions layer
 */

const monitorMiddleware = (req, res, next) => {
    const startTime = Date.now();
    
    // Track request metrics
    res.on('finish', () => {
        const duration = Date.now() - startTime;
        
        // Emit metrics (can be sent to Prometheus, StatsD, etc.)
        // For now, log metrics
        const metrics = {
            method: req.method,
            path: req.path,
            statusCode: res.statusCode,
            duration: duration,
            timestamp: new Date().toISOString()
        };
        
        // TODO: Send to metrics collection service (Prometheus, StatsD)
        // metricsClient.record(metrics);
        
        // Log slow requests (> 1 second)
        if (duration > 1000) {
            console.warn(`Slow request detected: ${req.method} ${req.path} took ${duration}ms`);
        }
    });
    
    next();
};

module.exports = monitorMiddleware;

