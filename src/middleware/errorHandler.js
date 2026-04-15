const logger = require('../config/logger');

const errorHandler = (err, req, res, next) => {
  logger.error('Error middleware', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  const statusCode = err.statusCode || 500;
  const message = process.env.NODE_ENV === 'production'
    ? 'Internal server error'
    : err.message;

  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
};

const notFound = (req, res) => {
  res.status(404).json({
    error: `Route ${req.method} ${req.path} not found`,
  });
};

module.exports = { errorHandler, notFound };
