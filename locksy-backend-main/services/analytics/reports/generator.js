/*
 * Report Generator
 * Generates analytics reports
 */

const mongoose = require('mongoose');
const dataProcessor = require('../../warehouse/processor');
const cacheService = require('../../cache/cacheService');

class ReportGenerator {
  /**
   * Generate daily report
   * @param {Date} date - Report date
   * @returns {Promise<Object>} Daily report
   */
  async generateDailyReport(date = new Date()) {
    try {
      const startDate = new Date(date);
      startDate.setHours(0, 0, 0, 0);
      const endDate = new Date(date);
      endDate.setHours(23, 59, 59, 999);

      const [messageStats, userActivity, groupStats] = await Promise.all([
        dataProcessor.aggregateMessagesByTime(startDate, endDate, 'hour'),
        dataProcessor.aggregateUserActivity(startDate, endDate),
        dataProcessor.aggregateGroupStatistics(startDate, endDate)
      ]);

      const report = {
        type: 'daily',
        date: startDate,
        messageStats,
        userActivity,
        groupStats,
        summary: {
          totalMessages: messageStats.reduce((sum, stat) => sum + stat.count, 0),
          activeUsers: userActivity.length,
          activeGroups: groupStats.length
        },
        generatedAt: new Date()
      };

      // Cache report
      const cacheKey = `report:daily:${startDate.toISOString().split('T')[0]}`;
      await cacheService.set(cacheKey, report, 86400 * 30); // 30 days TTL

      // Store in database
      await this.storeReport(report);

      return report;
    } catch (error) {
      console.error('ReportGenerator: Error generating daily report:', error.message);
      throw error;
    }
  }

  /**
   * Generate weekly report
   * @param {Date} weekStart - Week start date
   * @returns {Promise<Object>} Weekly report
   */
  async generateWeeklyReport(weekStart = new Date()) {
    try {
      const startDate = new Date(weekStart);
      startDate.setDate(startDate.getDate() - startDate.getDay()); // Start of week
      startDate.setHours(0, 0, 0, 0);
      const endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 6);
      endDate.setHours(23, 59, 59, 999);

      const [messageStats, userActivity, groupStats] = await Promise.all([
        dataProcessor.aggregateMessagesByTime(startDate, endDate, 'day'),
        dataProcessor.aggregateUserActivity(startDate, endDate),
        dataProcessor.aggregateGroupStatistics(startDate, endDate)
      ]);

      const report = {
        type: 'weekly',
        weekStart: startDate,
        weekEnd: endDate,
        messageStats,
        userActivity,
        groupStats,
        summary: {
          totalMessages: messageStats.reduce((sum, stat) => sum + stat.count, 0),
          activeUsers: userActivity.length,
          activeGroups: groupStats.length,
          averageMessagesPerDay: messageStats.length > 0 ? messageStats.reduce((sum, stat) => sum + stat.count, 0) / messageStats.length : 0
        },
        generatedAt: new Date()
      };

      // Cache report
      const cacheKey = `report:weekly:${startDate.toISOString().split('T')[0]}`;
      await cacheService.set(cacheKey, report, 86400 * 90); // 90 days TTL

      // Store in database
      await this.storeReport(report);

      return report;
    } catch (error) {
      console.error('ReportGenerator: Error generating weekly report:', error.message);
      throw error;
    }
  }

  /**
   * Generate monthly report
   * @param {Date} monthStart - Month start date
   * @returns {Promise<Object>} Monthly report
   */
  async generateMonthlyReport(monthStart = new Date()) {
    try {
      const startDate = new Date(monthStart.getFullYear(), monthStart.getMonth(), 1);
      startDate.setHours(0, 0, 0, 0);
      const endDate = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0);
      endDate.setHours(23, 59, 59, 999);

      const [messageStats, userActivity, groupStats] = await Promise.all([
        dataProcessor.aggregateMessagesByTime(startDate, endDate, 'day'),
        dataProcessor.aggregateUserActivity(startDate, endDate),
        dataProcessor.aggregateGroupStatistics(startDate, endDate)
      ]);

      const report = {
        type: 'monthly',
        month: startDate,
        messageStats,
        userActivity,
        groupStats,
        summary: {
          totalMessages: messageStats.reduce((sum, stat) => sum + stat.count, 0),
          activeUsers: userActivity.length,
          activeGroups: groupStats.length,
          averageMessagesPerDay: messageStats.length > 0 ? messageStats.reduce((sum, stat) => sum + stat.count, 0) / messageStats.length : 0,
          topUsers: userActivity.slice(0, 10).map(u => ({
            userId: u.userId,
            messageCount: u.messageCount
          }))
        },
        generatedAt: new Date()
      };

      // Cache report
      const cacheKey = `report:monthly:${startDate.getFullYear()}-${String(startDate.getMonth() + 1).padStart(2, '0')}`;
      await cacheService.set(cacheKey, report, 86400 * 365); // 1 year TTL

      // Store in database
      await this.storeReport(report);

      return report;
    } catch (error) {
      console.error('ReportGenerator: Error generating monthly report:', error.message);
      throw error;
    }
  }

  /**
   * Generate custom report
   * @param {Object} options - Report options
   * @returns {Promise<Object>} Custom report
   */
  async generateCustomReport(options) {
    try {
      const { startDate, endDate, metrics, groupBy } = options;

      if (!startDate || !endDate) {
        throw new Error('Start date and end date are required');
      }

      const report = {
        type: 'custom',
        period: { startDate, endDate },
        metrics: metrics || ['messages', 'users', 'groups'],
        groupBy: groupBy || 'day',
        data: {},
        generatedAt: new Date()
      };

      // Generate requested metrics
      if (report.metrics.includes('messages')) {
        report.data.messages = await dataProcessor.aggregateMessagesByTime(startDate, endDate, groupBy);
      }

      if (report.metrics.includes('users')) {
        report.data.users = await dataProcessor.aggregateUserActivity(startDate, endDate);
      }

      if (report.metrics.includes('groups')) {
        report.data.groups = await dataProcessor.aggregateGroupStatistics(startDate, endDate);
      }

      return report;
    } catch (error) {
      console.error('ReportGenerator: Error generating custom report:', error.message);
      throw error;
    }
  }

  /**
   * Store report in database
   * @param {Object} report - Report data
   */
  async storeReport(report) {
    try {
      const Report = this.getReportModel();
      await Report.create(report);
    } catch (error) {
      console.error('ReportGenerator: Error storing report:', error.message);
      // Don't throw - report generation shouldn't fail if storage fails
    }
  }

  /**
   * Get Report model
   * @returns {mongoose.Model} Report model
   */
  getReportModel() {
    try {
      return mongoose.model('Report');
    } catch (error) {
      // Model doesn't exist, create schema
      const reportSchema = new mongoose.Schema({
        type: { type: String, required: true, index: true },
        date: Date,
        weekStart: Date,
        month: Date,
        period: {
          startDate: Date,
          endDate: Date
        },
        messageStats: mongoose.Schema.Types.Mixed,
        userActivity: mongoose.Schema.Types.Mixed,
        groupStats: mongoose.Schema.Types.Mixed,
        summary: mongoose.Schema.Types.Mixed,
        data: mongoose.Schema.Types.Mixed,
        generatedAt: { type: Date, default: Date.now, index: true }
      }, {
        collection: 'analytics_reports',
        timestamps: true
      });

      reportSchema.index({ type: 1, generatedAt: -1 });
      reportSchema.index({ generatedAt: -1 });

      return mongoose.model('Report', reportSchema);
    }
  }
}

// Export singleton instance
const reportGenerator = new ReportGenerator();
module.exports = reportGenerator;


