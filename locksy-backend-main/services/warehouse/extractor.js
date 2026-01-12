/*
 * Data Warehouse Extractor
 * Extracts data from Metadata DBs for warehouse loading
 */

const mongoose = require('mongoose');
const cacheService = require('../cache/cacheService');

class DataExtractor {
  constructor() {
    this.batchSize = parseInt(process.env.EXTRACT_BATCH_SIZE || '1000');
  }

  /**
   * Extract users data
   * @param {Object} options - Extraction options
   * @returns {Promise<Array>} Extracted user data
   */
  async extractUsers(options = {}) {
    try {
      const Usuario = mongoose.model('Usuario');
      const since = options.since || new Date(Date.now() - 24 * 60 * 60 * 1000); // Default: last 24 hours
      
      const users = await Usuario.find({
        ...(options.since && { createdAt: { $gte: since } })
      })
        .select('_id nombre email codigoContacto online lastSeen createdAt')
        .lean();

      // Transform for warehouse
      return users.map(user => ({
        userId: user._id.toString(),
        nombre: user.nombre,
        email: user.email,
        codigoContacto: user.codigoContacto,
        online: user.online,
        lastSeen: user.lastSeen,
        createdAt: user.createdAt,
        extractedAt: new Date()
      }));
    } catch (error) {
      console.error('DataExtractor: Error extracting users:', error.message);
      throw error;
    }
  }

  /**
   * Extract messages data
   * @param {Object} options - Extraction options
   * @returns {Promise<Array>} Extracted message data
   */
  async extractMessages(options = {}) {
    try {
      const Mensaje = mongoose.model('Mensaje');
      const since = options.since || new Date(Date.now() - 24 * 60 * 60 * 1000); // Default: last 24 hours
      
      const messages = await Mensaje.find({
        ...(options.since && { createdAt: { $gte: since } })
      })
        .select('_id de para grupo mensaje.type createdAt')
        .lean();

      // Transform for warehouse
      return messages.map(msg => ({
        messageId: msg._id.toString(),
        from: msg.de,
        to: msg.para,
        groupId: msg.grupo?.toString() || null,
        messageType: msg.mensaje?.type || 'text',
        createdAt: msg.createdAt,
        extractedAt: new Date()
      }));
    } catch (error) {
      console.error('DataExtractor: Error extracting messages:', error.message);
      throw error;
    }
  }

  /**
   * Extract groups data
   * @param {Object} options - Extraction options
   * @returns {Promise<Array>} Extracted group data
   */
  async extractGroups(options = {}) {
    try {
      const Grupo = mongoose.model('Grupo');
      const GrupoUsuario = mongoose.model('GrupoUsuario');
      const since = options.since || new Date(Date.now() - 24 * 60 * 60 * 1000);
      
      const groups = await Grupo.find({
        ...(options.since && { fecha: { $gte: since } })
      })
        .select('_id codigo nombre usuarioCrea fecha createdAt')
        .lean();

      // Get member counts
      const groupsWithMembers = await Promise.all(
        groups.map(async (group) => {
          const memberCount = await GrupoUsuario.countDocuments({
            grupo: group._id
          });

          return {
            groupId: group._id.toString(),
            codigo: group.codigo,
            nombre: group.nombre,
            creatorId: group.usuarioCrea?.toString() || null,
            memberCount,
            fecha: group.fecha,
            createdAt: group.createdAt,
            extractedAt: new Date()
          };
        })
      );

      return groupsWithMembers;
    } catch (error) {
      console.error('DataExtractor: Error extracting groups:', error.message);
      throw error;
    }
  }

  /**
   * Extract contacts data
   * @param {Object} options - Extraction options
   * @returns {Promise<Array>} Extracted contact data
   */
  async extractContacts(options = {}) {
    try {
      const Contacto = mongoose.model('Contacto');
      const since = options.since || new Date(Date.now() - 24 * 60 * 60 * 1000);
      
      const contacts = await Contacto.find({
        ...(options.since && { fecha: { $gte: since } })
      })
        .select('_id usuario contacto activo fecha createdAt')
        .lean();

      // Transform for warehouse
      return contacts.map(contact => ({
        contactId: contact._id.toString(),
        userId: contact.usuario?.toString() || null,
        contactUserId: contact.contacto?.toString() || null,
        active: contact.activo === '1',
        fecha: contact.fecha,
        createdAt: contact.createdAt,
        extractedAt: new Date()
      }));
    } catch (error) {
      console.error('DataExtractor: Error extracting contacts:', error.message);
      throw error;
    }
  }

  /**
   * Extract all data types
   * @param {Object} options - Extraction options
   * @returns {Promise<Object>} Extracted data
   */
  async extractAll(options = {}) {
    try {
      const [users, messages, groups, contacts] = await Promise.all([
        this.extractUsers(options),
        this.extractMessages(options),
        this.extractGroups(options),
        this.extractContacts(options)
      ]);

      return {
        users,
        messages,
        groups,
        contacts,
        extractedAt: new Date(),
        summary: {
          usersCount: users.length,
          messagesCount: messages.length,
          groupsCount: groups.length,
          contactsCount: contacts.length
        }
      };
    } catch (error) {
      console.error('DataExtractor: Error extracting all data:', error.message);
      throw error;
    }
  }

  /**
   * Extract incremental data (since last extraction)
   * @param {Date} lastExtractionTime - Last extraction timestamp
   * @returns {Promise<Object>} Incremental data
   */
  async extractIncremental(lastExtractionTime) {
    try {
      const cacheKey = 'warehouse:last_extraction';
      const cached = await cacheService.get(cacheKey);
      const since = lastExtractionTime || (cached ? new Date(cached) : new Date(Date.now() - 24 * 60 * 60 * 1000));

      const data = await this.extractAll({ since });

      // Update last extraction time
      await cacheService.set(cacheKey, new Date().toISOString(), 86400 * 7); // 7 days TTL

      return {
        ...data,
        since,
        incremental: true
      };
    } catch (error) {
      console.error('DataExtractor: Error extracting incremental data:', error.message);
      throw error;
    }
  }
}

// Export singleton instance
const dataExtractor = new DataExtractor();
module.exports = dataExtractor;


