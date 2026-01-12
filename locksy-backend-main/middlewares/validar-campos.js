const { validationResult } = require('express-validator');

/**
 * Enhanced input validation middleware
 * Includes sanitization and XSS prevention
 */
const validarCampos = (req, res, next) => {
    const errores = validationResult(req);

    if (!errores.isEmpty()) {
        // Log validation errors
        if (req.logger) {
            req.logger.warn('Validation failed', {
                errors: errores.array(),
                path: req.path,
                method: req.method,
            });
        }

        return res.status(400).json({
            ok: false,
            errors: errores.mapped()
        });
    }

    next();
}

/**
 * Sanitize string input to prevent XSS
 */
function sanitizeInput(str) {
    if (typeof str !== 'string') {
        return str;
    }
    
    return str
        .replace(/[<>]/g, '') // Remove < and >
        .trim();
}

/**
 * Sanitize object recursively
 */
function sanitizeObject(obj) {
    if (typeof obj !== 'object' || obj === null) {
        return typeof obj === 'string' ? sanitizeInput(obj) : obj;
    }

    if (Array.isArray(obj)) {
        return obj.map(item => sanitizeObject(item));
    }

    const sanitized = {};
    for (const key in obj) {
        if (obj.hasOwnProperty(key)) {
            sanitized[key] = sanitizeObject(obj[key]);
        }
    }

    return sanitized;
}

/**
 * Sanitize request body middleware
 */
const sanitizeBody = (req, res, next) => {
    if (req.body && typeof req.body === 'object') {
        req.body = sanitizeObject(req.body);
    }
    next();
}

module.exports = {
    validarCampos,
    sanitizeInput,
    sanitizeObject,
    sanitizeBody,
}