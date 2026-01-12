/*
 * Block Server Logic
 * Manages file blocks, chunked uploads, and distributed storage
 */

const fileChunker = require('./fileChunker');
const fileService = require('./fileService');
const { getStorageClient } = require('./storageClient');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');

class BlockServer {
  constructor() {
    this.chunkSize = 10 * 1024 * 1024; // 10MB
    this.chunkMetadata = new Map(); // Store chunk upload metadata in memory (use Redis in production)
  }

  /**
   * Get storage client
   */
  getStorage() {
    return getStorageClient();
  }

  /**
   * Initialize chunked upload session
   * @param {string} fileName - Original file name
   * @param {number} fileSize - Total file size
   * @param {string} mimeType - File MIME type
   * @returns {Object} Upload session metadata
   */
  initializeChunkedUpload(fileName, fileSize, mimeType) {
    const uploadId = crypto.randomBytes(16).toString('hex');
    const totalChunks = Math.ceil(fileSize / this.chunkSize);
    const fileExtension = path.extname(fileName);

    const metadata = {
      uploadId,
      fileName,
      fileSize,
      mimeType,
      fileExtension,
      totalChunks,
      uploadedChunks: [],
      chunkSize: this.chunkSize,
      createdAt: new Date(),
      status: 'uploading'
    };

    // Store metadata (in production, use Redis)
    this.chunkMetadata.set(uploadId, metadata);

    return {
      uploadId,
      totalChunks,
      chunkSize: this.chunkSize
    };
  }

  /**
   * Upload a single chunk
   * @param {string} uploadId - Upload session ID
   * @param {number} chunkIndex - Chunk index (0-based)
   * @param {Buffer} chunkData - Chunk data
   * @param {string} chunkHash - MD5 hash of chunk
   * @returns {Promise<Object>} Chunk upload result
   */
  async uploadChunk(uploadId, chunkIndex, chunkData, chunkHash) {
    const metadata = this.chunkMetadata.get(uploadId);
    if (!metadata) {
      throw new Error('Invalid upload session');
    }

    if (chunkIndex >= metadata.totalChunks) {
      throw new Error('Chunk index out of range');
    }

    // Validate chunk hash
    const actualHash = crypto.createHash('md5').update(chunkData).digest('hex');
    if (actualHash !== chunkHash) {
      throw new Error('Chunk hash mismatch');
    }

    // Upload chunk to storage
    const chunkFileName = `${uploadId}-chunk-${chunkIndex}`;
    const chunkPath = `chunks/${uploadId}/${chunkFileName}`;

    // Create temporary file for chunk
    const tempDir = path.join(__dirname, '../../../uploads/temp');
    await fs.mkdir(tempDir, { recursive: true });
    const tempPath = path.join(tempDir, chunkFileName);
    await fs.writeFile(tempPath, chunkData);

    // Upload to storage
    const storageClient = this.getStorage();
    const result = await storageClient.uploadFile(
      tempPath,
      chunkPath,
      {
        contentType: 'application/octet-stream',
        metadata: {
          uploadId,
          chunkIndex: chunkIndex.toString(),
          chunkHash
        }
      }
    );

    // Clean up temp file
    try {
      await fs.unlink(tempPath);
    } catch (err) {
      console.warn(`BlockServer: Could not delete temp file ${tempPath}:`, err.message);
    }

    // Update metadata
    metadata.uploadedChunks.push({
      index: chunkIndex,
      path: chunkPath,
      hash: chunkHash,
      uploadedAt: new Date()
    });

    this.chunkMetadata.set(uploadId, metadata);

    return {
      success: true,
      chunkIndex,
      uploadedChunks: metadata.uploadedChunks.length,
      totalChunks: metadata.totalChunks
    };
  }

  /**
   * Complete chunked upload and reassemble file
   * @param {string} uploadId - Upload session ID
   * @param {string} folder - Destination folder
   * @returns {Promise<Object>} File upload result
   */
  async completeChunkedUpload(uploadId, folder = 'general') {
    const metadata = this.chunkMetadata.get(uploadId);
    if (!metadata) {
      throw new Error('Invalid upload session');
    }

    // Verify all chunks are uploaded
    if (metadata.uploadedChunks.length !== metadata.totalChunks) {
      throw new Error(`Missing chunks. Uploaded: ${metadata.uploadedChunks.length}, Required: ${metadata.totalChunks}`);
    }

    // Sort chunks by index
    metadata.uploadedChunks.sort((a, b) => a.index - b.index);

    // Download all chunks and reassemble
    const tempDir = path.join(__dirname, '../../../uploads/temp');
    await fs.mkdir(tempDir, { recursive: true });
    const reassembledPath = path.join(tempDir, `${uploadId}-reassembled${metadata.fileExtension}`);

    // Get storage client once for the entire operation
    const storageClient = this.getStorage();
    
    try {
      // Download and reassemble chunks
      const chunkFiles = [];
      for (const chunk of metadata.uploadedChunks) {
        // Download chunk from storage
        const chunkData = await storageClient.downloadFile(chunk.path);
        const chunkFilePath = path.join(tempDir, `${uploadId}-chunk-${chunk.index}`);
        await fs.writeFile(chunkFilePath, chunkData);
        chunkFiles.push({
          index: chunk.index,
          path: chunkFilePath
        });
      }

      // Reassemble file
      await fileChunker.reassembleChunks(chunkFiles, reassembledPath);

      // Upload reassembled file to final location
      const fileName = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${metadata.fileExtension}`;
      const destinationPath = path.join(folder, fileName);

      const file = {
        path: reassembledPath,
        originalname: metadata.fileName,
        mimetype: metadata.mimeType,
        size: metadata.fileSize
      };

      const result = await fileService.uploadFile(file, folder);

      // Clean up temp files
      try {
        await fs.unlink(reassembledPath);
      } catch (err) {
        console.warn(`BlockServer: Could not delete temp file:`, err.message);
      }

      // Delete chunks from storage
      for (const chunk of metadata.uploadedChunks) {
        try {
          await storageClient.deleteFile(chunk.path);
        } catch (err) {
          console.warn(`BlockServer: Could not delete chunk ${chunk.path}:`, err.message);
        }
      }

      // Remove metadata
      this.chunkMetadata.delete(uploadId);

      return {
        success: true,
        ...result,
        uploadId
      };
    } catch (error) {
      // Clean up on error
      try {
        if (await fs.access(reassembledPath).then(() => true).catch(() => false)) {
          await fs.unlink(reassembledPath);
        }
      } catch (err) {
        // Ignore cleanup errors
      }

      throw error;
    }
  }

  /**
   * Get upload progress
   * @param {string} uploadId - Upload session ID
   * @returns {Object} Upload progress
   */
  getUploadProgress(uploadId) {
    const metadata = this.chunkMetadata.get(uploadId);
    if (!metadata) {
      return null;
    }

    return {
      uploadId,
      totalChunks: metadata.totalChunks,
      uploadedChunks: metadata.uploadedChunks.length,
      progress: (metadata.uploadedChunks.length / metadata.totalChunks) * 100,
      status: metadata.status
    };
  }

  /**
   * Cancel chunked upload
   * @param {string} uploadId - Upload session ID
   */
  async cancelChunkedUpload(uploadId) {
    const metadata = this.chunkMetadata.get(uploadId);
    if (!metadata) {
      return;
    }

    // Delete uploaded chunks from storage
    const storageClient = this.getStorage();
    for (const chunk of metadata.uploadedChunks) {
      try {
        await storageClient.deleteFile(chunk.path);
      } catch (err) {
        console.warn(`BlockServer: Could not delete chunk ${chunk.path}:`, err.message);
      }
    }

    // Remove metadata
    this.chunkMetadata.delete(uploadId);
  }
}

// Export singleton instance
const blockServer = new BlockServer();
module.exports = blockServer;

