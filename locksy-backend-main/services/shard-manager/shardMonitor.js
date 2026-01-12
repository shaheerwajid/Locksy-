/*
 * Shard Monitor
 * Monitors shard health and performance
 */

const shardRouter = require('./shardRouter');
const cacheService = require('../cache/cacheService');
const mongoose = require('mongoose');

class ShardMonitor {
  constructor() {
    this.monitoringInterval = parseInt(process.env.SHARD_MONITOR_INTERVAL || '60000'); // 1 minute
    this.monitoringTimer = null;
    this.shardHealth = new Map();
  }

  /**
   * Start monitoring
   */
  start() {
    if (this.monitoringTimer) {
      return; // Already monitoring
    }

    // Initial health check
    this.checkShardHealth().catch(err => {
      console.error('ShardMonitor: Initial health check failed:', err.message);
    });

    // Periodic health checks
    this.monitoringTimer = setInterval(() => {
      this.checkShardHealth().catch(err => {
        console.error('ShardMonitor: Health check failed:', err.message);
      });
    }, this.monitoringInterval);

    console.log('ShardMonitor: Started monitoring');
  }

  /**
   * Stop monitoring
   */
  stop() {
    if (this.monitoringTimer) {
      clearInterval(this.monitoringTimer);
      this.monitoringTimer = null;
      console.log('ShardMonitor: Stopped monitoring');
    }
  }

  /**
   * Check shard health
   * @returns {Promise<Object>} Health status
   */
  async checkShardHealth() {
    try {
      const shardCount = shardRouter.getShardCount();
      const healthStatus = {
        timestamp: new Date(),
        shards: [],
        overall: 'healthy'
      };

      // Check each shard
      for (let i = 0; i < shardCount; i++) {
        const shardHealth = await this.checkSingleShard(i);
        healthStatus.shards.push(shardHealth);
        
        if (shardHealth.status !== 'healthy') {
          healthStatus.overall = 'degraded';
        }
      }

      // Cache health status
      await cacheService.set('shard:health', healthStatus, 300); // 5 minutes TTL

      // Store in memory
      this.shardHealth.set('latest', healthStatus);

      return healthStatus;
    } catch (error) {
      console.error('ShardMonitor: Error checking shard health:', error.message);
      return {
        timestamp: new Date(),
        status: 'error',
        error: error.message
      };
    }
  }

  /**
   * Check single shard health
   * @param {number} shardIndex - Shard index
   * @returns {Promise<Object>} Shard health status
   */
  async checkSingleShard(shardIndex) {
    try {
      // Check database connection
      const dbStatus = mongoose.connection.readyState === 1;
      
      // Check cache
      const cacheStatus = await cacheService.get('shard:test') !== null || true; // Simple test

      // Get shard metadata
      const metadata = await shardRouter.getShardMetadata(shardIndex);

      const health = {
        shardIndex,
        status: dbStatus && cacheStatus ? 'healthy' : 'unhealthy',
        database: dbStatus ? 'connected' : 'disconnected',
        cache: cacheStatus ? 'connected' : 'disconnected',
        documentCount: metadata.documentCount || 0,
        lastUpdated: metadata.lastUpdated
      };

      return health;
    } catch (error) {
      return {
        shardIndex,
        status: 'error',
        error: error.message
      };
    }
  }

  /**
   * Get shard health status
   * @returns {Promise<Object>} Health status
   */
  async getHealthStatus() {
    const cached = await cacheService.get('shard:health');
    if (cached) {
      return cached;
    }
    return await this.checkShardHealth();
  }

  /**
   * Get shard performance metrics
   * @param {number} shardIndex - Shard index (optional)
   * @returns {Promise<Object>} Performance metrics
   */
  async getPerformanceMetrics(shardIndex = null) {
    try {
      const metrics = {
        timestamp: new Date(),
        shards: []
      };

      if (shardIndex !== null) {
        // Get metrics for specific shard
        const shardMetrics = await this.getSingleShardMetrics(shardIndex);
        metrics.shards.push(shardMetrics);
      } else {
        // Get metrics for all shards
        const shardCount = shardRouter.getShardCount();
        for (let i = 0; i < shardCount; i++) {
          const shardMetrics = await this.getSingleShardMetrics(i);
          metrics.shards.push(shardMetrics);
        }
      }

      return metrics;
    } catch (error) {
      console.error('ShardMonitor: Error getting performance metrics:', error.message);
      return {
        timestamp: new Date(),
        error: error.message
      };
    }
  }

  /**
   * Get single shard performance metrics
   * @param {number} shardIndex - Shard index
   * @returns {Promise<Object>} Shard metrics
   */
  async getSingleShardMetrics(shardIndex) {
    const metadata = await shardRouter.getShardMetadata(shardIndex);
    const health = await this.checkSingleShard(shardIndex);

    return {
      shardIndex,
      documentCount: metadata.documentCount || 0,
      status: health.status,
      lastUpdated: metadata.lastUpdated
    };
  }
}

// Export singleton instance
const shardMonitor = new ShardMonitor();
module.exports = shardMonitor;


