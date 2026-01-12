/*
 * Partition Manager
 * Manages partition metadata and statistics
 */

const directoryPartitioner = require('./directoryPartitioner');
const cacheService = require('../cache/cacheService');
const mongoose = require('mongoose');

class PartitionManager {
  constructor() {
    this.partitionStats = new Map();
  }

  /**
   * Get partition statistics
   * @param {string} partitionPath - Partition path
   * @returns {Promise<Object>} Partition statistics
   */
  async getPartitionStats(partitionPath) {
    const cacheKey = `partition:stats:${partitionPath}`;
    
    // Check cache
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // Calculate stats
    const stats = await this.calculatePartitionStats(partitionPath);

    // Cache stats (15 minutes TTL)
    await cacheService.set(cacheKey, stats, 900);

    return stats;
  }

  /**
   * Calculate partition statistics
   * @param {string} partitionPath - Partition path
   * @returns {Promise<Object>} Partition statistics
   */
  async calculatePartitionStats(partitionPath) {
    try {
      // Extract collection name and partition index from path
      const [collectionName] = partitionPath.split('/');
      const partitionIndex = directoryPartitioner.extractPartitionIndex(partitionPath);

      // Get model
      const Model = mongoose.model(collectionName);
      if (!Model) {
        return {
          partitionPath,
          documentCount: 0,
          size: 0,
          lastUpdated: new Date()
        };
      }

      // Count documents in partition (approximate)
      // Note: In a real sharded setup, this would query the specific shard
      const documentCount = await Model.countDocuments({}).lean();

      return {
        partitionPath,
        partitionIndex,
        collectionName,
        documentCount,
        size: 0, // Would need to query actual size
        lastUpdated: new Date()
      };
    } catch (error) {
      console.error('PartitionManager: Error calculating stats:', error.message);
      return {
        partitionPath,
        documentCount: 0,
        size: 0,
        lastUpdated: new Date(),
        error: error.message
      };
    }
  }

  /**
   * Update partition metadata after write
   * @param {string} partitionPath - Partition path
   * @param {number} documentCount - New document count
   */
  async updatePartitionMetadata(partitionPath, documentCount) {
    const metadata = await directoryPartitioner.getPartitionMetadata(partitionPath);
    metadata.documentCount = documentCount;
    metadata.lastUpdated = new Date();

    // Update cache
    const cacheKey = `partition:metadata:${partitionPath}`;
    await cacheService.set(cacheKey, metadata, 3600);

    // Invalidate stats cache
    const statsCacheKey = `partition:stats:${partitionPath}`;
    await cacheService.deletePattern(statsCacheKey).catch(() => {});
  }

  /**
   * Get all partition statistics for a collection
   * @param {string} collectionName - Collection name
   * @returns {Promise<Array<Object>>} Array of partition statistics
   */
  async getAllPartitionStats(collectionName) {
    const partitions = directoryPartitioner.getAllPartitions(collectionName);
    const statsPromises = partitions.map(partition => this.getPartitionStats(partition));
    return Promise.all(statsPromises);
  }

  /**
   * Get partition distribution (for load balancing)
   * @param {string} collectionName - Collection name
   * @returns {Promise<Object>} Distribution information
   */
  async getPartitionDistribution(collectionName) {
    const stats = await this.getAllPartitionStats(collectionName);
    
    const totalDocuments = stats.reduce((sum, stat) => sum + (stat.documentCount || 0), 0);
    const averageDocuments = totalDocuments / stats.length || 0;

    return {
      collectionName,
      totalPartitions: stats.length,
      totalDocuments,
      averageDocumentsPerPartition: averageDocuments,
      partitions: stats.map(stat => ({
        partitionIndex: stat.partitionIndex,
        documentCount: stat.documentCount,
        percentage: totalDocuments > 0 ? (stat.documentCount / totalDocuments * 100).toFixed(2) : 0
      }))
    };
  }
}

// Export singleton instance
const partitionManager = new PartitionManager();
module.exports = partitionManager;


