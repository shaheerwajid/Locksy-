/*
 * Directory-Based Partitioning
 * Organizes data by directory structure for efficient access
 */

const crypto = require('crypto');
const cacheService = require('../cache/cacheService');

class DirectoryPartitioner {
  constructor() {
    this.partitionCount = parseInt(process.env.PARTITION_COUNT || '10'); // Default 10 partitions
    this.partitionMetadataCache = new Map(); // Cache partition metadata
  }

  /**
   * Hash function for consistent partitioning
   * @param {string} value - Value to hash
   * @returns {number} Partition index (0 to partitionCount-1)
   */
  hashToPartition(value) {
    if (!value) {
      return 0;
    }
    const hash = crypto.createHash('md5').update(String(value)).digest('hex');
    const hashInt = parseInt(hash.substring(0, 8), 16);
    return hashInt % this.partitionCount;
  }

  /**
   * Get partition for user
   * @param {string} userId - User ID or codigoContacto
   * @returns {string} Partition directory
   */
  getUserPartition(userId) {
    const partitionIndex = this.hashToPartition(userId);
    return `users/partition_${partitionIndex}`;
  }

  /**
   * Get partition for message
   * @param {string} recipientId - Recipient ID (para field)
   * @param {Date} date - Message date (optional, for time-based partitioning)
   * @returns {string} Partition directory
   */
  getMessagePartition(recipientId, date = null) {
    // Partition by recipient (primary) and optionally by date range
    const recipientPartition = this.hashToPartition(recipientId);
    
    if (date) {
      // Time-based sub-partitioning (by month)
      const month = date.getMonth() + 1;
      const year = date.getFullYear();
      return `messages/partition_${recipientPartition}/${year}/${month}`;
    }
    
    return `messages/partition_${recipientPartition}`;
  }

  /**
   * Get partition for group
   * @param {string} groupCode - Group code
   * @returns {string} Partition directory
   */
  getGroupPartition(groupCode) {
    const partitionIndex = this.hashToPartition(groupCode);
    return `groups/partition_${partitionIndex}`;
  }

  /**
   * Get partition for contact
   * @param {string} userId - User ID
   * @returns {string} Partition directory
   */
  getContactPartition(userId) {
    const partitionIndex = this.hashToPartition(userId);
    return `contacts/partition_${partitionIndex}`;
  }

  /**
   * Get partition metadata (cached)
   * @param {string} partitionPath - Partition path
   * @returns {Promise<Object>} Partition metadata
   */
  async getPartitionMetadata(partitionPath) {
    const cacheKey = `partition:metadata:${partitionPath}`;
    
    // Check cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // Generate metadata
    const metadata = {
      path: partitionPath,
      partitionIndex: this.extractPartitionIndex(partitionPath),
      createdAt: new Date(),
      documentCount: 0, // Will be updated by partition manager
      lastUpdated: new Date()
    };

    // Cache metadata (1 hour TTL)
    await cacheService.set(cacheKey, metadata, 3600);

    return metadata;
  }

  /**
   * Extract partition index from path
   * @param {string} partitionPath - Partition path
   * @returns {number} Partition index
   */
  extractPartitionIndex(partitionPath) {
    const match = partitionPath.match(/partition_(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  /**
   * Get all partitions for a collection
   * @param {string} collectionType - Collection type (users, messages, groups, contacts)
   * @returns {Array<string>} Array of partition paths
   */
  getAllPartitions(collectionType) {
    const partitions = [];
    for (let i = 0; i < this.partitionCount; i++) {
      partitions.push(`${collectionType}/partition_${i}`);
    }
    return partitions;
  }

  /**
   * Get partition count
   * @returns {number} Number of partitions
   */
  getPartitionCount() {
    return this.partitionCount;
  }

  /**
   * Set partition count (for dynamic scaling)
   * @param {number} count - New partition count
   */
  setPartitionCount(count) {
    this.partitionCount = count;
    // Clear partition metadata cache
    this.partitionMetadataCache.clear();
  }
}

// Export singleton instance
const directoryPartitioner = new DirectoryPartitioner();
module.exports = directoryPartitioner;


