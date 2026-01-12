/*
 * Zookeeper Client
 * Handles Zookeeper connection and operations
 */

const zookeeper = require('node-zookeeper-client');
const config = require('../../config');

class ZookeeperClient {
  constructor() {
    this.client = null;
    this.connected = false;
    this.basePath = '/locksy';
    this.servicesPath = `${this.basePath}/services`;
    this.configPath = `${this.basePath}/config`;
    this.locksPath = `${this.basePath}/locks`;
  }

  /**
   * Connect to Zookeeper
   */
  async connect() {
    if (this.connected && this.client) {
      return this.client;
    }

    try {
      const zkHost = process.env.ZOOKEEPER_HOST || 'localhost:2181';
      
      this.client = zookeeper.createClient(zkHost, {
        sessionTimeout: 30000,
        spinDelay: 1000,
        retries: 3
      });

      return new Promise((resolve, reject) => {
        this.client.once('connected', () => {
          this.connected = true;
          console.log('Zookeeper: Connected');
          
          // Initialize base paths
          this.ensurePath(this.basePath)
            .then(() => this.ensurePath(this.servicesPath))
            .then(() => this.ensurePath(this.configPath))
            .then(() => this.ensurePath(this.locksPath))
            .then(() => resolve(this.client))
            .catch(reject);
        });

        this.client.on('disconnected', () => {
          this.connected = false;
          console.warn('Zookeeper: Disconnected');
        });

      this.client.on('error', (error) => {
        console.error('Zookeeper: Error:', error.message);
        this.connected = false;
      });

        this.client.connect();
      });
    } catch (error) {
      console.error('Zookeeper: Connection failed:', error.message);
      throw error;
    }
  }

  /**
   * Ensure path exists
   * @param {string} path - Zookeeper path
   * @returns {Promise<void>}
   */
  async ensurePath(path) {
    return new Promise((resolve, reject) => {
      const zookeeper = require('node-zookeeper-client');
      this.client.mkdirp(path, (error) => {
        if (error && error.code !== zookeeper.Exception.NODE_EXISTS) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  /**
   * Create node
   * @param {string} path - Node path
   * @param {Buffer|string} data - Node data
   * @param {number} mode - Node mode (EPHEMERAL, SEQUENTIAL, etc.)
   * @returns {Promise<string>} Created path
   */
  async createNode(path, data = null, mode = zookeeper.CreateMode.PERSISTENT) {
    await this.connect();
    
    return new Promise((resolve, reject) => {
      const nodeData = data ? Buffer.from(typeof data === 'string' ? data : JSON.stringify(data)) : Buffer.alloc(0);
      
      this.client.create(path, nodeData, mode, (error, createdPath) => {
        if (error) {
          reject(error);
        } else {
          resolve(createdPath);
        }
      });
    });
  }

  /**
   * Get node data
   * @param {string} path - Node path
   * @returns {Promise<Object>} Node data
   */
  async getNode(path) {
    await this.connect();
    
    return new Promise((resolve, reject) => {
      this.client.getData(path, (error, data, stat) => {
        if (error) {
          reject(error);
        } else {
          try {
            const parsed = data ? JSON.parse(data.toString()) : null;
            resolve({ data: parsed, stat });
          } catch (e) {
            resolve({ data: data ? data.toString() : null, stat });
          }
        }
      });
    });
  }

  /**
   * Set node data
   * @param {string} path - Node path
   * @param {Object|string} data - Data to set
   * @returns {Promise<void>}
   */
  async setNode(path, data) {
    await this.connect();
    
    return new Promise((resolve, reject) => {
      const nodeData = Buffer.from(typeof data === 'string' ? data : JSON.stringify(data));
      
      this.client.setData(path, nodeData, -1, (error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  /**
   * Delete node
   * @param {string} path - Node path
   * @returns {Promise<void>}
   */
  async deleteNode(path) {
    await this.connect();
    
    return new Promise((resolve, reject) => {
      this.client.remove(path, -1, (error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  /**
   * List children
   * @param {string} path - Parent path
   * @returns {Promise<Array<string>>} Children paths
   */
  async listChildren(path) {
    await this.connect();
    
    return new Promise((resolve, reject) => {
      this.client.getChildren(path, (error, children) => {
        if (error) {
          reject(error);
        } else {
          resolve(children);
        }
      });
    });
  }

  /**
   * Check if connected
   * @returns {boolean} Connection status
   */
  isConnected() {
    if (!this.client) {
      return false;
    }
    const zookeeper = require('node-zookeeper-client');
    return this.connected && this.client.getState() === zookeeper.State.SYNC_CONNECTED;
  }

  /**
   * Close connection
   */
  async close() {
    if (this.client) {
      this.client.close();
      this.client = null;
      this.connected = false;
      console.log('Zookeeper: Connection closed');
    }
  }
}

// Export singleton instance
const zookeeperClient = new ZookeeperClient();
module.exports = zookeeperClient;

