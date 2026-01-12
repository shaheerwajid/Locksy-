/*
 * Feed Service
 * Core feed generation logic
 */

const mongoose = require('mongoose');
const cacheService = require('../cache/cacheService');
const shardRouter = require('../shard-manager/shardRouter');

class FeedService {
  /**
   * Generate user feed
   * @param {string} userId - User ID
   * @param {Object} options - Options
   * @returns {Promise<Object>} User feed
   */
  async generateUserFeed(userId, options = {}) {
    try {
      const Mensaje = mongoose.model('Mensaje');
      const Contacto = mongoose.model('Contacto');
      const Grupo = mongoose.model('Grupo');
      const GrupoUsuario = mongoose.model('GrupoUsuario');

      // Get shards for user
      const shards = shardRouter.getShardsForQuery('usuarios', { _id: userId });

      // Aggregate feed from multiple sources
      const feed = {
        userId,
        messages: [],
        contacts: [],
        groups: [],
        timestamp: new Date()
      };

      // Get recent messages (limit from options or default 50)
      const messageLimit = options.messageLimit || 50;
      const messages = await Mensaje.find({
        $or: [
          { de: userId },
          { para: userId }
        ]
      })
        .sort({ createdAt: -1 })
        .limit(messageLimit)
        .populate('usuario', 'nombre avatar publicKey')
        .lean();

      feed.messages = messages;

      // Get contacts (limit from options or default 100)
      const contactLimit = options.contactLimit || 100;
      const contacts = await Contacto.find({
        $or: [
          { usuario: userId },
          { contacto: userId }
        ],
        activo: '1'
      })
        .populate('usuario', 'nombre avatar codigoContacto')
        .populate('contacto', 'nombre avatar codigoContacto')
        .limit(contactLimit)
        .lean();

      feed.contacts = contacts;

      // Get groups (limit from options or default 50)
      const groupLimit = options.groupLimit || 50;
      const grupoUsuarios = await GrupoUsuario.find({
        usuarioContacto: userId
      })
        .populate('grupo')
        .populate('grupo.usuarioCrea', 'nombre avatar codigoContacto')
        .limit(groupLimit)
        .lean();

      feed.groups = grupoUsuarios.map(gu => gu.grupo);

      return feed;
    } catch (error) {
      console.error('FeedService: Error generating user feed:', error.message);
      throw error;
    }
  }

  /**
   * Generate group feed
   * @param {string} groupId - Group ID
   * @param {Object} options - Options
   * @returns {Promise<Object>} Group feed
   */
  async generateGroupFeed(groupId, options = {}) {
    try {
      const Mensaje = mongoose.model('Mensaje');
      const Grupo = mongoose.model('Grupo');

      // Get group
      const group = await Grupo.findById(groupId)
        .populate('usuarioCrea', 'nombre avatar codigoContacto')
        .lean();

      if (!group) {
        throw new Error(`Group ${groupId} not found`);
      }

      // Get recent messages (limit from options or default 100)
      const messageLimit = options.messageLimit || 100;
      const messages = await Mensaje.find({
        grupo: groupId
      })
        .sort({ createdAt: -1 })
        .limit(messageLimit)
        .populate('usuario', 'nombre avatar')
        .lean();

      const feed = {
        groupId,
        group,
        messages,
        timestamp: new Date()
      };

      return feed;
    } catch (error) {
      console.error('FeedService: Error generating group feed:', error.message);
      throw error;
    }
  }

  /**
   * Generate activity feed
   * @param {string} userId - User ID
   * @param {Object} options - Options
   * @returns {Promise<Object>} Activity feed
   */
  async generateActivityFeed(userId, options = {}) {
    try {
      // Activity feed aggregates recent activities
      const feed = {
        userId,
        activities: [],
        timestamp: new Date()
      };

      // Get user feed as base for activity feed
      const userFeed = await this.generateUserFeed(userId, options);
      
      // Transform to activities
      feed.activities = [
        ...userFeed.messages.map(msg => ({
          type: 'message',
          data: msg,
          timestamp: msg.createdAt
        })),
        ...userFeed.contacts.map(contact => ({
          type: 'contact',
          data: contact,
          timestamp: contact.fecha
        })),
        ...userFeed.groups.map(group => ({
          type: 'group',
          data: group,
          timestamp: group.fecha
        }))
      ].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

      return feed;
    } catch (error) {
      console.error('FeedService: Error generating activity feed:', error.message);
      throw error;
    }
  }
}

// Export singleton instance
const feedService = new FeedService();
module.exports = feedService;


