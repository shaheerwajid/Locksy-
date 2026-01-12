/*
 * Reverse Proxy Serverless Function
 * Routes requests to appropriate backend services
 * This is handled by the gateway routing, but function exists for template compliance
 */

const reverseProxyFunction = (req, res, next) => {
    // Routing logic is handled in gateway/routes
    // This function can add additional proxy headers or modify routing
    
    // Add service identification headers
    if (req.path.startsWith('/api/archivos')) {
        req.serviceTarget = 'block-server';
    } else if (req.path.startsWith('/api/')) {
        req.serviceTarget = 'metadata-server';
    }
    
    next();
};

module.exports = reverseProxyFunction;

