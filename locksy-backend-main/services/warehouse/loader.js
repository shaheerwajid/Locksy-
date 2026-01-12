/*
 * Data Warehouse Loader
 * Loads extracted data into warehouse
 */

const mongoose = require('mongoose');
const cacheService = require('../cache/cacheService');

class DataLoader {
  constructor() {
    this.batchSize = parseInt(process.env.LOAD_BATCH_SIZE || '1000');
  }

  /**
   * Load users into warehouse
   * @param {Array<Object>} users - User data
   * @returns {Promise<Object>} Load result
   */
  async loadUsers(users) {
    try {
      const WarehouseUser = this.getWarehouseUserModel();
      
      // Batch insert
      const batches = this.chunkArray(users, this.batchSize);
      let loaded = 0;

      for (const batch of batches) {
        // Upsert users (update if exists, insert if not)
        const operations = batch.map(user => ({
          updateOne: {
            filter: { userId: user.userId },
            update: { $set: user },
            upsert: true
          }
        }));

        await WarehouseUser.bulkWrite(operations);
        loaded += batch.length;
      }

      return {
        success: true,
        loaded,
        total: users.length
      };
    } catch (error) {
      console.error('DataLoader: Error loading users:', error.message);
      throw error;
    }
  }

  /**
   * Load messages into warehouse
   * @param {Array<Object>} messages - Message data
   * @returns {Promise<Object>} Load result
   */
  async loadMessages(messages) {
    try {
      const WarehouseMessage = this.getWarehouseMessageModel();
      
      // Batch insert
      const batches = this.chunkArray(messages, this.batchSize);
      let loaded = 0;

      for (const batch of batches) {
        await WarehouseMessage.insertMany(batch, { ordered: false });
        loaded += batch.length;
      }

      return {
        success: true,
        loaded,
        total: messages.length
      };
    } catch (error) {
      console.error('DataLoader: Error loading messages:', error.message);
      throw error;
    }
  }

  /**
   * Load groups into warehouse
   * @param {Array<Object>} groups - Group data
   * @returns {Promise<Object>} Load result
   */
  async loadGroups(groups) {
    try {
      const WarehouseGroup = this.getWarehouseGroupModel();
      
      // Batch insert
      const batches = this.chunkArray(groups, this.batchSize);
      let loaded = 0;

      for (const batch of batches) {
        const operations = batch.map(group => ({
          updateOne: {
            filter: { groupId: group.groupId },
            update: { $set: group },
            upsert: true
          }
        }));

        await WarehouseGroup.bulkWrite(operations);
        loaded += batch.length;
      }

      return {
        success: true,
        loaded,
        total: groups.length
      };
    } catch (error) {
      console.error('DataLoader: Error loading groups:', error.message);
      throw error;
    }
  }

  /**
   * Load contacts into warehouse
   * @param {Array<Object>} contacts - Contact data
   * @returns {Promise<Object>} Load result
   */
  async loadContacts(contacts) {
    try {
      const WarehouseContact = this.getWarehouseContactModel();
      
      // Batch insert
      const batches = this.chunkArray(contacts, this.batchSize);
      let loaded = 0;

      for (const batch of batches) {
        await WarehouseContact.insertMany(batch, { ordered: false });
        loaded += batch.length;
      }

      return {
        success: true,
        loaded,
        total: contacts.length
      };
    } catch (error) {
      console.error('DataLoader: Error loading contacts:', error.message);
      throw error;
    }
  }

  /**
   * Load all data into warehouse
   * @param {Object} data - Extracted data
   * @returns {Promise<Object>} Load results
   */
  async loadAll(data) {
    try {
      const [usersResult, messagesResult, groupsResult, contactsResult] = await Promise.all([
        this.loadUsers(data.users),
        this.loadMessages(data.messages),
        this.loadGroups(data.groups),
        this.loadContacts(data.contacts)
      ]);

      return {
        success: true,
        users: usersResult,
        messages: messagesResult,
        groups: groupsResult,
        contacts: contactsResult,
        loadedAt: new Date()
      };
    } catch (error) {
      console.error('DataLoader: Error loading all data:', error.message);
      throw error;
    }
  }

  /**
   * Get Warehouse User model
   * @returns {mongoose.Model} Warehouse User model
   */
  getWarehouseUserModel() {
    try {
      return mongoose.model('WarehouseUser');
    } catch (error) {
      // Model doesn't exist, create schema
      const userSchema = new mongoose.Schema({
        userId: { type: String, required: true, unique: true, index: true },
        nombre: String,
        email: String,
        codigoContacto: String,
        online: Boolean,
        lastSeen: Date,
        createdAt: Date,
        extractedAt: Date
      }, {
        collection: 'warehouse_users',
        timestamps: true
      });

      userSchema.index({ createdAt: -1 });
      userSchema.index({ extractedAt: -1 });

      return mongoose.model('WarehouseUser', userSchema);
    }
  }

  /**
   * Get Warehouse Message model
   * @returns {mongoose.Model} Warehouse Message model
   */
  getWarehouseMessageModel() {
    try {
      return mongoose.model('WarehouseMessage');
    } catch (error) {
      // Model doesn't exist, create schema
      const messageSchema = new mongoose.Schema({
        messageId: { type: String, required: true, unique: true, index: true },
        from: { type: String, index: true },
        to: { type: String, index: true },
        groupId: { type: String, index: true },
        messageType: String,
        createdAt: { type: Date, index: true },
        extractedAt: Date
      }, {
        collection: 'warehouse_messages',
        timestamps: true
      });

      messageSchema.index({ createdAt: -1 });
      messageSchema.index({ from: 1, createdAt: -1 });
      messageSchema.index({ to: 1, createdAt: -1 });
      messageSchema.index({ groupId: 1, createdAt: -1 });

      return mongoose.model('WarehouseMessage', messageSchema);
    }
  }

  /**
   * Get Warehouse Group model
   * @returns {mongoose.Model} Warehouse Group model
   */
  getWarehouseGroupModel() {
    try {
      return mongoose.model('WarehouseGroup');
    } catch (error) {
      // Model doesn't exist, create schema
      const groupSchema = new mongoose.Schema({
        groupId: { type: String, required: true, unique: true, index: true },
        codigo: String,
        nombre: String,
        creatorId: { type: String, index: true },
        memberCount: Number,
        fecha: Date,
        createdAt: Date,
        extractedAt: Date
      }, {
        collection: 'warehouse_groups',
        timestamps: true
      });

      groupSchema.index({ createdAt: -1 });
      groupSchema.index({ creatorId: 1 });

      return mongoose.model('WarehouseGroup', groupSchema);
    }
  }

  /**
   * Get Warehouse Contact model
   * @returns {mongoose.Model} Warehouse Contact model
   */
  getWarehouseContactModel() {
    try {
      return mongoose.model('WarehouseContact');
    } catch (error) {
      // Model doesn't exist, create schema
      const contactSchema = new mongoose.Schema({
        contactId: { type: String, required: true, unique: true, index: true },
        userId: { type: String, index: true },
        contactUserId: { type: String, index: true },
        active: Boolean,
        fecha: Date,
        createdAt: Date,
        extractedAt: Date
      }, {
        collection: 'warehouse_contacts',
        timestamps: true
      });

      contactSchema.index({ userId: 1, createdAt: -1 });
      contactSchema.index({ contactUserId: 1, createdAt: -1 });
      contactSchema.index({ createdAt: -1 });

      return mongoose.model('WarehouseContact', contactSchema);
    }
  }

  /**
   * Chunk array into batches
   * @param {Array} array - Array to chunk
   * @param {number} size - Batch size
   * @returns {Array<Array>} Chunked arrays
   */
  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}

// Export singleton instance
const dataLoader = new DataLoader();
module.exports = dataLoader;


