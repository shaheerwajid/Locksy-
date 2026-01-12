/*
 * Distributed Lock
 * Distributed locking using Zookeeper
 */

const zookeeperClient = require('./zookeeper-client');

class DistributedLock {
  constructor() {
    this.locksPath = '/locksy/locks';
    this.activeLocks = new Map();
  }

  /**
   * Acquire lock
   * @param {string} lockName - Lock name
   * @param {number} timeout - Timeout in milliseconds
   * @returns {Promise<Object>} Lock object
   */
  async acquire(lockName, timeout = 30000) {
    try {
      await zookeeperClient.connect();
      
      const lockPath = `${this.locksPath}/${lockName}`;
      await zookeeperClient.ensurePath(lockPath);

      // Create ephemeral sequential node
      const lockNodePath = `${lockPath}/lock-`;
      const createdPath = await zookeeperClient.createNode(
        lockNodePath,
        {
          pid: process.pid,
          hostname: require('os').hostname(),
          timestamp: new Date().toISOString()
        },
        zookeeperClient.client.CreateMode.EPHEMERAL_SEQUENTIAL
      );

      const lock = {
        name: lockName,
        path: createdPath,
        acquiredAt: new Date(),
        timeout
      };

      // Try to acquire lock
      const acquired = await this.tryAcquire(lockPath, createdPath, timeout);
      
      if (acquired) {
        this.activeLocks.set(lockName, lock);
        console.log(`DistributedLock: Acquired lock ${lockName} at ${createdPath}`);
        return lock;
      } else {
        // Timeout - clean up
        await zookeeperClient.deleteNode(createdPath);
        throw new Error(`Failed to acquire lock ${lockName} within ${timeout}ms`);
      }
    } catch (error) {
      console.error('DistributedLock: Error acquiring lock:', error.message);
      throw error;
    }
  }

  /**
   * Try to acquire lock
   * @param {string} lockPath - Lock path
   * @param {string} ourPath - Our lock node path
   * @param {number} timeout - Timeout
   * @returns {Promise<boolean>} True if acquired
   */
  async tryAcquire(lockPath, ourPath, timeout) {
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      try {
        const children = await zookeeperClient.listChildren(lockPath);
        if (children.length === 0) {
          return true; // No other locks, we got it
        }

        // Sort children
        children.sort();

        // Extract our sequence
        const ourSeq = this.extractSequence(ourPath);
        
        // Find our position
        const ourIndex = children.findIndex(child => {
          const childPath = `${lockPath}/${child}`;
          return this.extractSequence(childPath) === ourSeq;
        });

        // If we're first, we got the lock
        if (ourIndex === 0) {
          return true;
        }

        // Watch the previous node
        if (ourIndex > 0) {
          const previousNode = children[ourIndex - 1];
          const previousPath = `${lockPath}/${previousNode}`;
          
          await this.waitForNodeDeletion(previousPath, timeout - (Date.now() - startTime));
        }
      } catch (error) {
        // If node doesn't exist, we might have the lock now
        const zk = require('node-zookeeper-client');
        if (error.code === zk.Exception.NO_NODE) {
          continue;
        }
        throw error;
      }
    }

    return false; // Timeout
  }

  /**
   * Wait for node deletion
   * @param {string} path - Node path
   * @param {number} timeout - Timeout
   * @returns {Promise<void>}
   */
  async waitForNodeDeletion(path, timeout) {
    return new Promise((resolve, reject) => {
      const startTime = Date.now();
      const zookeeper = require('node-zookeeper-client');
      
      const checkNode = () => {
        zookeeperClient.client.exists(
          path,
          (event) => {
            if (event && event.type === zookeeper.Event.NODE_DELETED) {
              resolve();
            } else {
              checkNode();
            }
          },
          (error, stat) => {
            if (error) {
              const zk = require('node-zookeeper-client');
              if (error.code === zk.Exception.NO_NODE) {
                resolve(); // Node doesn't exist, we can proceed
              } else {
                reject(error);
              }
            } else if (!stat) {
              resolve(); // Node doesn't exist
            } else if (Date.now() - startTime > timeout) {
              reject(new Error('Timeout waiting for node deletion'));
            } else {
              // Node exists, wait a bit and check again
              setTimeout(checkNode, 100);
            }
          }
        );
      };

      checkNode();
    });
  }

  /**
   * Release lock
   * @param {string} lockName - Lock name
   */
  async release(lockName) {
    try {
      const lock = this.activeLocks.get(lockName);
      if (lock) {
        await zookeeperClient.deleteNode(lock.path);
        this.activeLocks.delete(lockName);
        console.log(`DistributedLock: Released lock ${lockName}`);
      }
    } catch (error) {
      console.error('DistributedLock: Error releasing lock:', error.message);
    }
  }

  /**
   * Extract sequence number from path
   * @param {string} path - Zookeeper path
   * @returns {number} Sequence number
   */
  extractSequence(path) {
    const match = path.match(/lock-(\d+)$/);
    return match ? parseInt(match[1]) : Infinity;
  }

  /**
   * Check if lock is held
   * @param {string} lockName - Lock name
   * @returns {boolean} True if held
   */
  isLocked(lockName) {
    return this.activeLocks.has(lockName);
  }
}

// Export singleton instance
const distributedLock = new DistributedLock();
module.exports = distributedLock;

