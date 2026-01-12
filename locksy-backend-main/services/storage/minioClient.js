/*
 * MinIO Storage Client
 * Compatible with S3 API, used for local development
 */

const MinIO = require('minio');
const config = require('../../config');
const fs = require('fs').promises;

class MinIOClient {
  constructor() {
    const minioConfig = config.storage.minio;
    
    this.client = new MinIO.Client({
      endPoint: minioConfig.endpoint,
      port: minioConfig.port,
      useSSL: false,
      accessKey: minioConfig.accessKey,
      secretKey: minioConfig.secretKey,
    });

    this.bucket = minioConfig.bucket;
    this.ensureBucket();
  }

  /**
   * Ensure bucket exists
   */
  async ensureBucket() {
    try {
      const exists = await this.client.bucketExists(this.bucket);
      if (!exists) {
        await this.client.makeBucket(this.bucket, 'us-east-1');
        console.log(`MinIO: Created bucket ${this.bucket}`);
      }
    } catch (error) {
      console.error('MinIO: Failed to ensure bucket', error.message);
    }
  }

  /**
   * Upload file
   */
  async uploadFile(filePath, destinationPath, options = {}) {
    try {
      const fileContent = await fs.readFile(filePath);
      const metaData = options.contentType ? { 'Content-Type': options.contentType } : {};

      await this.client.putObject(
        this.bucket,
        destinationPath,
        fileContent,
        fileContent.length,
        metaData
      );

      return {
        success: true,
        path: destinationPath,
        url: await this.getPresignedUrl(destinationPath),
      };
    } catch (error) {
      console.error('MinIO: Upload failed', error.message);
      throw error;
    }
  }

  /**
   * Delete file
   */
  async deleteFile(filePath) {
    try {
      await this.client.removeObject(this.bucket, filePath);
      return { success: true };
    } catch (error) {
      console.error('MinIO: Delete failed', error.message);
      throw error;
    }
  }

  /**
   * Get file URL (with CDN support)
   */
  getFileUrl(filePath) {
    const minioUrl = `http://${config.storage.minio.endpoint}:${config.storage.minio.port}/${this.bucket}/${filePath}`;
    
    // Check if CDN is enabled
    try {
      const cdnService = require('../cdn/cdnService');
      if (cdnService.isEnabled()) {
        return cdnService.getFileUrl(filePath, minioUrl);
      }
    } catch (error) {
      // CDN service not available, use MinIO URL
    }

    return minioUrl;
  }

  /**
   * Generate presigned URL
   */
  async getPresignedUrl(filePath, expiresIn = 3600) {
    try {
      return await this.client.presignedGetObject(this.bucket, filePath, expiresIn);
    } catch (error) {
      console.error('MinIO: Failed to generate presigned URL', error.message);
      return this.getFileUrl(filePath);
    }
  }

  /**
   * Check if file exists
   */
  async fileExists(filePath) {
    try {
      await this.client.statObject(this.bucket, filePath);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Download file
   */
  async downloadFile(filePath) {
    try {
      return await this.client.getObject(this.bucket, filePath);
    } catch (error) {
      console.error('MinIO: Download failed', error.message);
      throw error;
    }
  }

  /**
   * Check if storage is connected
   */
  isConnected() {
    // MinIO client connection is checked per request
    return true;
  }
}

module.exports = MinIOClient;

