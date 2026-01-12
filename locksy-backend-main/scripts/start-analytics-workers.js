#!/usr/bin/env node
/*
 * Start Analytics Workers
 * Starts analytics worker instances
 */

const cluster = require('cluster');
const numWorkers = parseInt(process.env.ANALYTICS_WORKER_COUNT || '2');

if (cluster.isMaster) {
  console.log(`Starting ${numWorkers} analytics workers...`);

  for (let i = 0; i < numWorkers; i++) {
    const worker = cluster.fork({
      WORKER_ID: `analytics-worker-${i + 1}`,
      HEALTH_PORT: 3008 + i
    });

    worker.on('exit', (code, signal) => {
      console.log(`Analytics worker ${worker.process.pid} exited with code ${code} and signal ${signal}`);
      // Restart worker
      const newWorker = cluster.fork({
        WORKER_ID: `analytics-worker-${i + 1}`,
        HEALTH_PORT: 3008 + i
      });
      console.log(`Analytics worker restarted: ${newWorker.process.pid}`);
    });
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`Analytics worker ${worker.process.pid} died`);
  });
} else {
  // Worker process
  require('../services/analytics/worker.js');
}


