/*
 * Auth Endpoints Tests
 */

const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../index');
const Usuario = require('../models/usuario');
const RefreshToken = require('../models/refreshToken');

describe('Auth Endpoints', () => {
  beforeAll(async () => {
    // Connect to test database
    await mongoose.connect(process.env.DB_CNN_TEST || process.env.DB_CNN);
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  describe('POST /api/login/new', () => {
    it('should create user without privateKey field', async () => {
      const res = await request(app)
        .post('/api/login/new')
        .send({
          nombre: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          publicKey: '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END PUBLIC KEY-----',
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.usuario).not.toHaveProperty('privateKey');
      expect(res.body.accessToken).toBeDefined();
      
      // Verify user in database
      const user = await Usuario.findById(res.body.usuario.uid);
      expect(user.privateKey).toBeUndefined();
      expect(user.publicKey).toBeDefined();

      // Cleanup
      await Usuario.findByIdAndDelete(res.body.usuario.uid);
    });
  });

  describe('POST /api/auth/refresh', () => {
    it('should refresh access token and rotate refresh token', async () => {
      // First, create user and login
      const registerRes = await request(app)
        .post('/api/login/new')
        .send({
          nombre: 'Test User',
          email: 'test2@example.com',
          password: 'password123',
        });

      const refreshToken = registerRes.headers['set-cookie']
        ?.find(c => c.startsWith('refreshToken='))
        ?.split(';')[0]
        ?.split('=')[1];

      // Refresh token
      const refreshRes = await request(app)
        .post('/api/auth/refresh')
        .set('Cookie', `refreshToken=${refreshToken}`)
        .send({});

      expect(refreshRes.statusCode).toBe(200);
      expect(refreshRes.body.ok).toBe(true);
      expect(refreshRes.body.accessToken).toBeDefined();
      
      // Verify old token is revoked
      const oldTokenDoc = await RefreshToken.findByToken(refreshToken);
      expect(oldTokenDoc.revoked).toBe(true);

      // Cleanup
      await Usuario.findOneAndDelete({ email: 'test2@example.com' });
    });
  });
});

