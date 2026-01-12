/*
 * Authentication Serverless Function
 * Validates user identity before requests reach API Gateway
 */

const { comprobarJWT } = require('../helpers/jwt');

const authFunction = async (req, res, next) => {
    // Public endpoints that don't require authentication
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
        '/api/usuarios/recoveryPasswordS1',
        '/api/usuarios/recoverPassword',
        '/api/usuarios/email-check'
    ];
    
    if (publicPaths.some(path => req.path === path || req.path.startsWith(path))) {
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
        
        req.uid = uid;
        req.token = token;
        req.authenticated = true;
        
        next();
    } catch (error) {
        return res.status(401).json({
            ok: false,
            msg: 'Error de autenticación'
        });
    }
};

module.exports = authFunction;

