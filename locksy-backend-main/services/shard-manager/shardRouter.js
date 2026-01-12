/*
 * Shard Router
 * Routes requests to correct shard based on sharding key
 */

const directoryPartitioner = require('../partitioning/directoryPartitioner');
const PartitionStrategy = require('../partitioning/partitionStrategy');
const cacheService = require('../cache/cacheService');

class ShardRouter {
  constructor() {
    this.shardMetadata = new Map(); // Store shard metadata
    this.shardCount = parseInt(process.env.SHARD_COUNT || '3'); // Default 3 shards
  }

  /**
   * Route document to shard
   * @param {string} collectionName - Collection name
   * @param {Object} doc - Document
   * @returns {number} Shard index (0 to shardCount-1)
   */
  routeToShard(collectionName, doc) {
    // Get partition path
    const partitionPath = PartitionStrategy.getPartitionKey(collectionName, doc);
    
    // Extract partition index
    const partitionIndex = directoryPartitioner.extractPartitionIndex(partitionPath);
    
    // Map partition to shard (distribute partitions across shards)
    return partitionIndex % this.shardCount;
  }

  /**
   * Get shard for query
   * @param {string} collectionName - Collection name
   * @param {Object} query - MongoDB query
   * @returns {Array<number>} Array of shard indices to query
   */
  getShardsForQuery(collectionName, query) {
    // If query has sharding key, route to specific shard
    const shardingKey = this.getShardingKeyFromQuery(collectionName, query);
    if (shardingKey) {
      const shardIndex = this.routeToShard(collectionName, { _id: shardingKey });
      return [shardIndex];
    }

    // Otherwise, query all shards
    return Array.from({ length: this.shardCount }, (_, i) => i);
  }

  /**
   * Extract sharding key from query
   * @param {string} collectionName - Collection name
   * @param {Object} query - MongoDB query
   * @returns {string|null} Sharding key
   */
  getShardingKeyFromQuery(collectionName, query) {
    // Sharding keys based on collection
    if (query._id) {
      return query._id.toString();
    }

    if (collectionName === 'usuarios' || collectionName === 'users') {
      return query.codigoContacto || null;
    }

    if (collectionName === 'mensajes' || collectionName === 'messages') {
      return query.para || null;
    }

    if (collectionName === 'grupos' || collectionName === 'groups') {
      return query.codigo || null;
    }

    return null;
  }

  /**
   * Get shard metadata
   * @param {number} shardIndex - Shard index
   * @returns {Promise<Object>} Shard metadata
   */
  async getShardMetadata(shardIndex) {
    const cacheKey = `shard:metadata:${shardIndex}`;
    
    // Check cache
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // Generate metadata
    const metadata = {
      shardIndex,
      status: 'active',
      documentCount: 0,
      lastUpdated: new Date()
    };

    // Cache metadata (1 hour TTL)
    await cacheService.set(cacheKey, metadata, 3600);

    return metadata;
  }

  /**
   * Get all shard metadata
   * @returns {Promise<Array<Object>>} Array of shard metadata
   */
  async getAllShardMetadata() {
    const shards = [];
    for (let i = 0; i < this.shardCount; i++) {
      const metadata = await this.getShardMetadata(i);
      shards.push(metadata);
    }
    return shards;
  }

  /**
   * Get shard count
   * @returns {number} Number of shards
   */
  getShardCount() {
    return this.shardCount;
  }
}

// Export singleton instance
const shardRouter = new ShardRouter();
module.exports = shardRouter;

