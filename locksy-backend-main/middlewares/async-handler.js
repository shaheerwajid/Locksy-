/**
 * Async Handler Middleware
 * Wraps async route handlers to catch errors and prevent connection closures
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch((error) => {
      // Don't send response if headers already sent
      if (res.headersSent) {
        return next(error);
      }

      console.error('Async handler error:', error);
      
      // Log error with context
      if (req.logger) {
        req.logger.error('Unhandled async error', {
          error: error.message,
          stack: error.stack,
          path: req.path,
          method: req.method
        });
      }

      const statusCode = error.status || error.statusCode || 500;
      res.status(statusCode).json({
        ok: false,
        msg: error.message || 'Internal server error',
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    });
  };
};

module.exports = asyncHandler;


