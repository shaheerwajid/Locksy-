/*
 * CDN Static File Middleware
 * Redirects static file requests to CDN when enabled
 */

const cdnService = require('../services/cdn/cdnService');

/**
 * Middleware to serve static files from CDN or fallback to local
 */
function cdnStaticMiddleware(req, res, next) {
  // Only handle static file requests
  const staticPaths = ['/public/', '/CryptoChatfiles/', '/uploads/'];
  const isStaticRequest = staticPaths.some(path => req.path.startsWith(path));

  if (!isStaticRequest) {
    return next();
  }

  // If CDN is enabled, redirect to CDN URL
  if (cdnService.isEnabled()) {
    const cdnUrl = cdnService.getCDNUrl(req.path);
    if (cdnUrl) {
      // Redirect to CDN
      return res.redirect(301, cdnUrl);
    }
  }

  // Fallback to local serving (next middleware will handle it)
  next();
}

/**
 * Middleware to inject CDN URLs into HTML responses
 */
function injectCDNUrls(req, res, next) {
  if (!cdnService.isEnabled()) {
    return next();
  }

  // Only process HTML responses
  const originalSend = res.send;
  res.send = function(body) {
    if (typeof body === 'string' && res.get('Content-Type')?.includes('text/html')) {
      // Replace static asset URLs with CDN URLs
      body = body.replace(
        /(href|src)=["'](\/public\/[^"']+)["']/g,
        (match, attr, path) => {
          const cdnUrl = cdnService.getCDNUrl(path);
          return cdnUrl ? `${attr}="${cdnUrl}"` : match;
        }
      );
    }
    return originalSend.call(this, body);
  };

  next();
}

module.exports = {
  cdnStaticMiddleware,
  injectCDNUrls
};


