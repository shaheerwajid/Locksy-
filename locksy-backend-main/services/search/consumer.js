/*
 * Search Indexing Consumer
 * Consumes from indexing queue and indexes data in Elasticsearch
 */

const MessageConsumer = require('../queue/consumer');
const indexer = require('./indexer');
const Mensaje = require('../../models/mensaje');
const Usuario = require('../../models/usuario');
const Grupo = require('../../models/grupo');

class SearchIndexingConsumer extends MessageConsumer {
  constructor() {
    super('indexing', {
      prefetch: 5 // Process up to 5 indexing tasks at a time
    });
  }

  /**
   * Process indexing message
   * @param {Object} message - Message from queue
   * @param {Function} handler - Handler function (not used, but required by base class)
   */
  async processMessage(message, handler) {
    try {
      const { type, action, data } = message;

      if (action !== 'index') {
        console.warn(`SearchIndexingConsumer: Unknown action: ${action}`);
        return;
      }

      switch (type) {
        case 'user':
          await this.indexUser(data);
          break;

        case 'message':
          await this.indexMessage(data);
          break;

        case 'group':
          await this.indexGroup(data);
          break;

        default:
          console.warn(`SearchIndexingConsumer: Unknown type: ${type}`);
      }
    } catch (error) {
      console.error('SearchIndexingConsumer: Error processing message:', error.message);
      throw error; // Re-throw to trigger retry mechanism
    }
  }

  /**
   * Index user
   * @param {Object} data - User data (may be ID or full user object)
   */
  async indexUser(data) {
    try {
      let user;
      if (data._id || data.id) {
        // If we have an ID, fetch the full user
        const userId = data._id || data.id;
        user = await Usuario.findById(userId);
        if (!user) {
          console.warn(`SearchIndexingConsumer: User not found: ${userId}`);
          return;
        }
      } else {
        // Assume data is the user object
        user = data;
      }

      await indexer.indexUser(user);
      console.log(`SearchIndexingConsumer: Indexed user ${user._id}`);
    } catch (error) {
      console.error('SearchIndexingConsumer: Error indexing user:', error.message);
      throw error;
    }
  }

  /**
   * Index message
   * @param {Object} data - Message data (may be ID or full message object)
   */
  async indexMessage(data) {
    try {
      let message;
      if (data._id || data.id) {
        // If we have an ID, fetch the full message
        const messageId = data._id || data.id;
        message = await Mensaje.findById(messageId);
        if (!message) {
          console.warn(`SearchIndexingConsumer: Message not found: ${messageId}`);
          return;
        }
      } else {
        // Assume data is the message object
        message = data;
      }

      await indexer.indexMessage(message);
      console.log(`SearchIndexingConsumer: Indexed message ${message._id}`);
    } catch (error) {
      console.error('SearchIndexingConsumer: Error indexing message:', error.message);
      throw error;
    }
  }

  /**
   * Index group
   * @param {Object} data - Group data (may be ID or full group object)
   */
  async indexGroup(data) {
    try {
      let group;
      if (data._id || data.id) {
        // If we have an ID, fetch the full group
        const groupId = data._id || data.id;
        group = await Grupo.findById(groupId);
        if (!group) {
          console.warn(`SearchIndexingConsumer: Group not found: ${groupId}`);
          return;
        }
      } else {
        // Assume data is the group object
        group = data;
      }

      await indexer.indexGroup(group);
      console.log(`SearchIndexingConsumer: Indexed group ${group._id}`);
    } catch (error) {
      console.error('SearchIndexingConsumer: Error indexing group:', error.message);
      throw error;
    }
  }
}

// Export singleton instance
const searchIndexingConsumer = new SearchIndexingConsumer();
module.exports = searchIndexingConsumer;






