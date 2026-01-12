const { verifyAccessToken, generateAccessToken } = require('./tokens');

// Keep for backward compatibility, but use new token system
const generarJWT = async (uid) => {
  return await generateAccessToken(uid);
};

const comprobarJWT = (token = '') => {
  return verifyAccessToken(token);
};

module.exports = {
  generarJWT,
  comprobarJWT,
};