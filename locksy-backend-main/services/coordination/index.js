/*
 * Coordination Service
 * Main coordination service using Zookeeper
 */

const zookeeperClient = require('./zookeeper-client');
const serviceDiscovery = require('./service-discovery');
const leaderElection = require('./leader-election');
const distributedLock = require('./distributed-lock');

class CoordinationService {
  constructor() {
    this.initialized = false;
  }

  /**
   * Initialize coordination service
   */
  async initialize() {
    if (this.initialized) {
      return;
    }

    try {
      await zookeeperClient.connect();
      this.initialized = true;
      console.log('CoordinationService: Initialized');
    } catch (error) {
      console.error('CoordinationService: Initialization failed:', error.message);
      throw error;
    }
  }

  /**
   * Register service
   * @param {string} serviceName - Service name
   * @param {Object} serviceInfo - Service information
   */
  async registerService(serviceName, serviceInfo) {
    await this.initialize();
    return await serviceDiscovery.registerService(serviceName, serviceInfo);
  }

  /**
   * Discover services
   * @param {string} serviceName - Service name (optional)
   */
  async discoverServices(serviceName = null) {
    await this.initialize();
    return await serviceDiscovery.discoverServices(serviceName);
  }

  /**
   * Participate in leader election
   * @param {string} electionName - Election name
   * @param {Function} onBecomeLeader - Callback
   * @param {Function} onLoseLeadership - Callback
   */
  async participateInElection(electionName, onBecomeLeader, onLoseLeadership) {
    await this.initialize();
    return await leaderElection.participate(electionName, onBecomeLeader, onLoseLeadership);
  }

  /**
   * Acquire distributed lock
   * @param {string} lockName - Lock name
   * @param {number} timeout - Timeout
   */
  async acquireLock(lockName, timeout = 30000) {
    await this.initialize();
    return await distributedLock.acquire(lockName, timeout);
  }

  /**
   * Release distributed lock
   * @param {string} lockName - Lock name
   */
  async releaseLock(lockName) {
    await this.initialize();
    return await distributedLock.release(lockName);
  }

  /**
   * Shutdown coordination service
   */
  async shutdown() {
    try {
      // Unregister all services
      for (const [serviceName] of serviceDiscovery.registeredServices) {
        await serviceDiscovery.unregisterService(serviceName);
      }

      // Withdraw from elections
      if (leaderElection.currentElection) {
        await leaderElection.withdraw();
      }

      // Release all locks
      for (const [lockName] of distributedLock.activeLocks) {
        await distributedLock.release(lockName);
      }

      // Close Zookeeper connection
      await zookeeperClient.close();
      
      this.initialized = false;
      console.log('CoordinationService: Shutdown complete');
    } catch (error) {
      console.error('CoordinationService: Shutdown error:', error.message);
    }
  }
}

// Export singleton instance
const coordinationService = new CoordinationService();
module.exports = coordinationService;


