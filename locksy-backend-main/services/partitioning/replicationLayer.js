/*
 * Replication and Partitioning Layer
 * Coordinates writes to primary, reads from secondaries
 * Handles partition routing
 */

const mongoose = require('mongoose');
const { getReadPreference } = require('../../database/read-preference');
const directoryPartitioner = require('./directoryPartitioner');
const PartitionStrategy = require('./partitionStrategy');
const cacheService = require('../cache/cacheService');

class ReplicationLayer {
  constructor() {
    this.replicaSetStatus = null;
    this.lastHealthCheck = null;
    this.healthCheckInterval = 30000; // 30 seconds
  }

  /**
   * Execute write operation (always goes to primary)
   * @param {string} collectionName - Collection name
   * @param {Function} operation - Write operation function
   * @param {Object} doc - Document for partitioning
   * @returns {Promise<*>} Operation result
   */
  async executeWrite(collectionName, operation, doc = null) {
    try {
      // Get partition information
      let partitionPath = null;
      if (doc) {
        partitionPath = PartitionStrategy.getPartitionKey(collectionName, doc);
      }

      // Execute write operation (always uses primary)
      const result = await operation();

      // Invalidate cache for this partition
      if (partitionPath) {
        await this.invalidatePartitionCache(collectionName, partitionPath);
      } else {
        // Invalidate all partitions for this collection
        await this.invalidateCollectionCache(collectionName);
      }

      return result;
    } catch (error) {
      console.error('ReplicationLayer: Write operation failed:', error.message);
      throw error;
    }
  }

  /**
   * Execute read operation (can use secondary)
   * @param {string} collectionName - Collection name
   * @param {Function} operation - Read operation function
   * @param {Object} options - Read options
   * @param {string} options.readPreference - Read preference (default: secondaryPreferred)
   * @param {Object} options.partitionDoc - Document for partition routing
   * @returns {Promise<*>} Operation result
   */
  async executeRead(collectionName, operation, options = {}) {
    try {
      const readPreference = options.readPreference || getReadPreference('read', 'secondaryPreferred');
      
      // Get partition information if provided
      let partitionPath = null;
      if (options.partitionDoc) {
        partitionPath = PartitionStrategy.getPartitionKey(collectionName, options.partitionDoc);
      }

      // Check cache first
      if (partitionPath) {
        const cacheKey = this.getCacheKey(collectionName, partitionPath, options);
        const cached = await cacheService.get(cacheKey);
        if (cached) {
          return cached;
        }
      }

      // Execute read operation with read preference
      const Model = mongoose.model(collectionName);
      if (Model && readPreference !== 'primary') {
        // Set read preference for this query
        const result = await operation(Model, readPreference);
        
        // Cache result if partition is known
        if (partitionPath && result) {
          const cacheKey = this.getCacheKey(collectionName, partitionPath, options);
          await cacheService.set(cacheKey, result, 300); // 5 minutes TTL
        }
        
        return result;
      } else {
        // Fallback to direct operation
        return await operation();
      }
    } catch (error) {
      console.error('ReplicationLayer: Read operation failed:', error.message);
      // Fallback to primary on error
      return await operation();
    }
  }

  /**
   * Get cache key for partition
   * @param {string} collectionName - Collection name
   * @param {string} partitionPath - Partition path
   * @param {Object} options - Query options
   * @returns {string} Cache key
   */
  getCacheKey(collectionName, partitionPath, options) {
    const queryHash = require('crypto')
      .createHash('md5')
      .update(JSON.stringify(options.query || {}))
      .digest('hex')
      .substring(0, 8);
    return `read:${collectionName}:${partitionPath}:${queryHash}`;
  }

  /**
   * Invalidate partition cache
   * @param {string} collectionName - Collection name
   * @param {string} partitionPath - Partition path
   */
  async invalidatePartitionCache(collectionName, partitionPath) {
    const pattern = `read:${collectionName}:${partitionPath}:*`;
    await cacheService.deletePattern(pattern).catch(err => {
      console.warn('ReplicationLayer: Cache invalidation error:', err.message);
    });
  }

  /**
   * Invalidate all cache for collection
   * @param {string} collectionName - Collection name
   */
  async invalidateCollectionCache(collectionName) {
    const pattern = `read:${collectionName}:*`;
    await cacheService.deletePattern(pattern).catch(err => {
      console.warn('ReplicationLayer: Cache invalidation error:', err.message);
    });
  }

  /**
   * Check replica set health
   * @returns {Promise<Object>} Replica set status
   */
  async checkReplicaSetHealth() {
    try {
      const admin = mongoose.connection.db.admin();
      const status = await admin.command({ replSetGetStatus: 1 });
      
      this.replicaSetStatus = {
        setName: status.set,
        members: status.members.map(m => ({
          name: m.name,
          state: m.stateStr,
          health: m.health,
          uptime: m.uptime
        })),
        primary: status.members.find(m => m.stateStr === 'PRIMARY')?.name,
        secondaries: status.members.filter(m => m.stateStr === 'SECONDARY').map(m => m.name),
        lastCheck: new Date()
      };

      this.lastHealthCheck = new Date();
      return this.replicaSetStatus;
    } catch (error) {
      console.error('ReplicationLayer: Health check failed:', error.message);
      return null;
    }
  }

  /**
   * Get replica set status (cached)
   * @returns {Promise<Object>} Replica set status
   */
  async getReplicaSetStatus() {
    const now = new Date();
    if (!this.lastHealthCheck || (now - this.lastHealthCheck) > this.healthCheckInterval) {
      return await this.checkReplicaSetHealth();
    }
    return this.replicaSetStatus;
  }

  /**
   * Route query to appropriate partition
   * @param {string} collectionName - Collection name
   * @param {Object} query - MongoDB query
   * @returns {Array<string>} Array of partition paths to query
   */
  routeToPartitions(collectionName, query) {
    // If query has partition key, route to specific partition
    const partitionKey = this.getPartitionKeyFromQuery(collectionName, query);
    if (partitionKey) {
      const partitionPath = PartitionStrategy.getPartitionKey(collectionName, { _id: partitionKey });
      return [partitionPath];
    }

    // Otherwise, query all partitions
    return directoryPartitioner.getAllPartitions(collectionName);
  }

  /**
   * Extract partition key from query
   * @param {string} collectionName - Collection name
   * @param {Object} query - MongoDB query
   * @returns {string|null} Partition key
   */
  getPartitionKeyFromQuery(collectionName, query) {
    // Check for _id, codigoContacto, para, codigo based on collection
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
}

// Export singleton instance
const replicationLayer = new ReplicationLayer();
module.exports = replicationLayer;


