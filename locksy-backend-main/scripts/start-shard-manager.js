#!/usr/bin/env node
/*
 * Start Shard Manager
 * Runs the Shard Manager service on port 3006 (or SHARD_MANAGER_PORT)
 */

// Set environment
process.env.NODE_ENV = process.env.NODE_ENV || 'development';
process.env.ENABLE_FEED_GENERATION = 'true';

// Start the server
require('../services/shard-manager/index.js');


