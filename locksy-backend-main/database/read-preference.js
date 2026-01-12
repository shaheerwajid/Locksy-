/*
 * MongoDB Read Preference Configuration
 * Configures read preferences for replica set
 */

const mongoose = require('mongoose');

/**
 * Configure read preferences for queries
 * @param {string} preference - Read preference: 'primary', 'primaryPreferred', 'secondary', 'secondaryPreferred', 'nearest'
 */
function configureReadPreference(preference = 'secondaryPreferred') {
  // Set default read preference for all queries
  mongoose.set('readPreference', preference);

  // For writes, always use primary
  // This is handled automatically by Mongoose when using write operations

  return {
    readPreference: preference,
    // Write operations always go to primary (default behavior)
    writeConcern: {
      w: 'majority', // Wait for majority of replica set members
      j: true // Journal write acknowledgment
    }
  };
}

/**
 * Get read preference for specific operation
 * @param {string} operation - Operation type: 'read' or 'write'
 * @param {string} defaultPreference - Default read preference
 */
function getReadPreference(operation = 'read', defaultPreference = 'secondaryPreferred') {
  if (operation === 'write') {
    return 'primary'; // Writes always go to primary
  }
  return defaultPreference;
}

module.exports = {
  configureReadPreference,
  getReadPreference
};


