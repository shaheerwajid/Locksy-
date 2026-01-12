/*
 * Logging Middleware
 * Structured logging for all requests
 * Part of Serverless Functions layer
 */

const { v4: uuidv4 } = require('uuid');

const loggerMiddleware = (req, res, next) => {
    // Generate request ID for tracing
    req.requestId = req.headers['x-request-id'] || uuidv4();
    res.setHeader('X-Request-ID', req.requestId);
    
    // Log request start
    const startTime = Date.now();
    
    // Log request
    console.log(JSON.stringify({
        type: 'request',
        requestId: req.requestId,
        method: req.method,
        path: req.path,
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.get('user-agent'),
        timestamp: new Date().toISOString()
    }));
    
    // Log response when finished
    res.on('finish', () => {
        const duration = Date.now() - startTime;
        
        console.log(JSON.stringify({
            type: 'response',
            requestId: req.requestId,
            method: req.method,
            path: req.path,
            statusCode: res.statusCode,
            duration: `${duration}ms`,
            timestamp: new Date().toISOString()
        }));
    });
    
    next();
};

module.exports = loggerMiddleware;

