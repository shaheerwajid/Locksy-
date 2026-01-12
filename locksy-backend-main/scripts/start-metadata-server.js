#!/usr/bin/env node
/*
 * Start Metadata Server
 * Runs the Metadata Server service on port 3004 (or METADATA_SERVER_PORT)
 */

// Set environment variables BEFORE requiring any modules
process.env.NODE_ENV = process.env.NODE_ENV || 'development';
process.env.METADATA_SERVER_ENABLED = 'true';
process.env.METADATA_SERVER_PORT = process.env.METADATA_SERVER_PORT || '3004';
// Explicitly disable main server startup
process.env.USE_GATEWAY = 'false';
process.env.ENABLE_CLUSTER = 'false';
// Prevent main index.js from executing
process.env.SKIP_MAIN_SERVER = 'true';

// Start the Metadata Server
require('../services/metadata-server/index.js');


