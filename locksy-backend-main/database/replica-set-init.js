/*
 * MongoDB Replica Set Initialization Script
 * Run this script to initialize a MongoDB replica set
 * Usage: mongo <connection-string> < this-file.js
 * Or: mongosh <connection-string> --file this-file.js
 */

// Initialize replica set
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: 'mongodb-primary:27017' },
    { _id: 1, host: 'mongodb-secondary1:27017' },
    { _id: 2, host: 'mongodb-secondary2:27017' }
  ]
});

// Wait for replica set to be ready
sleep(5000);

// Check replica set status
rs.status();


