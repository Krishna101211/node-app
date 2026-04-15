const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const config = require('./config');
const logger = require('./config/logger');
const healthRoute = require('./routes/health');
const apiRoute = require('./routes/api');

const app = express();

app.use(helmet());
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", "data:", "https:"],
  },
}));

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['https://yourdomain.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(compression());
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

app.use(rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  message: { error: 'Too many requests, please try again later.' },
}));

if (config.env !== 'test') {
  app.use(morgan('combined', { stream: { write: (msg) => logger.info(msg.trim()) } }));
}

app.use('/health', healthRoute);
app.use('/api', apiRoute);

app.use((err, req, res, _next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(err.status || 500).json({
    error: config.env === 'production' ? 'Internal server error' : err.message,
  });
});

const server = app.listen(config.port, () => {
  logger.info(`Server running on port ${config.port} in ${config.env} mode`);
});

const shutdown = (signal) => {
  logger.info(`${signal} received. Starting graceful shutdown...`);

  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });

  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('message', (msg) => {
  if (msg === 'shutdown') {
    shutdown('PM2 shutdown');
  }
});

module.exports = { app, server };
