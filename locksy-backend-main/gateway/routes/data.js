/*
 * Data Path Routes
 * Routes file/data operations to Block Server
 * Handles: File uploads, downloads, media processing
 */

const express = require('express');
const router = express.Router();
const config = require('../../config');
const { createProxyMiddleware } = require('http-proxy-middleware');

// Check if Block Server is enabled
const useBlockServer = config.services.blockServer.enabled;
const blockServerUrl = config.services.blockServer.url;

if (useBlockServer) {
  // Proxy all file operations to Block Server
  const proxyOptions = {
    target: blockServerUrl,
    changeOrigin: true,
    pathRewrite: {
      '^/api/archivos': '/api/archivos' // Keep /api/archivos prefix
    },
    onError: (err, req, res) => {
      console.error('Block Server proxy error:', err.message);
      // If Block Server is unavailable, return error
      if (!res.headersSent) {
        res.status(503).json({
          ok: false,
          msg: 'Block Server unavailable',
          fallback: 'Set BLOCK_SERVER_ENABLED=false to use direct routes'
        });
      }
    },
    onProxyReq: (proxyReq, req, res) => {
      // Forward request ID if present
      if (req.requestId) {
        proxyReq.setHeader('X-Request-ID', req.requestId);
      }
      // Forward user ID if present (from JWT middleware)
      if (req.uid) {
        proxyReq.setHeader('X-User-ID', req.uid);
      }
    },
    logLevel: 'warn'
  };

  // Create proxy middleware
  const blockProxy = createProxyMiddleware(proxyOptions);

  // Proxy all /api/archivos routes to Block Server
  router.use('/api/archivos', blockProxy);
} else {
  // Direct routes (backward compatibility - Block Server disabled)
  console.log('Block Server disabled, using direct routes');

  // File upload and management routes
  router.use('/', require('../../routes/uploads'));
}

// CDN URL generation endpoint
router.get('/cdn-url/:filePath(*)', (req, res) => {
  try {
    const cdnService = require('../../services/cdn/cdnService');
    const filePath = req.params.filePath;
    
    if (!cdnService.isEnabled()) {
      return res.status(404).json({
        ok: false,
        msg: 'CDN not enabled'
      });
    }

    const cdnUrl = cdnService.getCDNUrl(filePath);
    if (!cdnUrl) {
      return res.status(404).json({
        ok: false,
        msg: 'Could not generate CDN URL'
      });
    }

    res.json({
      ok: true,
      url: cdnUrl,
      filePath
    });
  } catch (error) {
    console.error('Error generating CDN URL:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar URL de CDN'
    });
  }
});

module.exports = router;

