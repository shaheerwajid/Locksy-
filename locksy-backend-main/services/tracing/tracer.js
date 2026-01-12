/*
 * OpenTelemetry Tracer Setup
 * Initializes distributed tracing
 */

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

let sdk = null;
let initialized = false;

/**
 * Initialize OpenTelemetry tracing
 */
function initializeTracing() {
  if (initialized) {
    return;
  }

  try {
    const jaegerHost = process.env.JAEGER_HOST || 'localhost';
    const jaegerPort = parseInt(process.env.JAEGER_PORT || '6831');
    const serviceName = process.env.SERVICE_NAME || 'locksy-backend';

    // Create Jaeger exporter
    const jaegerExporter = new JaegerExporter({
      endpoint: `http://${jaegerHost}:14268/api/traces`,
      // For UDP (default)
      // host: jaegerHost,
      // port: jaegerPort
    });

    // Create SDK
    sdk = new NodeSDK({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: serviceName,
        [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      }),
      traceExporter: jaegerExporter,
      instrumentations: [
        getNodeAutoInstrumentations({
          // Disable some instrumentations if needed
          '@opentelemetry/instrumentation-fs': {
            enabled: false, // Disable file system instrumentation
          },
        }),
      ],
    });

    // Start SDK
    sdk.start();
    initialized = true;
    console.log('Tracing: OpenTelemetry initialized');
  } catch (error) {
    console.warn('Tracing: Failed to initialize OpenTelemetry:', error.message);
  }
}

/**
 * Shutdown tracing
 */
async function shutdownTracing() {
  if (sdk) {
    await sdk.shutdown();
    sdk = null;
    initialized = false;
    console.log('Tracing: Shutdown complete');
  }
}

/**
 * Get tracer
 * @param {string} name - Tracer name
 * @returns {Object} Tracer instance
 */
function getTracer(name = 'locksy-backend') {
  const { trace } = require('@opentelemetry/api');
  return trace.getTracer(name);
}

module.exports = {
  initializeTracing,
  shutdownTracing,
  getTracer
};


