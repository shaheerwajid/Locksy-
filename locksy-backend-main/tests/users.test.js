/*
 * User Endpoints Tests
 */

const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../index');
const Usuario = require('../models/usuario');
const { generateAccessToken } = require('../helpers/tokens');

describe('User Endpoints', () => {
  let accessToken;
  let testUserId;

  beforeAll(async () => {
    await mongoose.connect(process.env.DB_CNN_TEST || process.env.DB_CNN);
    
    // Create test user and get token
    const registerRes = await request(app)
      .post('/api/login/new')
      .send({
        nombre: 'Test User',
        email: 'testuser@example.com',
        password: 'password123',
        publicKey: '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END PUBLIC KEY-----',
      });

    accessToken = registerRes.body.accessToken;
    testUserId = registerRes.body.usuario.uid;
  });

  afterAll(async () => {
    await Usuario.findByIdAndDelete(testUserId);
    await mongoose.connection.close();
  });

  describe('GET /api/usuarios/:id/public-key', () => {
    it('should return public key only (no private key)', async () => {
      const res = await request(app)
        .get(`/api/usuarios/${testUserId}/public-key`)
        .set('x-token', accessToken);

      expect(res.statusCode).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.usuario.publicKey).toBeDefined();
      expect(res.body.usuario).not.toHaveProperty('privateKey');
    });

    it('should return 404 for non-existent user', async () => {
      const fakeId = new mongoose.Types.ObjectId();
      const res = await request(app)
        .get(`/api/usuarios/${fakeId}/public-key`)
        .set('x-token', accessToken);

      expect(res.statusCode).toBe(404);
    });
  });
});

