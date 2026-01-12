/*
 * Report Viewer
 * API for viewing and querying reports
 */

const reportGenerator = require('./generator');
const cacheService = require('../../cache/cacheService');
const mongoose = require('mongoose');

class ReportViewer {
  /**
   * Get daily report
   * @param {Date} date - Report date
   * @returns {Promise<Object>} Daily report
   */
  async getDailyReport(date = new Date()) {
    try {
      const dateStr = date.toISOString().split('T')[0];
      const cacheKey = `report:daily:${dateStr}`;

      // Check cache first
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      // Generate if not cached
      return await reportGenerator.generateDailyReport(date);
    } catch (error) {
      console.error('ReportViewer: Error getting daily report:', error.message);
      throw error;
    }
  }

  /**
   * Get weekly report
   * @param {Date} weekStart - Week start date
   * @returns {Promise<Object>} Weekly report
   */
  async getWeeklyReport(weekStart = new Date()) {
    try {
      const dateStr = weekStart.toISOString().split('T')[0];
      const cacheKey = `report:weekly:${dateStr}`;

      // Check cache first
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      // Generate if not cached
      return await reportGenerator.generateWeeklyReport(weekStart);
    } catch (error) {
      console.error('ReportViewer: Error getting weekly report:', error.message);
      throw error;
    }
  }

  /**
   * Get monthly report
   * @param {Date} monthStart - Month start date
   * @returns {Promise<Object>} Monthly report
   */
  async getMonthlyReport(monthStart = new Date()) {
    try {
      const year = monthStart.getFullYear();
      const month = String(monthStart.getMonth() + 1).padStart(2, '0');
      const cacheKey = `report:monthly:${year}-${month}`;

      // Check cache first
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      // Generate if not cached
      return await reportGenerator.generateMonthlyReport(monthStart);
    } catch (error) {
      console.error('ReportViewer: Error getting monthly report:', error.message);
      throw error;
    }
  }

  /**
   * Get custom report
   * @param {Object} options - Report options
   * @returns {Promise<Object>} Custom report
   */
  async getCustomReport(options) {
    try {
      return await reportGenerator.generateCustomReport(options);
    } catch (error) {
      console.error('ReportViewer: Error getting custom report:', error.message);
      throw error;
    }
  }

  /**
   * List available reports
   * @param {Object} options - Query options
   * @returns {Promise<Array>} List of reports
   */
  async listReports(options = {}) {
    try {
      const Report = reportGenerator.getReportModel();
      const { type, limit = 50, skip = 0 } = options;

      const query = type ? { type } : {};

      const reports = await Report.find(query)
        .sort({ generatedAt: -1 })
        .limit(limit)
        .skip(skip)
        .select('type date weekStart month period summary generatedAt')
        .lean();

      return reports;
    } catch (error) {
      console.error('ReportViewer: Error listing reports:', error.message);
      throw error;
    }
  }

  /**
   * Export report
   * @param {string} reportId - Report ID
   * @param {string} format - Export format (json, csv)
   * @returns {Promise<Object>} Exported report
   */
  async exportReport(reportId, format = 'json') {
    try {
      const Report = reportGenerator.getReportModel();
      const report = await Report.findById(reportId).lean();

      if (!report) {
        throw new Error('Report not found');
      }

      if (format === 'json') {
        return {
          format: 'json',
          data: report
        };
      } else if (format === 'csv') {
        // Convert to CSV format
        const csv = this.convertToCSV(report);
        return {
          format: 'csv',
          data: csv
        };
      } else {
        throw new Error('Unsupported export format');
      }
    } catch (error) {
      console.error('ReportViewer: Error exporting report:', error.message);
      throw error;
    }
  }

  /**
   * Convert report to CSV
   * @param {Object} report - Report data
   * @returns {string} CSV string
   */
  convertToCSV(report) {
    // Simple CSV conversion for summary data
    const lines = [];
    
    // Header
    lines.push('Type,Date,Total Messages,Active Users,Active Groups');

    // Summary row
    const date = report.date || report.weekStart || report.month || new Date();
    const summary = report.summary || {};
    lines.push([
      report.type,
      date.toISOString().split('T')[0],
      summary.totalMessages || 0,
      summary.activeUsers || 0,
      summary.activeGroups || 0
    ].join(','));

    return lines.join('\n');
  }
}

// Export singleton instance
const reportViewer = new ReportViewer();
module.exports = reportViewer;


