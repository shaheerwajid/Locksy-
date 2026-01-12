/*
 * Request Validation Middleware
 * Validates and sanitizes incoming requests
 * Part of Serverless Functions layer
 */

const { validationResult } = require('express-validator');
const { body, query, param } = require('express-validator');

// Request validation middleware
const validatorMiddleware = (req, res, next) => {
    // Basic validation for common patterns
    const errors = validationResult(req);
    
    if (!errors.isEmpty()) {
        return res.status(400).json({
            ok: false,
            errors: errors.mapped()
        });
    }
    
    // Sanitize common inputs
    if (req.body) {
        // Remove potentially dangerous characters
        Object.keys(req.body).forEach(key => {
            if (typeof req.body[key] === 'string') {
                // Basic XSS prevention
                req.body[key] = req.body[key].replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
            }
        });
    }
    
    next();
};

// Validation rules for common endpoints
const validationRules = {
    login: [
        body('email').isEmail().normalizeEmail(),
        body('password').notEmpty().trim().isLength({ min: 6 })
    ],
    register: [
        body('email').isEmail().normalizeEmail(),
        body('password').notEmpty().trim().isLength({ min: 6 }),
        body('nombre').notEmpty().trim().isLength({ min: 2, max: 50 })
    ],
    userId: [
        param('uid').isMongoId().withMessage('Invalid user ID format')
    ],
    fileUpload: [
        body('type').isIn(['images', 'video', 'audio', 'documents', 'recording']),
        body('extension').notEmpty()
    ]
};

module.exports = validatorMiddleware;
module.exports.validationRules = validationRules;

