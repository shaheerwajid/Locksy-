/*
 * Span Manager
 * Manages spans for tracing
 */

const { trace, context } = require('@opentelemetry/api');
const { getTracer } = require('./tracer');

class SpanManager {
  /**
   * Create span
   * @param {string} name - Span name
   * @param {Object} options - Span options
   * @returns {Object} Span
   */
  createSpan(name, options = {}) {
    const tracer = getTracer(options.tracerName || 'locksy-backend');
    return tracer.startSpan(name, options);
  }

  /**
   * Execute function within span
   * @param {string} spanName - Span name
   * @param {Function} fn - Function to execute
   * @param {Object} options - Span options
   * @returns {Promise<*>} Function result
   */
  async executeInSpan(spanName, fn, options = {}) {
    const tracer = getTracer(options.tracerName || 'locksy-backend');
    const span = tracer.startSpan(spanName, options);

    try {
      const result = await context.with(trace.setSpan(context.active(), span), async () => {
        return await fn(span);
      });

      span.setStatus({ code: 1 }); // OK
      return result;
    } catch (error) {
      span.setStatus({ code: 2, message: error.message }); // ERROR
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  }

  /**
   * Add span attributes
   * @param {Object} span - Span object
   * @param {Object} attributes - Attributes to add
   */
  addAttributes(span, attributes) {
    if (span && attributes) {
      for (const [key, value] of Object.entries(attributes)) {
        span.setAttribute(key, value);
      }
    }
  }

  /**
   * Add span event
   * @param {Object} span - Span object
   * @param {string} name - Event name
   * @param {Object} attributes - Event attributes
   */
  addEvent(span, name, attributes = {}) {
    if (span) {
      span.addEvent(name, attributes);
    }
  }
}

// Export singleton instance
const spanManager = new SpanManager();
module.exports = spanManager;


