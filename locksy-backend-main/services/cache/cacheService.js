/*
 * Cache Service
 * Abstraction layer for caching operations with TTL management
 */

const { getRedisClient, isConnected } = require('./redisClient');

class CacheService {
  constructor() {
    this.redis = getRedisClient();
    this.defaultTTL = 3600; // 1 hour in seconds
  }

  /**
   * Get value from cache
   */
  async get(key) {
    if (!isConnected()) {
      return null;
    }

    try {
      const value = await this.redis.get(key);
      if (value) {
        return JSON.parse(value);
      }
      return null;
    } catch (error) {
      console.error(`Cache: Error getting key ${key}:`, error.message);
      return null;
    }
  }

  /**
   * Set value in cache with TTL
   */
  async set(key, value, ttl = this.defaultTTL) {
    if (!isConnected()) {
      return false;
    }

    try {
      const stringValue = JSON.stringify(value);
      await this.redis.setex(key, ttl, stringValue);
      return true;
    } catch (error) {
      console.error(`Cache: Error setting key ${key}:`, error.message);
      return false;
    }
  }

  /**
   * Delete key from cache
   */
  async delete(key) {
    if (!isConnected()) {
      return false;
    }

    try {
      await this.redis.del(key);
      return true;
    } catch (error) {
      console.error(`Cache: Error deleting key ${key}:`, error.message);
      return false;
    }
  }

  /**
   * Delete multiple keys matching pattern
   */
  async deletePattern(pattern) {
    if (!isConnected()) {
      return false;
    }

    try {
      const keys = await this.redis.keys(pattern);
      if (keys.length > 0) {
        await this.redis.del(...keys);
      }
      return true;
    } catch (error) {
      console.error(`Cache: Error deleting pattern ${pattern}:`, error.message);
      return false;
    }
  }

  /**
   * Check if key exists
   */
  async exists(key) {
    if (!isConnected()) {
      return false;
    }

    try {
      const result = await this.redis.exists(key);
      return result === 1;
    } catch (error) {
      console.error(`Cache: Error checking key ${key}:`, error.message);
      return false;
    }
  }

  /**
   * Get TTL for key
   */
  async getTTL(key) {
    if (!isConnected()) {
      return -1;
    }

    try {
      return await this.redis.ttl(key);
    } catch (error) {
      console.error(`Cache: Error getting TTL for key ${key}:`, error.message);
      return -1;
    }
  }

  /**
   * Increment value
   */
  async increment(key, amount = 1) {
    if (!isConnected()) {
      return null;
    }

    try {
      return await this.redis.incrby(key, amount);
    } catch (error) {
      console.error(`Cache: Error incrementing key ${key}:`, error.message);
      return null;
    }
  }

  /**
   * Cache helper methods with specific TTLs
   */

  // User profile cache: 1 hour
  async cacheUser(userId, userData) {
    return this.set(`user:${userId}`, userData, 3600);
  }

  async getUser(userId) {
    return this.get(`user:${userId}`);
  }

  async invalidateUser(userId) {
    return this.delete(`user:${userId}`);
  }

  // Group metadata cache: 30 minutes
  async cacheGroup(groupId, groupData) {
    return this.set(`group:${groupId}`, groupData, 1800);
  }

  async getGroup(groupId) {
    return this.get(`group:${groupId}`);
  }

  async invalidateGroup(groupId) {
    return this.delete(`group:${groupId}`);
  }

  // Message metadata cache: 5 minutes
  async cacheMessage(messageId, messageData) {
    return this.set(`message:${messageId}`, messageData, 300);
  }

  async getMessage(messageId) {
    return this.get(`message:${messageId}`);
  }

  // Contact list cache: 15 minutes
  async cacheContacts(userId, contacts) {
    return this.set(`contacts:${userId}`, contacts, 900);
  }

  async getContacts(userId) {
    return this.get(`contacts:${userId}`);
  }

  async invalidateContacts(userId) {
    return this.delete(`contacts:${userId}`);
  }
}

// Export singleton instance
const cacheService = new CacheService();
module.exports = cacheService;

