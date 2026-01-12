/*
 * Feed Aggregator
 * Aggregates feeds from multiple sources
 */

const cacheService = require('../cache/cacheService');
const feedService = require('./feedService');

class FeedAggregator {
  /**
   * Aggregate user feed from multiple sources
   * @param {string} userId - User ID
   * @param {Object} options - Options
   * @returns {Promise<Object>} Aggregated feed
   */
  async aggregateUserFeed(userId, options = {}) {
    try {
      // Generate base feed
      const baseFeed = await feedService.generateUserFeed(userId, options);

      // Add aggregated statistics
      const aggregated = {
        ...baseFeed,
        statistics: {
          totalMessages: baseFeed.messages.length,
          totalContacts: baseFeed.contacts.length,
          totalGroups: baseFeed.groups.length,
          unreadMessages: baseFeed.messages.filter(m => !m.read).length
        },
        lastUpdated: new Date()
      };

      // Cache aggregated feed
      const cacheKey = `feed:user:${userId}`;
      await cacheService.set(cacheKey, aggregated, 300); // 5 minutes TTL

      return aggregated;
    } catch (error) {
      console.error('FeedAggregator: Error aggregating user feed:', error.message);
      throw error;
    }
  }

  /**
   * Aggregate group feed from multiple sources
   * @param {string} groupId - Group ID
   * @param {Object} options - Options
   * @returns {Promise<Object>} Aggregated feed
   */
  async aggregateGroupFeed(groupId, options = {}) {
    try {
      // Generate base feed
      const baseFeed = await feedService.generateGroupFeed(groupId, options);

      // Add aggregated statistics
      const aggregated = {
        ...baseFeed,
        statistics: {
          totalMessages: baseFeed.messages.length,
          groupMembers: baseFeed.group?.totalMembers || 0
        },
        lastUpdated: new Date()
      };

      // Cache aggregated feed
      const cacheKey = `feed:group:${groupId}`;
      await cacheService.set(cacheKey, aggregated, 300); // 5 minutes TTL

      return aggregated;
    } catch (error) {
      console.error('FeedAggregator: Error aggregating group feed:', error.message);
      throw error;
    }
  }

  /**
   * Aggregate activity feed
   * @param {string} userId - User ID
   * @param {Object} options - Options
   * @returns {Promise<Object>} Aggregated activity feed
   */
  async aggregateActivityFeed(userId, options = {}) {
    try {
      // Generate base feed
      const baseFeed = await feedService.generateActivityFeed(userId, options);

      // Add aggregated statistics
      const aggregated = {
        ...baseFeed,
        statistics: {
          totalActivities: baseFeed.activities.length,
          activitiesByType: this.groupActivitiesByType(baseFeed.activities)
        },
        lastUpdated: new Date()
      };

      // Cache aggregated feed
      const cacheKey = `feed:activity:${userId}`;
      await cacheService.set(cacheKey, aggregated, 300); // 5 minutes TTL

      return aggregated;
    } catch (error) {
      console.error('FeedAggregator: Error aggregating activity feed:', error.message);
      throw error;
    }
  }

  /**
   * Group activities by type
   * @param {Array<Object>} activities - Activities
   * @returns {Object} Activities grouped by type
   */
  groupActivitiesByType(activities) {
    const grouped = {};
    for (const activity of activities) {
      if (!grouped[activity.type]) {
        grouped[activity.type] = 0;
      }
      grouped[activity.type]++;
    }
    return grouped;
  }
}

// Export singleton instance
const feedAggregator = new FeedAggregator();
module.exports = feedAggregator;


