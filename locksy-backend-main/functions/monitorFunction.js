/*
 * Monitoring Serverless Function
 * Tracks API usage and performance metrics
 */

const monitorFunction = (req, res, next) => {
    const startTime = process.hrtime.bigint();
    
    // Track request start
    req.metrics = {
        startTime: startTime,
        method: req.method,
        path: req.path,
        endpoint: `${req.method} ${req.path}`
    };
    
    // Track response completion
    res.on('finish', () => {
        const duration = Number(process.hrtime.bigint() - startTime) / 1000000; // Convert to milliseconds
        
        // Emit metrics
        const metrics = {
            endpoint: req.metrics.endpoint,
            statusCode: res.statusCode,
            duration: duration,
            timestamp: new Date().toISOString(),
            requestId: req.requestId
        };
        
        // Log metrics (will be enhanced with Prometheus in Phase 8)
        console.log(JSON.stringify({
            type: 'metric',
            ...metrics
        }));
        
        // TODO: Send to metrics service (Prometheus, StatsD, CloudWatch)
    });
    
    next();
};

module.exports = monitorFunction;

