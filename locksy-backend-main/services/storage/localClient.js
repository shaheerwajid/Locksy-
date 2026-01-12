/*
 * Local File Storage Client
 * Stores files on local filesystem (fallback/default)
 */

const fs = require('fs').promises;
const path = require('path');

class LocalClient {
  constructor() {
    this.uploadDir = path.join(process.cwd(), 'uploads');
    this.ensureUploadDir();
  }

  async ensureUploadDir() {
    try {
      await fs.mkdir(this.uploadDir, { recursive: true });
    } catch (error) {
      console.error('LocalStorage: Failed to create upload directory', error.message);
    }
  }

  /**
   * Upload file
   */
  async uploadFile(filePath, destinationPath, options = {}) {
    try {
      const fullDestinationPath = path.join(this.uploadDir, destinationPath);
      const destinationDir = path.dirname(fullDestinationPath);

      // Ensure directory exists
      await fs.mkdir(destinationDir, { recursive: true });

      // Copy file
      await fs.copyFile(filePath, fullDestinationPath);

      return {
        success: true,
        path: destinationPath,
        url: `/uploads/${destinationPath}`,
      };
    } catch (error) {
      console.error('LocalStorage: Upload failed', error.message);
      throw error;
    }
  }

  /**
   * Delete file
   */
  async deleteFile(filePath) {
    try {
      const fullPath = path.join(this.uploadDir, filePath);
      await fs.unlink(fullPath);
      return { success: true };
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.error('LocalStorage: Delete failed', error.message);
        throw error;
      }
      return { success: true }; // File doesn't exist, consider it deleted
    }
  }

  /**
   * Get file URL
   */
  getFileUrl(filePath) {
    // Check if CDN is enabled
    try {
      const cdnService = require('../cdn/cdnService');
      if (cdnService.isEnabled()) {
        return cdnService.getFileUrl(filePath, `/uploads/${filePath}`);
      }
    } catch (error) {
      // CDN service not available, use local URL
    }

    return `/uploads/${filePath}`;
  }

  /**
   * Generate presigned URL (not applicable for local storage)
   */
  async getPresignedUrl(filePath, expiresIn = 3600) {
    // For local storage, return direct URL
    return this.getFileUrl(filePath);
  }

  /**
   * Check if file exists
   */
  async fileExists(filePath) {
    try {
      const fullPath = path.join(this.uploadDir, filePath);
      await fs.access(fullPath);
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
      const fullPath = path.join(this.uploadDir, filePath);
      return await fs.readFile(fullPath);
    } catch (error) {
      console.error('LocalStorage: Download failed', error.message);
      throw error;
    }
  }

  /**
   * Check if storage is connected
   */
  isConnected() {
    return true; // Local storage is always available
  }
}

module.exports = LocalClient;

