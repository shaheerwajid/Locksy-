/*
 * Control Path Routes
 * Routes metadata operations to Metadata Server
 * Handles: Users, Groups, Contacts, Messages, Auth, Requests
 */

const express = require('express');
const router = express.Router();
const config = require('../../config');
const { createProxyMiddleware, fixRequestBody } = require('http-proxy-middleware');

// Check if Metadata Server is enabled
const useMetadataServer = config.services.metadataServer.enabled;
const metadataServerUrl = config.services.metadataServer.url;

if (useMetadataServer) {
  // Proxy all metadata operations to Metadata Server
  // Router is mounted at /api in gateway, so paths come in as /search/search, /usuarios, etc.
  // Metadata Server expects /api/search/search, /api/usuarios, etc.
  // We use pathRewrite to reliably add /api prefix to all paths
  // IMPORTANT: req.path in onProxyReq shows the FULL path including mount point
  // but pathRewrite operates on the path AFTER the mount point is stripped
  // So when router receives /search/search, pathRewrite should create /api/search/search
  const proxyOptions = {
    target: metadataServerUrl,
    changeOrigin: true,
    // Add timeout to prevent hanging requests
    timeout: 30000, // 30 seconds timeout
    proxyTimeout: 30000, // 30 seconds proxy timeout
    // pathRewrite: Rewrite path to add /api prefix
    // Router receives paths like /search/search, /usuarios (without /api prefix)
    // Rewrite to /api/search/search, /api/usuarios for Metadata Server
    // Use function-based rewrite to ensure correct behavior
    // NOTE: http-proxy-middleware receives the FULL path from the gateway (including /api prefix)
    // even though Express router is mounted at /api. This is because the proxy middleware
    // operates on req.url/req.path which includes the full path.
    // So we need to check if path already has /api and use it as-is, otherwise add /api.
    pathRewrite: function (path, req) {
      // Remove query string from path if present (query string is handled separately by http-proxy-middleware)
      const pathWithoutQuery = path.split('?')[0];
      
      // Check if path already starts with /api
      if (pathWithoutQuery.startsWith('/api')) {
        // Path already has /api prefix, use it as-is
        // This handles the case where http-proxy-middleware receives the full path from gateway
        return pathWithoutQuery;
      } else {
        // Path doesn't have /api prefix, add it
        // This handles edge cases or direct calls
        return '/api' + pathWithoutQuery;
      }
    },
    onError: (err, req, res) => {
      console.error('Metadata Server proxy error:', err.message);
      console.error('Failed path:', req.path);
      console.error('Error code:', err.code);
      // If Metadata Server is unavailable, return error
      if (!res.headersSent) {
        if (err.code === 'ETIMEDOUT' || err.code === 'ECONNRESET') {
          res.status(504).json({
            ok: false,
            msg: 'Metadata Server timeout',
            error: err.message
          });
        } else {
          res.status(503).json({
            ok: false,
            msg: 'Metadata Server unavailable',
            error: err.message,
            fallback: 'Set METADATA_SERVER_ENABLED=false to use direct routes'
          });
        }
      }
    },
    onProxyReq: (proxyReq, req, res) => {
      // Forward headers FIRST (before fixRequestBody, which may modify headers)
      // Forward request ID if present
      if (req.requestId) {
        proxyReq.setHeader('X-Request-ID', req.requestId);
      }
      // Forward authentication token (CRITICAL: Metadata Server needs this to validate JWT)
      if (req.headers['x-token']) {
        proxyReq.setHeader('x-token', req.headers['x-token']);
      }
      // Forward user ID if present (from JWT middleware)
      if (req.uid) {
        proxyReq.setHeader('X-User-ID', req.uid);
      }
      
      // Forward other headers (skip host, connection)
      Object.keys(req.headers).forEach(key => {
        const lowerKey = key.toLowerCase();
        if (lowerKey !== 'host' && 
            lowerKey !== 'connection' && 
            !proxyReq.getHeader(key)) {
          proxyReq.setHeader(key, req.headers[key]);
        }
      });
      
      // CRITICAL: Preserve query string for GET requests
      // http-proxy-middleware should handle this automatically, but we ensure it's preserved
      if (req.method === 'GET' && req.url && req.url.includes('?')) {
        const queryString = req.url.substring(req.url.indexOf('?'));
        // The proxyReq.path should already include query string, but we ensure it's there
        if (!proxyReq.path.includes('?')) {
          proxyReq.path = proxyReq.path + queryString;
        }
      }
      
      // CRITICAL: Fix request body when body-parser has already parsed it
      // This must be called AFTER setting headers, and only for requests with bodies
      // fixRequestBody reconstructs the body from req.body and writes it to the proxy request
      if (req.body && (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH')) {
        try {
          fixRequestBody(proxyReq, req);
        } catch (error) {
          console.error('[Proxy] Error fixing request body:', error.message);
          // Continue without body fix - may cause issues but won't crash
        }
      }
      
      // Set timeout on proxy request
      proxyReq.setTimeout(30000); // 30 seconds
      
      // Log proxy request for debugging
      const queryString = req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : '';
      console.log(`[Proxy] ${req.method} ${req.path}${queryString} -> ${metadataServerUrl}${proxyReq.path}`);
      console.log(`[Proxy] Query params: ${JSON.stringify(req.query)}`);
      if (req.body && Object.keys(req.body).length > 0) {
        console.log(`[Proxy] Body keys: ${Object.keys(req.body).join(', ')}`);
      }
    },
    onProxyRes: (proxyRes, req, res) => {
      // Log proxy response for debugging
      console.log(`[Proxy] ${req.method} ${req.path} -> ${proxyRes.statusCode}`);
    },
    logLevel: 'warn' // Only log warnings and errors
  };

  // Authentication routes (handled directly, not by Metadata Server)
  // Mount BEFORE proxy so /login is handled first and not proxied
  router.use('/login', require('../../routes/auth'));

  // Create proxy middleware with reliable path matching
  // Filter excludes /login which is handled directly above
  const metadataProxy = createProxyMiddleware(
    (pathname, req) => {
      // Don't proxy /login (auth handled separately above)
      // pathname is relative to router mount point (/api), so /login not /api/login
      // Also exclude /login/new, /login/refresh, etc.
      if (pathname && pathname.startsWith('/login')) {
        return false; // Don't proxy, let the auth router handle it
      }
      // Proxy everything else to Metadata Server
      return true;
    },
    proxyOptions
  );

  // Proxy all other routes to Metadata Server (router is already mounted at /api in gateway)
  // This handles all /api/* routes except /api/login (and /api/login/*)
  // IMPORTANT: Mount proxy AFTER auth routes so auth routes are checked first
  router.use('/', metadataProxy);
} else {
  // Direct routes (backward compatibility - Metadata Server disabled)
  console.log('Metadata Server disabled, using direct routes');

  // Authentication routes
  router.use('/login', require('../../routes/auth'));

  // User management routes (metadata)
  router.use('/usuarios', require('../../routes/usuarios'));

  // Contact routes (metadata)
  router.use('/contactos', require('../../routes/contactos'));

  // Group routes (metadata)
  router.use('/grupos', require('../../routes/grupos'));

  // Message routes (metadata - message history, not file content)
  router.use('/mensajes', require('../../routes/mensajes'));

  // Request routes (metadata)
  router.use('/solicitudes', require('../../routes/solicitudes'));

  // Legacy PMS routes
  router.use('/pms', require('../../routes/usuarios'));
}

module.exports = router;

