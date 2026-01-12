/*
 * Feed Generation Service
 * Generates personalized content feeds
 */

const producer = require('../queue/producer');
const cacheService = require('../cache/cacheService');
const shardRouter = require('../shard-manager/shardRouter');

class FeedGenerator {
  constructor() {
    this.generationTriggers = new Set();
  }

  /**
   * Generate user feed
   * @param {string} userId - User ID
   * @param {Object} options - Generation options
   */
  async generateUserFeed(userId, options = {}) {
    try {
      // Check cache first
      const cacheKey = `feed:user:${userId}`;
      const cached = await cacheService.get(cacheKey);
      if (cached && !options.force) {
        return cached;
      }

      // Queue feed generation task
      await producer.sendToQueue('feed_generation_queue', {
        type: 'user_feed',
        userId,
        data: options,
        timestamp: new Date().toISOString()
      });

      return {
        ok: true,
        message: 'Feed generation queued',
        userId
      };
    } catch (error) {
      console.error('FeedGenerator: Error generating user feed:', error.message);
      throw error;
    }
  }

  /**
   * Generate group feed
   * @param {string} groupId - Group ID
   * @param {Object} options - Generation options
   */
  async generateGroupFeed(groupId, options = {}) {
    try {
      // Check cache first
      const cacheKey = `feed:group:${groupId}`;
      const cached = await cacheService.get(cacheKey);
      if (cached && !options.force) {
        return cached;
      }

      // Queue feed generation task
      await producer.sendToQueue('feed_generation_queue', {
        type: 'group_feed',
        groupId,
        data: options,
        timestamp: new Date().toISOString()
      });

      return {
        ok: true,
        message: 'Feed generation queued',
        groupId
      };
    } catch (error) {
      console.error('FeedGenerator: Error generating group feed:', error.message);
      throw error;
    }
  }

  /**
   * Generate activity feed
   * @param {string} userId - User ID
   * @param {Object} options - Generation options
   */
  async generateActivityFeed(userId, options = {}) {
    try {
      // Check cache first
      const cacheKey = `feed:activity:${userId}`;
      const cached = await cacheService.get(cacheKey);
      if (cached && !options.force) {
        return cached;
      }

      // Queue feed generation task
      await producer.sendToQueue('feed_generation_queue', {
        type: 'activity_feed',
        userId,
        data: options,
        timestamp: new Date().toISOString()
      });

      return {
        ok: true,
        message: 'Activity feed generation queued',
        userId
      };
    } catch (error) {
      console.error('FeedGenerator: Error generating activity feed:', error.message);
      throw error;
    }
  }

  /**
   * Trigger feed generation on new content
   * @param {string} contentType - Content type (message, contact, group)
   * @param {Object} contentData - Content data
   */
  async triggerFeedGeneration(contentType, contentData) {
    try {
      switch (contentType) {
        case 'message':
          // Trigger feeds for message recipients
          if (contentData.para) {
            await this.generateUserFeed(contentData.para, { messageLimit: 50 });
          }
          if (contentData.grupo) {
            await this.generateGroupFeed(contentData.grupo, { messageLimit: 100 });
          }
          break;

        case 'contact':
          // Trigger feeds for both users
          if (contentData.usuario) {
            await this.generateUserFeed(contentData.usuario.toString(), { contactLimit: 100 });
          }
          if (contentData.contacto) {
            await this.generateUserFeed(contentData.contacto.toString(), { contactLimit: 100 });
          }
          break;

        case 'group':
          // Trigger feed for group members
          if (contentData.grupoId) {
            await this.generateGroupFeed(contentData.grupoId, { messageLimit: 100 });
          }
          break;

        default:
          console.warn(`FeedGenerator: Unknown content type: ${contentType}`);
      }
    } catch (error) {
      console.error('FeedGenerator: Error triggering feed generation:', error.message);
      // Don't throw - feed generation failure shouldn't block content creation
    }
  }

  /**
   * Get user feed
   * @param {string} userId - User ID
   * @returns {Promise<Object>} User feed
   */
  async getUserFeed(userId) {
    try {
      const cacheKey = `feed:user:${userId}`;
      const feed = await cacheService.get(cacheKey);
      
      if (!feed) {
        // Generate feed if not cached
        await this.generateUserFeed(userId);
        return {
          ok: true,
          message: 'Feed generation in progress',
          userId
        };
      }

      return {
        ok: true,
        feed
      };
    } catch (error) {
      console.error('FeedGenerator: Error getting user feed:', error.message);
      throw error;
    }
  }

  /**
   * Get group feed
   * @param {string} groupId - Group ID
   * @returns {Promise<Object>} Group feed
   */
  async getGroupFeed(groupId) {
    try {
      const cacheKey = `feed:group:${groupId}`;
      const feed = await cacheService.get(cacheKey);
      
      if (!feed) {
        // Generate feed if not cached
        await this.generateGroupFeed(groupId);
        return {
          ok: true,
          message: 'Feed generation in progress',
          groupId
        };
      }

      return {
        ok: true,
        feed
      };
    } catch (error) {
      console.error('FeedGenerator: Error getting group feed:', error.message);
      throw error;
    }
  }
}

// Export singleton instance
const feedGenerator = new FeedGenerator();
module.exports = feedGenerator;


