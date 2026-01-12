/*
 * File Service
 * High-level file operations service
 */

const { getStorageClient } = require('./storageClient');
const path = require('path');
const crypto = require('crypto');

class FileService {
  constructor() {
    this.storage = getStorageClient();
    this.chunkSize = 10 * 1024 * 1024; // 10MB chunks for large files
  }

  /**
   * Upload file
   */
  async uploadFile(file, folder = 'general', options = {}) {
    try {
      // Generate unique filename
      const fileExtension = path.extname(file.originalname);
      const fileName = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${fileExtension}`;
      const destinationPath = path.join(folder, fileName);

      // Upload file
      const result = await this.storage.uploadFile(
        file.path,
        destinationPath,
        {
          contentType: file.mimetype,
          ...options,
        }
      );

      return {
        ...result,
        originalName: file.originalname,
        size: file.size,
        mimetype: file.mimetype,
      };
    } catch (error) {
      console.error('FileService: Upload failed', error.message);
      throw error;
    }
  }

  /**
   * Upload large file in chunks (for files > 10MB)
   * Uses Block Server for chunked uploads
   */
  async uploadLargeFile(file, folder = 'general', options = {}) {
    if (file.size <= this.chunkSize) {
      // File is small enough, use regular upload
      return this.uploadFile(file, folder, options);
    }

    // Use Block Server for chunked upload
    const blockServer = require('./blockServer');
    const fs = require('fs').promises;
    const crypto = require('crypto');

    try {
      // Initialize chunked upload
      const { uploadId, totalChunks, chunkSize } = blockServer.initializeChunkedUpload(
        file.originalname,
        file.size,
        file.mimetype
      );

      // Read file and upload chunks in parallel
      const fileHandle = await fs.open(file.path, 'r');
      const buffer = Buffer.alloc(chunkSize);
      const uploadPromises = [];

      for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        const bytesRead = await fileHandle.read(buffer, 0, chunkSize, chunkIndex * chunkSize);
        
        if (bytesRead.bytesRead === 0) {
          break;
        }

        const chunkData = buffer.slice(0, bytesRead.bytesRead);
        const chunkHash = crypto.createHash('md5').update(chunkData).digest('hex');

        // Upload chunk (can be done in parallel)
        uploadPromises.push(
          blockServer.uploadChunk(uploadId, chunkIndex, chunkData, chunkHash)
        );
      }

      await fileHandle.close();

      // Wait for all chunks to upload
      await Promise.all(uploadPromises);

      // Complete upload and reassemble
      const result = await blockServer.completeChunkedUpload(uploadId, folder);

      // Clean up original file
      try {
        await fs.unlink(file.path);
      } catch (err) {
        console.warn('FileService: Could not delete original file:', err.message);
      }

      return result;
    } catch (error) {
      console.error('FileService: Chunked upload failed:', error.message);
      // Fallback to regular upload on error
      console.warn('FileService: Falling back to regular upload');
      return this.uploadFile(file, folder, options);
    }
  }

  /**
   * Delete file
   */
  async deleteFile(filePath) {
    try {
      return await this.storage.deleteFile(filePath);
    } catch (error) {
      console.error('FileService: Delete failed', error.message);
      throw error;
    }
  }

  /**
   * Get file URL (with CDN support)
   */
  getFileUrl(filePath) {
    const storageUrl = this.storage.getFileUrl(filePath);
    
    // Try to get CDN URL
    try {
      const cdnService = require('../cdn/cdnService');
      if (cdnService.isEnabled()) {
        const cdnUrl = cdnService.getFileUrl(filePath, storageUrl);
        return cdnUrl;
      }
    } catch (error) {
      // CDN service not available, use storage URL
    }

    return storageUrl;
  }

  /**
   * Get presigned URL
   */
  async getPresignedUrl(filePath, expiresIn = 3600) {
    return await this.storage.getPresignedUrl(filePath, expiresIn);
  }

  /**
   * Check if file exists
   */
  async fileExists(filePath) {
    return await this.storage.fileExists(filePath);
  }

  /**
   * Get file path for different types
   */
  getFilePath(type, fileName) {
    const folders = {
      image: 'images',
      video: 'videos',
      document: 'documents',
      audio: 'audio',
      thumbnail: 'thumbnails',
    };

    const folder = folders[type] || 'general';
    return path.join(folder, fileName);
  }
}

// Export singleton instance
const fileService = new FileService();
module.exports = fileService;

