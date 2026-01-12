/*
 * Centralized Configuration Management
 * Loads and validates environment variables
 */

require('dotenv').config();

const config = {
  // Server Configuration
  server: {
    port: parseInt(process.env.PORT || '3000'),
    nodeEnv: process.env.NODE_ENV || 'development',
    enableCluster: process.env.ENABLE_CLUSTER === 'true',
    useGateway: process.env.USE_GATEWAY !== 'false', // Default to true
    workerPortOffset: parseInt(process.env.WORKER_PORT_OFFSET || '0')
  },

  // Service Configuration
  services: {
    metadataServer: {
      enabled: process.env.METADATA_SERVER_ENABLED !== 'false', // Default to true
      port: parseInt(process.env.METADATA_SERVER_PORT || '3004'),
      host: process.env.METADATA_SERVER_HOST || 'localhost',
      url: process.env.METADATA_SERVER_URL || `http://localhost:${parseInt(process.env.METADATA_SERVER_PORT || '3004')}`
    },
    blockServer: {
      enabled: process.env.BLOCK_SERVER_ENABLED !== 'false', // Default to true
      port: parseInt(process.env.BLOCK_SERVER_PORT || '3005'),
      host: process.env.BLOCK_SERVER_HOST || 'localhost',
      url: process.env.BLOCK_SERVER_URL || `http://localhost:${parseInt(process.env.BLOCK_SERVER_PORT || '3005')}`
    }
  },

  // Database Configuration
  database: {
    connectionString: process.env.DB_CNN || 'mongodb://localhost:27017/cryptochat'
  },

  // Redis Configuration
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379'),
    password: process.env.REDIS_PASSWORD || undefined,
    url: process.env.REDIS_URL || undefined
  },

  // Message Queue Configuration
  queue: {
    rabbitmq: {
      url: process.env.RABBITMQ_URL || 'amqp://localhost:5672',
      user: process.env.RABBITMQ_USER || 'guest',
      password: process.env.RABBITMQ_PASSWORD || 'guest'
    }
  },

  // File Storage Configuration
  storage: {
    type: process.env.STORAGE_TYPE || 'local', // local, s3, gcs, minio
    s3: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      region: process.env.AWS_REGION || 'us-east-1',
      bucket: process.env.AWS_S3_BUCKET
    },
    gcs: {
      projectId: process.env.GCS_PROJECT_ID,
      keyFile: process.env.GCS_KEY_FILE,
      bucket: process.env.GCS_BUCKET
    },
    minio: {
      endpoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: parseInt(process.env.MINIO_PORT || '9000'),
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
      bucket: process.env.MINIO_BUCKET || 'cryptochat'
    }
  },

  // CDN Configuration
  cdn: {
    enabled: process.env.CDN_ENABLED === 'true',
    baseUrl: process.env.CDN_BASE_URL || ''
  },

  // JWT Configuration
  jwt: {
    secret: process.env.JWT_KEY || 'default-secret-change-in-production'
  },

  // Firebase Configuration
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKey: process.env.FIREBASE_PRIVATE_KEY,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL
  },

  // Elasticsearch Configuration
  elasticsearch: {
    host: process.env.ELASTICSEARCH_HOST || 'localhost',
    port: parseInt(process.env.ELASTICSEARCH_PORT || '9200'),
    indexPrefix: process.env.ELASTICSEARCH_INDEX_PREFIX || 'cryptochat'
  },

  // Logging Configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/app.log'
  },

  // Monitoring Configuration
  monitoring: {
    enabled: process.env.METRICS_ENABLED !== 'false',
    prometheusPort: parseInt(process.env.PROMETHEUS_PORT || '9090')
  },

  // Email Configuration
  email: {
    host: process.env.EMAIL_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.EMAIL_PORT || '587'),
    user: process.env.EMAIL_USER,
    password: process.env.EMAIL_PASSWORD
  },

  // Security Configuration
  security: {
    rateLimitEnabled: process.env.RATE_LIMIT_ENABLED !== 'false',
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '52428800'), // 50MB
    allowedFileTypes: (process.env.ALLOWED_FILE_TYPES || 'image/jpeg,image/png,image/gif,video/mp4,audio/mpeg,application/pdf').split(',')
  }
};

// Validation
function validateConfig() {
  const errors = [];

  // Required in production
  if (config.server.nodeEnv === 'production') {
    if (!config.jwt.secret || config.jwt.secret === 'default-secret-change-in-production') {
      errors.push('JWT_KEY must be set in production');
    }
    if (!config.database.connectionString) {
      errors.push('DB_CNN must be set');
    }
  }

  if (errors.length > 0) {
    console.error('Configuration errors:');
    errors.forEach(error => console.error(`  - ${error}`));
    throw new Error('Invalid configuration');
  }
}

// Validate on load
validateConfig();

module.exports = config;

