/*
 * Service Discovery
 * Service registration and discovery using Zookeeper
 */

const zookeeperClient = require('./zookeeper-client');

class ServiceDiscovery {
  constructor() {
    this.servicesPath = '/locksy/services';
    this.registeredServices = new Map();
  }

  /**
   * Register service
   * @param {string} serviceName - Service name
   * @param {Object} serviceInfo - Service information
   * @returns {Promise<string>} Service path
   */
  async registerService(serviceName, serviceInfo) {
    try {
      await zookeeperClient.connect();
      
      const servicePath = `${this.servicesPath}/${serviceName}`;
      await zookeeperClient.ensurePath(servicePath);

      // Create ephemeral node for this service instance
      const instancePath = `${servicePath}/instance-`;
      const instanceInfo = {
        ...serviceInfo,
        serviceName,
        registeredAt: new Date().toISOString(),
        pid: process.pid
      };

      const createdPath = await zookeeperClient.createNode(
        instancePath,
        instanceInfo,
        zookeeperClient.client.CreateMode.EPHEMERAL_SEQUENTIAL
      );

      this.registeredServices.set(serviceName, createdPath);

      console.log(`ServiceDiscovery: Registered service ${serviceName} at ${createdPath}`);
      return createdPath;
    } catch (error) {
      console.error('ServiceDiscovery: Error registering service:', error.message);
      throw error;
    }
  }

  /**
   * Unregister service
   * @param {string} serviceName - Service name
   */
  async unregisterService(serviceName) {
    try {
      const servicePath = this.registeredServices.get(serviceName);
      if (servicePath) {
        await zookeeperClient.deleteNode(servicePath);
        this.registeredServices.delete(serviceName);
        console.log(`ServiceDiscovery: Unregistered service ${serviceName}`);
      }
    } catch (error) {
      console.error('ServiceDiscovery: Error unregistering service:', error.message);
    }
  }

  /**
   * Discover services
   * @param {string} serviceName - Service name (optional)
   * @returns {Promise<Array<Object>>} List of services
   */
  async discoverServices(serviceName = null) {
    try {
      await zookeeperClient.connect();

      if (serviceName) {
        // Discover specific service
        const servicePath = `${this.servicesPath}/${serviceName}`;
        const children = await zookeeperClient.listChildren(servicePath);
        
        const instances = await Promise.all(
          children.map(async (child) => {
            const childPath = `${servicePath}/${child}`;
            const node = await zookeeperClient.getNode(childPath);
            return {
              path: childPath,
              name: child,
              ...node.data
            };
          })
        );

        return instances;
      } else {
        // Discover all services
        const services = await zookeeperClient.listChildren(this.servicesPath);
        
        const allInstances = [];
        for (const service of services) {
          const instances = await this.discoverServices(service);
          allInstances.push(...instances);
        }

        return allInstances;
      }
    } catch (error) {
      console.error('ServiceDiscovery: Error discovering services:', error.message);
      return [];
    }
  }

  /**
   * Watch service changes
   * @param {string} serviceName - Service name
   * @param {Function} callback - Callback function
   */
  async watchService(serviceName, callback) {
    try {
      await zookeeperClient.connect();
      
      const servicePath = `${this.servicesPath}/${serviceName}`;
      
      const watch = () => {
        zookeeperClient.client.getChildren(
          servicePath,
          (event) => {
            // Service list changed, fetch new list
            this.discoverServices(serviceName).then(instances => {
              callback(instances);
              watch(); // Re-watch
            });
          },
          (error, children) => {
            if (error) {
              console.error('ServiceDiscovery: Watch error:', error.message);
              return;
            }
            
            // Initial callback
            this.discoverServices(serviceName).then(instances => {
              callback(instances);
            });
          }
        );
      };

      watch();
    } catch (error) {
      console.error('ServiceDiscovery: Error watching service:', error.message);
    }
  }

  /**
   * Get service endpoint
   * @param {string} serviceName - Service name
   * @returns {Promise<string|null>} Service endpoint URL
   */
  async getServiceEndpoint(serviceName) {
    try {
      const instances = await this.discoverServices(serviceName);
      if (instances.length === 0) {
        return null;
      }

      // Return first available instance (could implement load balancing)
      const instance = instances[0];
      return instance.url || instance.host || null;
    } catch (error) {
      console.error('ServiceDiscovery: Error getting service endpoint:', error.message);
      return null;
    }
  }
}

// Export singleton instance
const serviceDiscovery = new ServiceDiscovery();
module.exports = serviceDiscovery;


