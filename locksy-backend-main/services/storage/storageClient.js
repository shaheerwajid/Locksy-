/*
 * Storage Client Abstraction
 * Provides unified interface for different storage backends (S3, GCS, MinIO, Local)
 */

const config = require('../../config');

let storageClient = null;

/**
 * Initialize storage client based on configuration
 */
function initializeStorage() {
  if (storageClient) {
    return storageClient;
  }

  const storageType = config.storage.type || 'local';

  try {
    switch (storageType) {
      case 's3':
        const S3Client = require('./s3Client');
        storageClient = new S3Client();
        console.log('Storage: Initialized S3 client');
        break;

      case 'gcs':
        const GCSClient = require('./gcsClient');
        storageClient = new GCSClient();
        console.log('Storage: Initialized GCS client');
        break;

      case 'minio':
        const MinIOClient = require('./minioClient');
        storageClient = new MinIOClient();
        console.log('Storage: Initialized MinIO client');
        break;

      case 'local':
      default:
        const LocalClient = require('./localClient');
        storageClient = new LocalClient();
        console.log('Storage: Initialized Local client');
        break;
    }

    return storageClient;
  } catch (error) {
    console.error('Storage: Failed to initialize storage client', error.message);
    // Fallback to local storage
    const LocalClient = require('./localClient');
    storageClient = new LocalClient();
    return storageClient;
  }
}

/**
 * Get storage client instance
 */
function getStorageClient() {
  if (!storageClient) {
    return initializeStorage();
  }
  return storageClient;
}

/**
 * Check if storage is connected
 */
function isConnected() {
  if (!storageClient) {
    return false;
  }
  // Check if storage client has isConnected method
  if (typeof storageClient.isConnected === 'function') {
    return storageClient.isConnected();
  }
  // Default to true if method doesn't exist
  return true;
}

module.exports = {
  initializeStorage,
  getStorageClient,
  isConnected,
};

