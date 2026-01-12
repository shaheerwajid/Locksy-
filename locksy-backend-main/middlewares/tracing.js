/*
 * Tracing Middleware
 * Adds distributed tracing to HTTP requests
 */

const { trace, context } = require('@opentelemetry/api');
const { getTracer } = require('../services/tracing/tracer');
const { propagation } = require('@opentelemetry/api');

/**
 * Tracing middleware
 */
const tracingMiddleware = (req, res, next) => {
  const tracer = getTracer('locksy-http');

  // Extract trace context from headers
  const parentContext = propagation.extract(context.active(), req.headers);
  
  // Start span
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    kind: 1, // SERVER
    attributes: {
      'http.method': req.method,
      'http.url': req.url,
      'http.route': req.path,
      'http.user_agent': req.get('user-agent') || '',
    }
  }, parentContext);

  // Set span context
  context.with(trace.setSpan(context.active(), span), () => {
    // Add trace ID to response headers
    const spanContext = span.spanContext();
    if (spanContext.traceId) {
      res.setHeader('X-Trace-ID', spanContext.traceId);
    }

    // Add request ID to span
    if (req.requestId) {
      span.setAttribute('request.id', req.requestId);
    }

    // Add user ID to span if authenticated
    if (req.uid) {
      span.setAttribute('user.id', req.uid);
    }

    // End span when response finishes
    res.on('finish', () => {
      span.setAttribute('http.status_code', res.statusCode);
      span.setStatus({
        code: res.statusCode >= 400 ? 2 : 1, // ERROR or OK
        message: res.statusMessage
      });
      span.end();
    });

    next();
  });
};

module.exports = tracingMiddleware;


