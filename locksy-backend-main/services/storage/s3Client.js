/*
 * AWS S3 Storage Client
 */

const AWS = require('aws-sdk');
const config = require('../../config');
const fs = require('fs').promises;

class S3Client {
  constructor() {
    const s3Config = config.storage.s3;

    AWS.config.update({
      accessKeyId: s3Config.accessKeyId,
      secretAccessKey: s3Config.secretAccessKey,
      region: s3Config.region,
    });

    this.s3 = new AWS.S3();
    this.bucket = s3Config.bucket;
  }

  /**
   * Upload file
   */
  async uploadFile(filePath, destinationPath, options = {}) {
    try {
      const fileContent = await fs.readFile(filePath);
      
      const params = {
        Bucket: this.bucket,
        Key: destinationPath,
        Body: fileContent,
        ContentType: options.contentType || 'application/octet-stream',
        ...options.metadata && { Metadata: options.metadata },
      };

      const result = await this.s3.upload(params).promise();

      return {
        success: true,
        path: destinationPath,
        url: result.Location,
        key: result.Key,
      };
    } catch (error) {
      console.error('S3: Upload failed', error.message);
      throw error;
    }
  }

  /**
   * Delete file
   */
  async deleteFile(filePath) {
    try {
      await this.s3.deleteObject({
        Bucket: this.bucket,
        Key: filePath,
      }).promise();

      return { success: true };
    } catch (error) {
      console.error('S3: Delete failed', error.message);
      throw error;
    }
  }

  /**
   * Get file URL (with CDN support)
   */
  getFileUrl(filePath) {
    const s3Url = `https://${this.bucket}.s3.${config.storage.s3.region}.amazonaws.com/${filePath}`;
    
    // Check if CDN is enabled
    try {
      const cdnService = require('../cdn/cdnService');
      if (cdnService.isEnabled()) {
        return cdnService.getFileUrl(filePath, s3Url);
      }
    } catch (error) {
      // CDN service not available, use S3 URL
    }

    return s3Url;
  }

  /**
   * Generate presigned URL
   */
  async getPresignedUrl(filePath, expiresIn = 3600) {
    try {
      const params = {
        Bucket: this.bucket,
        Key: filePath,
        Expires: expiresIn,
      };

      return await this.s3.getSignedUrlPromise('getObject', params);
    } catch (error) {
      console.error('S3: Failed to generate presigned URL', error.message);
      return this.getFileUrl(filePath);
    }
  }

  /**
   * Check if file exists
   */
  async fileExists(filePath) {
    try {
      await this.s3.headObject({
        Bucket: this.bucket,
        Key: filePath,
      }).promise();
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
      const params = {
        Bucket: this.bucket,
        Key: filePath,
      };

      const result = await this.s3.getObject(params).promise();
      return result.Body;
    } catch (error) {
      console.error('S3: Download failed', error.message);
      throw error;
    }
  }

  /**
   * Check if storage is connected
   */
  isConnected() {
    // S3 client is always "connected" (connection is made per request)
    return true;
  }
}

module.exports = S3Client;

