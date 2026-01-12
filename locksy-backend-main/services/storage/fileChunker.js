/*
 * File Chunker
 * Handles splitting files into chunks and reassembling them
 */

const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

class FileChunker {
  constructor(chunkSize = 10 * 1024 * 1024) {
    this.chunkSize = chunkSize; // Default 10MB per chunk
  }

  /**
   * Split file into chunks
   * @param {string} filePath - Path to file to chunk
   * @param {string} outputDir - Directory to store chunks
   * @returns {Promise<Object>} Chunk metadata
   */
  async splitFile(filePath, outputDir) {
    try {
      const fileStats = await fs.stat(filePath);
      const fileSize = fileStats.size;
      const totalChunks = Math.ceil(fileSize / this.chunkSize);
      const fileId = crypto.randomBytes(16).toString('hex');
      const fileExtension = path.extname(filePath);
      const originalName = path.basename(filePath);

      // Create output directory if it doesn't exist
      await fs.mkdir(outputDir, { recursive: true });

      const chunks = [];
      const fileHandle = await fs.open(filePath, 'r');
      const buffer = Buffer.alloc(this.chunkSize);

      for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        const chunkPath = path.join(outputDir, `${fileId}-chunk-${chunkIndex}`);
        const bytesRead = await fileHandle.read(buffer, 0, this.chunkSize, chunkIndex * this.chunkSize);
        
        if (bytesRead.bytesRead === 0) {
          break;
        }

        // Write chunk to file
        const chunkData = buffer.slice(0, bytesRead.bytesRead);
        await fs.writeFile(chunkPath, chunkData);

        chunks.push({
          index: chunkIndex,
          path: chunkPath,
          size: bytesRead.bytesRead,
          hash: crypto.createHash('md5').update(chunkData).digest('hex')
        });
      }

      await fileHandle.close();

      return {
        fileId,
        originalName,
        fileExtension,
        totalChunks,
        fileSize,
        chunks,
        chunkSize: this.chunkSize
      };
    } catch (error) {
      console.error('FileChunker: Error splitting file:', error.message);
      throw error;
    }
  }

  /**
   * Reassemble chunks into file
   * @param {Array} chunks - Array of chunk metadata with paths
   * @param {string} outputPath - Path to reassembled file
   * @returns {Promise<string>} Path to reassembled file
   */
  async reassembleChunks(chunks, outputPath) {
    try {
      // Sort chunks by index
      chunks.sort((a, b) => a.index - b.index);

      // Create output file
      const outputHandle = await fs.open(outputPath, 'w');

      // Write each chunk
      for (const chunk of chunks) {
        const chunkData = await fs.readFile(chunk.path);
        await outputHandle.write(chunkData);
      }

      await outputHandle.close();

      // Clean up chunks
      for (const chunk of chunks) {
        try {
          await fs.unlink(chunk.path);
        } catch (err) {
          console.warn(`FileChunker: Could not delete chunk ${chunk.path}:`, err.message);
        }
      }

      return outputPath;
    } catch (error) {
      console.error('FileChunker: Error reassembling chunks:', error.message);
      throw error;
    }
  }

  /**
   * Validate chunk integrity
   * @param {string} chunkPath - Path to chunk file
   * @param {string} expectedHash - Expected MD5 hash
   * @returns {Promise<boolean>} True if chunk is valid
   */
  async validateChunk(chunkPath, expectedHash) {
    try {
      const chunkData = await fs.readFile(chunkPath);
      const actualHash = crypto.createHash('md5').update(chunkData).digest('hex');
      return actualHash === expectedHash;
    } catch (error) {
      console.error('FileChunker: Error validating chunk:', error.message);
      return false;
    }
  }

  /**
   * Get chunk metadata from file
   * @param {string} filePath - Path to file
   * @returns {Promise<Object>} Chunk metadata
   */
  async getChunkMetadata(filePath) {
    try {
      const stats = await fs.stat(filePath);
      const totalChunks = Math.ceil(stats.size / this.chunkSize);
      
      return {
        totalChunks,
        fileSize: stats.size,
        chunkSize: this.chunkSize
      };
    } catch (error) {
      console.error('FileChunker: Error getting chunk metadata:', error.message);
      throw error;
    }
  }
}

// Export singleton instance
const fileChunker = new FileChunker();
module.exports = fileChunker;


