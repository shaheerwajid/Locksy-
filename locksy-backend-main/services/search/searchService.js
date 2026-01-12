/*
 * Search Service
 * Provides search functionality across different indices
 */

const { getClient, isAvailable } = require('./elasticsearchClient');
const config = require('../../config');

const indexPrefix = config.elasticsearch.indexPrefix || 'cryptochat';

class SearchService {
  /**
   * Search users
   */
  async searchUsers(query, limit = 10) {
    if (!(await isAvailable())) {
      return [];
    }

    try {
      const client = getClient();
      const result = await client.search({
        index: `${indexPrefix}-users`,
        body: {
          query: {
            multi_match: {
              query,
              fields: ['name', 'email'],
              fuzziness: 'AUTO',
            },
          },
          size: limit,
        },
      });

      return result.hits.hits.map(hit => hit._source);
    } catch (error) {
      console.error('SearchService: User search failed', error.message);
      return [];
    }
  }

  /**
   * Search messages
   */
  async searchMessages(query, userId = null, limit = 20) {
    if (!(await isAvailable())) {
      return [];
    }

    try {
      const client = getClient();
      const queryBody = {
        query: {
          bool: {
            must: [
              {
                multi_match: {
                  query,
                  fields: ['content'],
                  fuzziness: 'AUTO',
                },
              },
            ],
          },
        },
        size: limit,
      };

      // Filter by user if provided
      if (userId) {
        queryBody.query.bool.should = [
          { term: { from: userId.toString() } },
          { term: { to: userId.toString() } },
        ];
        queryBody.query.bool.minimum_should_match = 1;
      }

      const result = await client.search({
        index: `${indexPrefix}-messages`,
        body: queryBody,
      });

      return result.hits.hits.map(hit => hit._source);
    } catch (error) {
      console.error('SearchService: Message search failed', error.message);
      return [];
    }
  }

  /**
   * Search groups
   */
  async searchGroups(query, limit = 10) {
    if (!(await isAvailable())) {
      return [];
    }

    try {
      const client = getClient();
      const result = await client.search({
        index: `${indexPrefix}-groups`,
        body: {
          query: {
            multi_match: {
              query,
              fields: ['name', 'description'],
              fuzziness: 'AUTO',
            },
          },
          size: limit,
        },
      });

      return result.hits.hits.map(hit => hit._source);
    } catch (error) {
      console.error('SearchService: Group search failed', error.message);
      return [];
    }
  }

  /**
   * Aggregate search across all indices
   */
  async aggregateSearch(query, limit = 10) {
    const [users, messages, groups] = await Promise.all([
      this.searchUsers(query, limit),
      this.searchMessages(query, null, limit),
      this.searchGroups(query, limit),
    ]);

    return {
      users,
      messages,
      groups,
      total: users.length + messages.length + groups.length,
    };
  }
}

// Export singleton instance
const searchService = new SearchService();
module.exports = searchService;

