/*
 * Partition Strategy
 * Defines partitioning strategies for different collections
 */

const directoryPartitioner = require('./directoryPartitioner');

class PartitionStrategy {
  /**
   * Get partition strategy for collection
   * @param {string} collectionName - Collection name
   * @returns {Function} Partition function
   */
  static getStrategy(collectionName) {
    const strategies = {
      'usuarios': PartitionStrategy.partitionUser,
      'users': PartitionStrategy.partitionUser,
      'mensajes': PartitionStrategy.partitionMessage,
      'messages': PartitionStrategy.partitionMessage,
      'grupos': PartitionStrategy.partitionGroup,
      'groups': PartitionStrategy.partitionGroup,
      'contactos': PartitionStrategy.partitionContact,
      'contacts': PartitionStrategy.partitionContact
    };

    return strategies[collectionName.toLowerCase()] || PartitionStrategy.defaultPartition;
  }

  /**
   * Partition user document
   * @param {Object} userDoc - User document
   * @returns {string} Partition path
   */
  static partitionUser(userDoc) {
    // Use _id or codigoContacto for partitioning
    const partitionKey = userDoc._id?.toString() || userDoc.codigoContacto || userDoc.id;
    return directoryPartitioner.getUserPartition(partitionKey);
  }

  /**
   * Partition message document
   * @param {Object} messageDoc - Message document
   * @returns {string} Partition path
   */
  static partitionMessage(messageDoc) {
    // Partition by recipient (para field)
    const recipientId = messageDoc.para || messageDoc.recipient;
    const date = messageDoc.createdAt || messageDoc.fecha ? new Date(messageDoc.createdAt || messageDoc.fecha) : null;
    return directoryPartitioner.getMessagePartition(recipientId, date);
  }

  /**
   * Partition group document
   * @param {Object} groupDoc - Group document
   * @returns {string} Partition path
   */
  static partitionGroup(groupDoc) {
    // Partition by group code
    const groupCode = groupDoc.codigo || groupDoc.code;
    return directoryPartitioner.getGroupPartition(groupCode);
  }

  /**
   * Partition contact document
   * @param {Object} contactDoc - Contact document
   * @returns {string} Partition path
   */
  static partitionContact(contactDoc) {
    // Partition by user ID (usuario field)
    const userId = contactDoc.usuario?.toString() || contactDoc.userId;
    return directoryPartitioner.getContactPartition(userId);
  }

  /**
   * Default partition strategy
   * @param {Object} doc - Document
   * @returns {string} Partition path
   */
  static defaultPartition(doc) {
    // Default: partition by _id
    const id = doc._id?.toString() || doc.id;
    const partitionIndex = directoryPartitioner.hashToPartition(id);
    return `default/partition_${partitionIndex}`;
  }

  /**
   * Get partition key from document
   * @param {string} collectionName - Collection name
   * @param {Object} doc - Document
   * @returns {string} Partition key
   */
  static getPartitionKey(collectionName, doc) {
    const strategy = this.getStrategy(collectionName);
    return strategy(doc);
  }
}

module.exports = PartitionStrategy;


