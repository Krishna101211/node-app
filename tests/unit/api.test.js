const { app } = require('../src/index');
const request = require('supertest');

describe('Health Endpoint', () => {
  it('should return 200 with health status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('status', 'ok');
    expect(response.body).toHaveProperty('uptime');
    expect(response.body).toHaveProperty('timestamp');
  });
});

describe('API Endpoint', () => {
  it('should return API info', async () => {
    const response = await request(app).get('/api');
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message', 'API is running');
  });
});

describe('404 Handler', () => {
  it('should return 404 for unknown routes', async () => {
    const response = await request(app).get('/unknown');
    expect(response.status).toBe(404);
  });
});
