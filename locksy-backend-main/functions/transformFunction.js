/*
 * Transformation Serverless Function
 * Transforms request/response data formats
 */

const transformFunction = (req, res, next) => {
    // Transform request data if needed
    if (req.body && typeof req.body === 'object') {
        // Normalize data formats
        // Convert string numbers to actual numbers where appropriate
        Object.keys(req.body).forEach(key => {
            if (typeof req.body[key] === 'string' && !isNaN(req.body[key]) && req.body[key] !== '') {
                // Don't convert IDs or codes that should remain strings
                if (!['uid', 'codigo', 'codigoContacto', 'email', 'password'].includes(key)) {
                    const num = Number(req.body[key]);
                    if (!isNaN(num)) {
                        req.body[key] = num;
                    }
                }
            }
        });
    }
    
    // Transform response will be handled by response transformer middleware
    next();
};

module.exports = transformFunction;

