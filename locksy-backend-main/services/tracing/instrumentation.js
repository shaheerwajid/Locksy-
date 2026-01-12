/*
 * Custom Instrumentation
 * Custom spans for database, queue, and cache operations
 */

const { trace, context } = require('@opentelemetry/api');
const { getTracer } = require('./tracer');
const spanManager = require('./span-manager');

/**
 * Instrument database operation
 * @param {string} operation - Operation name
 * @param {Function} fn - Database function
 * @returns {Promise<*>} Function result
 */
async function instrumentDatabase(operation, fn) {
  return spanManager.executeInSpan(`db.${operation}`, async (span) => {
    span.setAttribute('db.operation', operation);
    return await fn();
  });
}

/**
 * Instrument queue operation
 * @param {string} queueName - Queue name
 * @param {string} operation - Operation (send, receive)
 * @param {Function} fn - Queue function
 * @returns {Promise<*>} Function result
 */
async function instrumentQueue(queueName, operation, fn) {
  return spanManager.executeInSpan(`queue.${operation}`, async (span) => {
    span.setAttribute('queue.name', queueName);
    span.setAttribute('queue.operation', operation);
    return await fn();
  });
}

/**
 * Instrument cache operation
 * @param {string} operation - Operation (get, set, delete)
 * @param {Function} fn - Cache function
 * @returns {Promise<*>} Function result
 */
async function instrumentCache(operation, fn) {
  return spanManager.executeInSpan(`cache.${operation}`, async (span) => {
    span.setAttribute('cache.operation', operation);
    return await fn();
  });
}

/**
 * Instrument storage operation
 * @param {string} operation - Operation (upload, download, delete)
 * @param {Function} fn - Storage function
 * @returns {Promise<*>} Function result
 */
async function instrumentStorage(operation, fn) {
  return spanManager.executeInSpan(`storage.${operation}`, async (span) => {
    span.setAttribute('storage.operation', operation);
    return await fn();
  });
}

module.exports = {
  instrumentDatabase,
  instrumentQueue,
  instrumentCache,
  instrumentStorage
};


