const dotenv = require('dotenv');
dotenv.config();

const requiredEnvVars = ['PORT', 'DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];

const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  log: {
    level: process.env.LOG_LEVEL || 'info',
  },
  db: {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    name: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    pool: {
      min: parseInt(process.env.DB_POOL_MIN, 10) || 2,
      max: parseInt(process.env.DB_POOL_MAX, 10) || 10,
    },
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '24h',
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW, 10) || 15 * 60 * 1000,
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },
};

requiredEnvVars.forEach((key) => {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
});

module.exports = config;
