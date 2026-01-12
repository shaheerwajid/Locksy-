/*
 * Data Processing Abstraction Layer
 * Supports MongoDB aggregations with design for future Hadoop/Spark integration
 */

const mongoose = require('mongoose');

class DataProcessor {
  constructor() {
    this.processingType = process.env.PROCESSING_TYPE || 'mongodb'; // mongodb, hadoop, spark
  }

  /**
   * Process data using MongoDB aggregations
   * @param {string} collection - Collection name
   * @param {Array} pipeline - Aggregation pipeline
   * @returns {Promise<Array>} Processed results
   */
  async processWithMongoDB(collection, pipeline) {
    try {
      const Model = mongoose.model(collection);
      const results = await Model.aggregate(pipeline);
      return results;
    } catch (error) {
      console.error('DataProcessor: MongoDB processing error:', error.message);
      throw error;
    }
  }

  /**
   * Process data (abstracted)
   * @param {string} collection - Collection name
   * @param {Array} pipeline - Processing pipeline
   * @returns {Promise<Array>} Processed results
   */
  async process(collection, pipeline) {
    switch (this.processingType) {
      case 'mongodb':
        return this.processWithMongoDB(collection, pipeline);
      case 'hadoop':
        // Future: Hadoop/MapReduce processing
        throw new Error('Hadoop processing not yet implemented');
      case 'spark':
        // Future: Spark processing
        throw new Error('Spark processing not yet implemented');
      default:
        return this.processWithMongoDB(collection, pipeline);
    }
  }

  /**
   * Aggregate messages by time period
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @param {string} period - Period (hour, day, week, month)
   * @returns {Promise<Array>} Aggregated results
   */
  async aggregateMessagesByTime(startDate, endDate, period = 'day') {
    const pipeline = [
      {
        $match: {
          createdAt: {
            $gte: startDate,
            $lte: endDate
          }
        }
      },
      {
        $group: {
          _id: this.getTimeGroupExpression(period),
          count: { $sum: 1 },
          uniqueUsers: { $addToSet: '$from' },
          uniqueRecipients: { $addToSet: '$to' }
        }
      },
      {
        $project: {
          period: '$_id',
          count: 1,
          uniqueUsersCount: { $size: '$uniqueUsers' },
          uniqueRecipientsCount: { $size: '$uniqueRecipients' }
        }
      },
      {
        $sort: { period: 1 }
      }
    ];

    return this.process('WarehouseMessage', pipeline);
  }

  /**
   * Aggregate user activity
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Array>} Aggregated results
   */
  async aggregateUserActivity(startDate, endDate) {
    const pipeline = [
      {
        $match: {
          createdAt: {
            $gte: startDate,
            $lte: endDate
          }
        }
      },
      {
        $group: {
          _id: '$from',
          messageCount: { $sum: 1 },
          lastActivity: { $max: '$createdAt' }
        }
      },
      {
        $project: {
          userId: '$_id',
          messageCount: 1,
          lastActivity: 1
        }
      },
      {
        $sort: { messageCount: -1 }
      }
    ];

    return this.process('WarehouseMessage', pipeline);
  }

  /**
   * Aggregate group statistics
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Array>} Aggregated results
   */
  async aggregateGroupStatistics(startDate, endDate) {
    const pipeline = [
      {
        $match: {
          createdAt: {
            $gte: startDate,
            $lte: endDate
          },
          groupId: { $ne: null }
        }
      },
      {
        $group: {
          _id: '$groupId',
          messageCount: { $sum: 1 },
          uniqueSenders: { $addToSet: '$from' }
        }
      },
      {
        $project: {
          groupId: '$_id',
          messageCount: 1,
          uniqueSendersCount: { $size: '$uniqueSenders' }
        }
      },
      {
        $sort: { messageCount: -1 }
      }
    ];

    return this.process('WarehouseMessage', pipeline);
  }

  /**
   * Get time group expression for aggregation
   * @param {string} period - Period (hour, day, week, month)
   * @returns {Object} MongoDB expression
   */
  getTimeGroupExpression(period) {
    const expressions = {
      hour: {
        year: { $year: '$createdAt' },
        month: { $month: '$createdAt' },
        day: { $dayOfMonth: '$createdAt' },
        hour: { $hour: '$createdAt' }
      },
      day: {
        year: { $year: '$createdAt' },
        month: { $month: '$createdAt' },
        day: { $dayOfMonth: '$createdAt' }
      },
      week: {
        year: { $year: '$createdAt' },
        week: { $week: '$createdAt' }
      },
      month: {
        year: { $year: '$createdAt' },
        month: { $month: '$createdAt' }
      }
    };

    return expressions[period] || expressions.day;
  }

  /**
   * Set processing type
   * @param {string} type - Processing type (mongodb, hadoop, spark)
   */
  setProcessingType(type) {
    this.processingType = type;
  }
}

// Export singleton instance
const dataProcessor = new DataProcessor();
module.exports = dataProcessor;


