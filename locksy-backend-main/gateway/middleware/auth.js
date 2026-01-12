/*
 * Authentication Middleware
 * Validates JWT tokens from requests
 * Part of Serverless Functions layer
 */

const { comprobarJWT } = require('../../helpers/jwt');

const authMiddleware = async (req, res, next) => {
    // Skip auth for public endpoints
    const publicPaths = [
        '/api/login/new', 
        '/api/login/send-otp',
        '/api/login/verify-otp',
        '/api/login/forgot-password',
        '/api/login/verify-reset-otp',
        '/api/login/reset-password',
        '/api/login', 
        '/health', 
        '/health/ready', 
        '/health/live', 
        '/api/usuarios/recoveryPasswordS1'
    ];
    if (publicPaths.some(path => req.path.startsWith(path))) {
        return next();
    }

    const token = req.header('x-token');
    
    if (!token) {
        return res.status(401).json({
            ok: false,
            msg: 'No hay token en la petición'
        });
    }

    try {
        const [valido, uid] = comprobarJWT(token);
        
        if (!valido) {
            return res.status(401).json({
                ok: false,
                msg: 'Token no válido'
            });
        }

        // Attach user ID to request for downstream use
        req.uid = uid;
        req.token = token;
        
        next();
    } catch (error) {
        return res.status(401).json({
            ok: false,
            msg: 'Token no válido'
        });
    }
};

module.exports = authMiddleware;

