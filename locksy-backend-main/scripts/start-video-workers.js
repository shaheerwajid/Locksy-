#!/usr/bin/env node
/*
 * Start Video Processing Workers
 * Starts 3 worker instances for video processing
 */

const cluster = require('cluster');
const numWorkers = parseInt(process.env.VIDEO_WORKER_COUNT || '3');

if (cluster.isMaster) {
  console.log(`Starting ${numWorkers} video processing workers...`);

  for (let i = 0; i < numWorkers; i++) {
    const worker = cluster.fork({
      WORKER_ID: `video-worker-${i + 1}`,
      HEALTH_PORT: 3007 + i
    });

    worker.on('exit', (code, signal) => {
      console.log(`Video worker ${worker.process.pid} exited with code ${code} and signal ${signal}`);
      // Restart worker
      const newWorker = cluster.fork({
        WORKER_ID: `video-worker-${i + 1}`,
        HEALTH_PORT: 3007 + i
      });
      console.log(`Video worker restarted: ${newWorker.process.pid}`);
    });
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`Video worker ${worker.process.pid} died`);
  });
} else {
  // Worker process
  require('../services/video/worker.js');
}


