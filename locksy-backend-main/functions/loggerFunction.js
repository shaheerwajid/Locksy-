/*
 * Logging Serverless Function
 * Records API requests and responses for auditing and debugging
 */

const loggerFunction = (req, res, next) => {
    // Request logging is handled by gateway/middleware/logger.js
    // This function provides additional logging capabilities
    
    // Log sensitive operations
    const sensitiveOperations = [
        '/api/login',
        '/api/usuarios/recoveryPasswordS1',
        '/api/usuarios/cambiarClave'
    ];
    
    if (sensitiveOperations.some(path => req.path.startsWith(path))) {
        // Log without sensitive data
        console.log(JSON.stringify({
            type: 'sensitive_operation',
            method: req.method,
            path: req.path,
            ip: req.ip,
            timestamp: new Date().toISOString(),
            requestId: req.requestId
        }));
    }
    
    next();
};

module.exports = loggerFunction;

