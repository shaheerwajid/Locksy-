#!/usr/bin/env node
/*
 * Start Block Server
 * Runs the Block Server service on port 3005 (or BLOCK_SERVER_PORT)
 */

// Set environment variables BEFORE requiring any modules
process.env.NODE_ENV = process.env.NODE_ENV || 'development';
process.env.BLOCK_SERVER_ENABLED = 'true';
process.env.BLOCK_SERVER_PORT = process.env.BLOCK_SERVER_PORT || '3005';
// Explicitly disable main server startup
process.env.USE_GATEWAY = 'false';
process.env.ENABLE_CLUSTER = 'false';
// Prevent main index.js from executing
process.env.SKIP_MAIN_SERVER = 'true';

// Start the Block Server
require('../services/block-server/index.js');
