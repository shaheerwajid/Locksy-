#!/usr/bin/env node
/*
 * Start Data Warehouse Service
 * Runs the Data Warehouse service on port 3009 (or WAREHOUSE_PORT)
 */

// Set environment variables BEFORE requiring any modules
process.env.NODE_ENV = process.env.NODE_ENV || 'development';
process.env.WAREHOUSE_PORT = process.env.WAREHOUSE_PORT || '3009';
process.env.ENABLE_SCHEDULER = 'true';
// Explicitly disable main server startup
process.env.USE_GATEWAY = 'false';
process.env.ENABLE_CLUSTER = 'false';
// Prevent main index.js from executing
process.env.SKIP_MAIN_SERVER = 'true';

// Add error handlers to keep process alive
process.on('uncaughtException', (error) => {
  console.error('Data Warehouse: Uncaught Exception:', error);
  // Don't exit - keep the service running
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Data Warehouse: Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit - keep the service running
});

// Start the Data Warehouse server
try {
  require('../services/warehouse/index.js');
} catch (error) {
  console.error('Data Warehouse: Failed to start:', error);
  // Keep process alive to see the error
  process.stdin.resume();
}


