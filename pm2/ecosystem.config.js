module.exports = {
  apps: [
    {
      name: 'my-app',
      script: './src/index.js',
      instances: 'max',
      exec_mode: 'cluster',
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
        LOG_LEVEL: 'debug'
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
        LOG_LEVEL: 'info'
      },
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3000,
        LOG_LEVEL: 'debug'
      },
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: '/opt/app/logs/error.log',
      out_file: '/opt/app/logs/out.log',
      merge_logs: true,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 4000,
      watch: false,
      min_uptime: '10s',
      listen_timeout: 10000,
      kill_timeout: 5000,
      shutdown_with_message: true,
      cron_restart: '0 3 * * 0'
    }
  ]
};
