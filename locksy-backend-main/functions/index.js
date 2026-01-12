/*
 * Serverless Functions Layer
 * Cross-cutting concerns that intercept requests
 * Implements: Authentication, Authorization, Caching, Transformation, 
 *             Rate Limiting, Reverse Proxy, Monitoring, Logging
 */

const authFunction = require('./authFunction');
const authorizeFunction = require('./authorizeFunction');
const cacheFunction = require('./cacheFunction');
const transformFunction = require('./transformFunction');
const reverseProxyFunction = require('./reverseProxyFunction');
const monitorFunction = require('./monitorFunction');
const loggerFunction = require('./loggerFunction');

module.exports = {
    authFunction,
    authorizeFunction,
    cacheFunction,
    transformFunction,
    reverseProxyFunction,
    monitorFunction,
    loggerFunction
};

