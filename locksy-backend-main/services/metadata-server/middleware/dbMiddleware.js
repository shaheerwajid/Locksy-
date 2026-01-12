/*
 * Database Middleware for Metadata Server
 * Handles database connection and read preferences
 */

const mongoose = require('mongoose');

/**
 * Middleware to ensure database connection
 */
const ensureDbConnection = (req, res, next) => {
  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      ok: false,
      msg: 'Database not connected'
    });
  }
  next();
};

/**
 * Middleware to set read preference for queries
 * Uses secondaryPreferred for reads (will use primary if no secondaries available)
 */
const setReadPreference = (preference = 'secondaryPreferred') => {
  return (req, res, next) => {
    // Store read preference in request for use in controllers
    req.readPreference = preference;
    next();
  };
};

module.exports = {
  ensureDbConnection,
  setReadPreference
};


