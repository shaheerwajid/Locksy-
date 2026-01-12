/*
 * Response Transformation Middleware
 * Transforms responses to consistent format
 * Part of Serverless Functions layer
 */

const transformerMiddleware = (req, res, next) => {
    // Store original json method
    const originalJson = res.json.bind(res);
    
    // Override json method to transform responses
    res.json = function(data) {
        // Transform response to consistent format
        const transformedData = {
            timestamp: new Date().toISOString(),
            ...data
        };
        
        // Add request ID if available
        if (req.requestId) {
            transformedData.requestId = req.requestId;
        }
        
        return originalJson(transformedData);
    };
    
    next();
};

module.exports = transformerMiddleware;

