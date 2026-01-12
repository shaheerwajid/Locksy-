const { verifyAccessToken } = require('../helpers/tokens');

const validarJWT = (req, res, next) => {
    // Leer token
    const token = req.header('x-token');
    if (!token) {
        return res.status(401).json({
            ok: false,
            msg: 'No hay token en la petición'
        });
    }

    try {
        const [valid, uid] = verifyAccessToken(token);
        
        if (!valid || !uid) {
            return res.status(401).json({
                ok: false,
                msg: 'Token no válido'
            });
        }

        req.uid = uid;
        next();

    } catch (error) {
        return res.status(401).json({
            ok: false,
            msg: 'Token no válido'
        })
    }
}

module.exports = {
    validarJWT
} 