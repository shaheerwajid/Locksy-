/*
 * Distributed Scheduler
 * Manages job execution for data processing
 */

const cron = require('node-cron');
const dataExtractor = require('./extractor');
const dataLoader = require('./loader');
const dataProcessor = require('./processor');
const cacheService = require('../cache/cacheService');

class DistributedScheduler {
  constructor() {
    this.jobs = new Map();
    this.jobHistory = [];
    this.maxHistorySize = 100;
  }

  /**
   * Start scheduler
   */
  start() {
    console.log('DistributedScheduler: Starting scheduler...');

    // Schedule ETL job (daily at 2 AM)
    this.scheduleJob('etl', '0 2 * * *', async () => {
      await this.runETLJob();
    });

    // Schedule aggregation job (hourly)
    this.scheduleJob('aggregation', '0 * * * *', async () => {
      await this.runAggregationJob();
    });

    // Schedule report generation (daily at 6 AM)
    this.scheduleJob('report', '0 6 * * *', async () => {
      await this.runReportJob();
    });

    console.log('DistributedScheduler: Scheduler started');
  }

  /**
   * Stop scheduler
   */
  stop() {
    for (const [jobId, task] of this.jobs.entries()) {
      task.stop();
      this.jobs.delete(jobId);
    }
    console.log('DistributedScheduler: Scheduler stopped');
  }

  /**
   * Schedule a job
   * @param {string} jobId - Job ID
   * @param {string} cronExpression - Cron expression
   * @param {Function} jobFunction - Job function
   */
  scheduleJob(jobId, cronExpression, jobFunction) {
    if (this.jobs.has(jobId)) {
      console.warn(`DistributedScheduler: Job ${jobId} already scheduled`);
      return;
    }

    const task = cron.schedule(cronExpression, async () => {
      const startTime = new Date();
      console.log(`DistributedScheduler: Starting job ${jobId} at ${startTime.toISOString()}`);

      try {
        await jobFunction();
        const endTime = new Date();
        const duration = endTime - startTime;

        this.recordJobHistory({
          jobId,
          status: 'success',
          startTime,
          endTime,
          duration
        });

        console.log(`DistributedScheduler: Job ${jobId} completed in ${duration}ms`);
      } catch (error) {
        const endTime = new Date();
        const duration = endTime - startTime;

        this.recordJobHistory({
          jobId,
          status: 'failed',
          startTime,
          endTime,
          duration,
          error: error.message
        });

        console.error(`DistributedScheduler: Job ${jobId} failed:`, error.message);
      }
    }, {
      scheduled: true,
      timezone: 'UTC'
    });

    this.jobs.set(jobId, task);
    console.log(`DistributedScheduler: Scheduled job ${jobId} with expression ${cronExpression}`);
  }

  /**
   * Run ETL job
   */
  async runETLJob() {
    try {
      console.log('ETL Job: Starting extraction...');
      
      // Extract incremental data
      const extractedData = await dataExtractor.extractIncremental();

      console.log(`ETL Job: Extracted ${extractedData.summary.usersCount} users, ${extractedData.summary.messagesCount} messages, ${extractedData.summary.groupsCount} groups, ${extractedData.summary.contactsCount} contacts`);

      // Load into warehouse
      console.log('ETL Job: Loading into warehouse...');
      const loadResult = await dataLoader.loadAll(extractedData);

      console.log('ETL Job: Completed successfully', loadResult);
      return loadResult;
    } catch (error) {
      console.error('ETL Job: Error:', error.message);
      throw error;
    }
  }

  /**
   * Run aggregation job
   */
  async runAggregationJob() {
    try {
      console.log('Aggregation Job: Starting...');

      const endDate = new Date();
      const startDate = new Date(endDate.getTime() - 24 * 60 * 60 * 1000); // Last 24 hours

      // Aggregate messages by time
      const messageAggregates = await dataProcessor.aggregateMessagesByTime(startDate, endDate, 'hour');

      // Aggregate user activity
      const userActivity = await dataProcessor.aggregateUserActivity(startDate, endDate);

      // Aggregate group statistics
      const groupStats = await dataProcessor.aggregateGroupStatistics(startDate, endDate);

      // Store aggregates
      await this.storeAggregates({
        messageAggregates,
        userActivity,
        groupStats,
        period: { startDate, endDate },
        generatedAt: new Date()
      });

      console.log('Aggregation Job: Completed successfully');
      return {
        messageAggregates: messageAggregates.length,
        userActivity: userActivity.length,
        groupStats: groupStats.length
      };
    } catch (error) {
      console.error('Aggregation Job: Error:', error.message);
      throw error;
    }
  }

  /**
   * Run report generation job
   */
  async runReportJob() {
    try {
      console.log('Report Job: Starting...');

      const endDate = new Date();
      const startDate = new Date(endDate.getTime() - 7 * 24 * 60 * 60 * 1000); // Last 7 days

      // Generate daily reports
      const dailyReports = await dataProcessor.aggregateMessagesByTime(startDate, endDate, 'day');

      // Generate user activity report
      const userActivityReport = await dataProcessor.aggregateUserActivity(startDate, endDate);

      // Generate group statistics report
      const groupStatsReport = await dataProcessor.aggregateGroupStatistics(startDate, endDate);

      // Store reports
      await this.storeReports({
        dailyReports,
        userActivityReport,
        groupStatsReport,
        period: { startDate, endDate },
        generatedAt: new Date()
      });

      console.log('Report Job: Completed successfully');
      return {
        dailyReports: dailyReports.length,
        userActivityReport: userActivityReport.length,
        groupStatsReport: groupStatsReport.length
      };
    } catch (error) {
      console.error('Report Job: Error:', error.message);
      throw error;
    }
  }

  /**
   * Store aggregates
   * @param {Object} aggregates - Aggregate data
   */
  async storeAggregates(aggregates) {
    try {
      const cacheKey = `warehouse:aggregates:${aggregates.period.startDate.toISOString()}`;
      await cacheService.set(cacheKey, aggregates, 86400 * 7); // 7 days TTL

      // Also store in database
      const AnalyticsAggregate = require('../analytics/processor').getAggregateModel();
      if (AnalyticsAggregate) {
        await AnalyticsAggregate.create({
          type: 'hourly_aggregate',
          data: aggregates,
          timestamp: aggregates.generatedAt
        });
      }
    } catch (error) {
      console.error('DistributedScheduler: Error storing aggregates:', error.message);
    }
  }

  /**
   * Store reports
   * @param {Object} reports - Report data
   */
  async storeReports(reports) {
    try {
      const cacheKey = `warehouse:reports:${reports.period.startDate.toISOString()}`;
      await cacheService.set(cacheKey, reports, 86400 * 30); // 30 days TTL

      // Also store in database
      const Report = require('../analytics/reports/generator').getReportModel();
      if (Report) {
        await Report.create({
          type: 'daily_report',
          data: reports,
          generatedAt: reports.generatedAt
        });
      }
    } catch (error) {
      console.error('DistributedScheduler: Error storing reports:', error.message);
    }
  }

  /**
   * Record job history
   * @param {Object} jobRecord - Job record
   */
  recordJobHistory(jobRecord) {
    this.jobHistory.push(jobRecord);
    if (this.jobHistory.length > this.maxHistorySize) {
      this.jobHistory.shift();
    }
  }

  /**
   * Get job history
   * @param {string} jobId - Job ID (optional)
   * @returns {Array} Job history
   */
  getJobHistory(jobId = null) {
    if (jobId) {
      return this.jobHistory.filter(job => job.jobId === jobId);
    }
    return this.jobHistory;
  }

  /**
   * Get scheduled jobs
   * @returns {Array} Scheduled jobs
   */
  getScheduledJobs() {
    return Array.from(this.jobs.keys());
  }
}

// Export singleton instance
const scheduler = new DistributedScheduler();
module.exports = scheduler;


