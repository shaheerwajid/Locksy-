/*
 * Elasticsearch Indexer
 * Indexes data for search functionality
 */

const { getClient, isAvailable } = require('./elasticsearchClient');
const config = require('../../config');

const indexPrefix = config.elasticsearch.indexPrefix || 'cryptochat';

class Indexer {
  /**
   * Index user
   */
  async indexUser(user) {
    if (!(await isAvailable())) {
      return false;
    }

    try {
      const client = getClient();
      await client.index({
        index: `${indexPrefix}-users`,
        id: user._id.toString(),
        body: {
          id: user._id.toString(),
          name: user.nombre || user.name,
          email: user.email,
          createdAt: user.createdAt,
        },
      });

      return true;
    } catch (error) {
      console.error('Indexer: Failed to index user', error.message);
      return false;
    }
  }

  /**
   * Index message
   */
  async indexMessage(message) {
    if (!(await isAvailable())) {
      return false;
    }

    try {
      const client = getClient();
      await client.index({
        index: `${indexPrefix}-messages`,
        id: message._id.toString(),
        body: {
          id: message._id.toString(),
          from: message.de?.toString(),
          to: message.para?.toString(),
          content: message.mensaje || message.message,
          createdAt: message.createdAt,
        },
      });

      return true;
    } catch (error) {
      console.error('Indexer: Failed to index message', error.message);
      return false;
    }
  }

  /**
   * Index group
   */
  async indexGroup(group) {
    if (!(await isAvailable())) {
      return false;
    }

    try {
      const client = getClient();
      await client.index({
        index: `${indexPrefix}-groups`,
        id: group._id.toString(),
        body: {
          id: group._id.toString(),
          name: group.nombre || group.name,
          description: group.descripcion || group.description,
          createdAt: group.createdAt,
        },
      });

      return true;
    } catch (error) {
      console.error('Indexer: Failed to index group', error.message);
      return false;
    }
  }

  /**
   * Delete document
   */
  async deleteDocument(index, id) {
    if (!(await isAvailable())) {
      return false;
    }

    try {
      const client = getClient();
      await client.delete({
        index: `${indexPrefix}-${index}`,
        id: id.toString(),
      });

      return true;
    } catch (error) {
      if (error.statusCode !== 404) {
        console.error(`Indexer: Failed to delete from ${index}`, error.message);
      }
      return false;
    }
  }
}

// Export singleton instance
const indexer = new Indexer();
module.exports = indexer;

