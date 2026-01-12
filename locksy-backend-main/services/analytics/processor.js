/*
 * Analytics Event Processor
 * Processes analytics events and stores them
 */

const mongoose = require('mongoose');
const cacheService = require('../cache/cacheService');

class AnalyticsProcessor {
  constructor() {
    this.batchSize = parseInt(process.env.ANALYTICS_BATCH_SIZE || '100');
    this.batchTimeout = parseInt(process.env.ANALYTICS_BATCH_TIMEOUT || '5000'); // 5 seconds
    this.eventBatch = [];
    this.batchTimer = null;
  }

  /**
   * Process analytics event
   * @param {Object} event - Event data
   */
  async processEvent(event) {
    try {
      const { type, data, timestamp } = event;

      // Add to batch
      this.eventBatch.push({
        type,
        data,
        timestamp: timestamp || new Date().toISOString(),
        processedAt: new Date()
      });

      // Process batch if it reaches batch size
      if (this.eventBatch.length >= this.batchSize) {
        await this.processBatch();
      } else {
        // Start/restart batch timer
        this.startBatchTimer();
      }

      // Store event in cache for real-time analytics
      await this.cacheEvent(event);

      return true;
    } catch (error) {
      console.error('AnalyticsProcessor: Error processing event:', error.message);
      throw error;
    }
  }

  /**
   * Process batch of events
   */
  async processBatch() {
    if (this.eventBatch.length === 0) {
      return;
    }

    try {
      const batch = [...this.eventBatch];
      this.eventBatch = [];
      this.clearBatchTimer();

      console.log(`AnalyticsProcessor: Processing batch of ${batch.length} events`);

      // Store events in database
      await this.storeEvents(batch);

      // Aggregate events
      await this.aggregateEvents(batch);

      console.log(`AnalyticsProcessor: Batch processed successfully`);
    } catch (error) {
      console.error('AnalyticsProcessor: Error processing batch:', error.message);
      // Re-add events to batch for retry
      this.eventBatch.unshift(...batch);
    }
  }

  /**
   * Store events in database
   * @param {Array<Object>} events - Events to store
   */
  async storeEvents(events) {
    try {
      // Use Analytics Event model if it exists
      let EventModel;
      try {
        EventModel = mongoose.model('AnalyticsEvent');
      } catch (error) {
        // Model doesn't exist, create schema on the fly
        const eventSchema = new mongoose.Schema({
          type: String,
          data: mongoose.Schema.Types.Mixed,
          timestamp: Date,
          processedAt: Date
        }, {
          collection: 'analytics_events',
          timestamps: true
        });

        // Index for efficient queries
        eventSchema.index({ type: 1, timestamp: -1 });
        eventSchema.index({ timestamp: -1 });

        EventModel = mongoose.model('AnalyticsEvent', eventSchema);
      }

      // Insert events
      await EventModel.insertMany(events);
    } catch (error) {
      console.error('AnalyticsProcessor: Error storing events:', error.message);
      throw error;
    }
  }

  /**
   * Aggregate events
   * @param {Array<Object>} events - Events to aggregate
   */
  async aggregateEvents(events) {
    try {
      // Group events by type
      const eventsByType = {};
      for (const event of events) {
        if (!eventsByType[event.type]) {
          eventsByType[event.type] = [];
        }
        eventsByType[event.type].push(event);
      }

      // Aggregate each event type
      for (const [type, typeEvents] of Object.entries(eventsByType)) {
        await this.aggregateEventType(type, typeEvents);
      }
    } catch (error) {
      console.error('AnalyticsProcessor: Error aggregating events:', error.message);
      // Don't throw - aggregation failure shouldn't block event storage
    }
  }

  /**
   * Aggregate events of a specific type
   * @param {string} type - Event type
   * @param {Array<Object>} events - Events of this type
   */
  async aggregateEventType(type, events) {
    try {
      // Get current hour for time-based aggregation
      const now = new Date();
      const hourKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}-${String(now.getHours()).padStart(2, '0')}`;
      
      const cacheKey = `analytics:aggregate:${type}:${hourKey}`;
      
      // Get existing aggregate
      let aggregate = await cacheService.get(cacheKey) || {
        type,
        hour: hourKey,
        count: 0,
        data: {}
      };

      // Update aggregate
      aggregate.count += events.length;
      aggregate.lastUpdated = new Date();

      // Type-specific aggregation
      switch (type) {
        case 'user_action':
          // Aggregate user actions
          for (const event of events) {
            const action = event.data?.action || 'unknown';
            aggregate.data[action] = (aggregate.data[action] || 0) + 1;
          }
          break;
        case 'message_sent':
          // Aggregate message statistics
          aggregate.data.totalMessages = (aggregate.data.totalMessages || 0) + events.length;
          break;
        default:
          // Generic aggregation
          aggregate.data.totalEvents = (aggregate.data.totalEvents || 0) + events.length;
      }

      // Cache aggregate (1 hour TTL)
      await cacheService.set(cacheKey, aggregate, 3600);

      // Store aggregate in database (for Data Warehouse)
      await this.storeAggregate(aggregate);
    } catch (error) {
      console.error(`AnalyticsProcessor: Error aggregating ${type}:`, error.message);
    }
  }

  /**
   * Store aggregate in database
   * @param {Object} aggregate - Aggregate data
   */
  async storeAggregate(aggregate) {
    try {
      // Use Analytics Aggregate model if it exists
      let AggregateModel;
      try {
        AggregateModel = mongoose.model('AnalyticsAggregate');
      } catch (error) {
        // Model doesn't exist, create schema on the fly
        const aggregateSchema = new mongoose.Schema({
          type: String,
          hour: String,
          count: Number,
          data: mongoose.Schema.Types.Mixed,
          lastUpdated: Date
        }, {
          collection: 'analytics_aggregates',
          timestamps: true
        });

        // Index for efficient queries
        aggregateSchema.index({ type: 1, hour: -1 });
        aggregateSchema.index({ hour: -1 });

        AggregateModel = mongoose.model('AnalyticsAggregate', aggregateSchema);
      }

      // Upsert aggregate
      await AggregateModel.findOneAndUpdate(
        { type: aggregate.type, hour: aggregate.hour },
        aggregate,
        { upsert: true, new: true }
      );
    } catch (error) {
      console.error('AnalyticsProcessor: Error storing aggregate:', error.message);
      // Don't throw - aggregate storage failure shouldn't block processing
    }
  }

  /**
   * Cache event for real-time analytics
   * @param {Object} event - Event data
   */
  async cacheEvent(event) {
    try {
      const cacheKey = `analytics:event:${event.type}:${Date.now()}`;
      await cacheService.set(cacheKey, event, 300); // 5 minutes TTL
    } catch (error) {
      console.warn('AnalyticsProcessor: Error caching event:', error.message);
    }
  }

  /**
   * Start batch timer
   */
  startBatchTimer() {
    this.clearBatchTimer();
    this.batchTimer = setTimeout(() => {
      this.processBatch().catch(err => {
        console.error('AnalyticsProcessor: Batch timer error:', err.message);
      });
    }, this.batchTimeout);
  }

  /**
   * Clear batch timer
   */
  clearBatchTimer() {
    if (this.batchTimer) {
      clearTimeout(this.batchTimer);
      this.batchTimer = null;
    }
  }

  /**
   * Flush remaining events
   */
  async flush() {
    if (this.eventBatch.length > 0) {
      await this.processBatch();
    }
  }
}

// Export singleton instance
const analyticsProcessor = new AnalyticsProcessor();
module.exports = analyticsProcessor;


