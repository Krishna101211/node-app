const { app } = require('../src/index');
const request = require('supertest');

describe('Integration Tests', () => {
  describe('Health Check', () => {
    it('should return healthy status with all required fields', async () => {
      const response = await request(app)
        .get('/health')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'ok',
        environment: expect.any(String),
        uptime: expect.any(Number),
      });
    });
  });

  describe('API Routes', () => {
    it('should handle GET /api', async () => {
      const response = await request(app)
        .get('/api')
        .expect(200);

      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('Security Headers', () => {
    it('should include security headers', async () => {
      const response = await request(app).get('/health');
      expect(response.headers['x-frame-options']).toBeDefined();
      expect(response.headers['x-content-type-options']).toBeDefined();
      expect(response.headers['x-xss-protection']).toBeDefined();
    });
  });
});
