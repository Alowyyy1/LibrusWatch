module.exports = {
  apps: [
    {
      name: "librus-backend",
      cwd: "/home/alowyy1/librus-watch/backend",
      script: "/home/alowyy1/librus-watch/venv/bin/uvicorn",
      args: "app.main:app --host 0.0.0.0 --port 8095",
      interpreter: "none",
      restart_delay: 3000,
      max_restarts: 10,
      env: {
        DATABASE_URL: "sqlite:///./librus_watch.db",
        ENCRYPTION_KEY: "librus-watch-secret-key-32bytes-long",
        JWT_SECRET: "librus-watch-jwt-secret-secure"
      }
    }
  ]
};
