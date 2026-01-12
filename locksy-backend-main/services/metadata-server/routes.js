/*
 * Metadata Server Routes
 * Routes for metadata operations (users, groups, messages, contacts, requests)
 */

const express = require('express');
const router = express.Router();

// Import controllers
const usersController = require('./controllers/usersController');
const groupsController = require('./controllers/groupsController');
const messagesController = require('./controllers/messagesController');
const contactsController = require('./controllers/contactsController');
const requestsController = require('./controllers/requestsController');

// JWT validation middleware (reuse from main app)
const { validarJWT } = require('../../middlewares/validar-jwt');

// User routes
router.get('/usuarios', validarJWT, usersController.getUsuarios);
router.post('/usuarios', validarJWT, usersController.getUsuario);
router.post('/usuarios/getUsuario', validarJWT, usersController.getUsuario); // Legacy compatibility route
router.put('/usuarios', validarJWT, usersController.updateUsuario);
router.post('/usuarios/updateUsuario', validarJWT, usersController.updateUsuario); // Legacy compatibility route
router.post('/usuarios/block', validarJWT, usersController.blockUsers);
router.post('/usuarios/unblock', validarJWT, usersController.unBlockUsers);
router.get('/usuarios/:id/public-key', usersController.obtenerPublicKey);
router.put('/usuarios/public-key', validarJWT, usersController.actualizarPublicKey);
router.post('/usuarios/me/keys', validarJWT, usersController.actualizarKeys);
router.post('/usuarios/check-email', usersController.registerEmailCheck);
router.post('/usuarios/recovery-password-s1', usersController.recoveryPasswordS1);
router.get('/usuarios/recovery-password-s2', usersController.recoveryPasswordS2);
router.post('/usuarios/recovery-password-s2', usersController.validarPreguntas);
router.post('/usuarios/cambiar-clave', usersController.cambiarClave);
router.post('/usuarios/registrar-preguntas', validarJWT, usersController.registrarPreguntas);
router.post('/usuarios/report', validarJWT, usersController.report);
router.get('/usuarios/pagos', validarJWT, usersController.getPagos);
router.post('/usuarios/pagos', validarJWT, usersController.registrarPago);

// Group routes
router.post('/grupos', validarJWT, groupsController.addGroup);
router.put('/grupos', validarJWT, groupsController.updateGroup);
router.post('/grupos/members', validarJWT, groupsController.groupMembers);
router.post('/grupos/member', validarJWT, groupsController.addMember);
router.delete('/grupos/member', validarJWT, groupsController.removeMember);
router.delete('/grupos', validarJWT, groupsController.removeGroup);
router.post('/grupos/by-code', validarJWT, groupsController.groupByCode);
router.post('/grupos/by-member', validarJWT, groupsController.groupsByMember);
router.put('/grupos/disappear-time', validarJWT, groupsController.updatGroupDisappearTime);

// Legacy group route aliases for backward compatibility
router.post('/grupos/addGroup', validarJWT, groupsController.addGroup);
router.post('/grupos/updateGroup', validarJWT, groupsController.updateGroup);
router.post('/grupos/groupMembers', validarJWT, groupsController.groupMembers);
router.post('/grupos/addMember', validarJWT, groupsController.addMember);
router.post('/grupos/removeMember', validarJWT, groupsController.removeMember);
router.post('/grupos/removeGroup', validarJWT, groupsController.removeGroup);
router.post('/grupos/groupsByMember', validarJWT, groupsController.groupsByMember);

// Message routes
router.get('/mensajes/chat/:de', validarJWT, messagesController.obtenerChat);
router.post('/mensajes', validarJWT, messagesController.crearMensaje);

// Contact routes
router.post('/contactos', validarJWT, contactsController.createContacto);
router.post('/contactos/list', validarJWT, contactsController.getListadoContactos);
router.put('/contactos/activate', validarJWT, contactsController.activateContacto);
router.delete('/contactos', validarJWT, contactsController.dropContacto);
router.put('/contactos/disappear-time', validarJWT, contactsController.updatContactDisappearTime);
router.post('/contactos/reject-call', validarJWT, contactsController.rejectCallHandler);

// Legacy contact route aliases for backward compatibility
// Note: getContactos uses POST /contactos with body to differentiate from createContacto
router.post('/contactos/getContactos', validarJWT, contactsController.getContactos);
router.post('/contactos/getListadoContactos', validarJWT, contactsController.getListadoContactos);
router.post('/contactos/activateContacto', validarJWT, contactsController.activateContacto);
router.post('/contactos/dropContacto', validarJWT, contactsController.dropContacto);

// Request routes
router.get('/solicitudes/:para', validarJWT, requestsController.buscarSolicitudes);
router.get('/incognitos/:para', validarJWT, requestsController.buscarIncognitos);

// Feed routes
router.use('/feed', require('../../routes/feed'));

// Search routes
router.use('/search', require('../../routes/search'));

// Legacy PMS routes removed - use direct API routes instead
// router.use('/pms', require('../../routes/usuarios')); // This was loading index.js

module.exports = router;

