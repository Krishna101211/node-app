const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    message: 'API is running',
    version: process.env.npm_package_version || '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
