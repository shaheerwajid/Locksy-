/*
 * Message Endpoints Tests
 */

const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../index');
const Usuario = require('../models/usuario');
const Mensaje = require('../models/mensaje');
const { generateAccessToken } = require('../helpers/tokens');

describe('Message Endpoints', () => {
  let accessToken;
  let userId1;
  let userId2;

  beforeAll(async () => {
    await mongoose.connect(process.env.DB_CNN_TEST || process.env.DB_CNN);
    
    // Create test users
    const user1 = new Usuario({
      nombre: 'User 1',
      email: 'user1@test.com',
      password: 'hashed',
      codigoContacto: 'TEST1',
    });
    await user1.save();
    userId1 = user1._id.toString();

    const user2 = new Usuario({
      nombre: 'User 2',
      email: 'user2@test.com',
      password: 'hashed',
      codigoContacto: 'TEST2',
    });
    await user2.save();
    userId2 = user2._id.toString();

    accessToken = await generateAccessToken(userId1);
  });

  afterAll(async () => {
    await Usuario.deleteMany({ email: { $in: ['user1@test.com', 'user2@test.com'] } });
    await Mensaje.deleteMany({ de: { $in: [userId1, userId2] } });
    await mongoose.connection.close();
  });

  describe('POST /api/mensajes', () => {
    it('should accept ciphertext only and reject plaintext', async () => {
      // Valid ciphertext (base64 encoded, minimum 256 bytes)
      const validCiphertext = Buffer.alloc(256).fill('A').toString('base64');

      const res = await request(app)
        .post('/api/mensajes')
        .set('x-token', accessToken)
        .send({
          para: userId2,
          mensaje: {
            ciphertext: validCiphertext,
            type: 'text',
          },
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.mensaje.mensaje.ciphertext).toBe(validCiphertext);
      
      // Verify no plaintext in database
      const message = await Mensaje.findById(res.body.mensaje._id);
      expect(message.mensaje.ciphertext).toBeDefined();
      expect(message.mensaje).not.toHaveProperty('plaintext');
    });

    it('should reject invalid ciphertext format', async () => {
      const res = await request(app)
        .post('/api/mensajes')
        .set('x-token', accessToken)
        .send({
          para: userId2,
          mensaje: {
            ciphertext: 'invalid-ciphertext',
            type: 'text',
          },
        });

      expect(res.statusCode).toBe(400);
      expect(res.body.ok).toBe(false);
    });
  });
});

