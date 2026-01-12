/*
 * Data Warehouse Routes
 * API endpoints for warehouse operations
 */

const express = require('express');
const router = express.Router();
const dataExtractor = require('./extractor');
const dataLoader = require('./loader');
const dataProcessor = require('./processor');
const scheduler = require('./scheduler');

// Extract data
router.post('/extract', async (req, res) => {
  try {
    const { type, options } = req.body;
    
    let result;
    switch (type) {
      case 'users':
        result = await dataExtractor.extractUsers(options);
        break;
      case 'messages':
        result = await dataExtractor.extractMessages(options);
        break;
      case 'groups':
        result = await dataExtractor.extractGroups(options);
        break;
      case 'contacts':
        result = await dataExtractor.extractContacts(options);
        break;
      case 'all':
        result = await dataExtractor.extractAll(options);
        break;
      case 'incremental':
        result = await dataExtractor.extractIncremental(options?.since);
        break;
      default:
        return res.status(400).json({
          ok: false,
          msg: 'Invalid extraction type'
        });
    }

    res.json({
      ok: true,
      type,
      data: result,
      count: Array.isArray(result) ? result.length : result.summary
    });
  } catch (error) {
    console.error('Error extracting data:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al extraer datos'
    });
  }
});

// Load data
router.post('/load', async (req, res) => {
  try {
    const { type, data } = req.body;
    
    if (!data) {
      return res.status(400).json({
        ok: false,
        msg: 'Data is required'
      });
    }

    let result;
    switch (type) {
      case 'users':
        result = await dataLoader.loadUsers(data);
        break;
      case 'messages':
        result = await dataLoader.loadMessages(data);
        break;
      case 'groups':
        result = await dataLoader.loadGroups(data);
        break;
      case 'contacts':
        result = await dataLoader.loadContacts(data);
        break;
      case 'all':
        result = await dataLoader.loadAll(data);
        break;
      default:
        return res.status(400).json({
          ok: false,
          msg: 'Invalid load type'
        });
    }

    res.json({
      ok: true,
      type,
      result
    });
  } catch (error) {
    console.error('Error loading data:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al cargar datos'
    });
  }
});

// Process data
router.post('/process', async (req, res) => {
  try {
    const { collection, pipeline } = req.body;
    
    if (!collection || !pipeline) {
      return res.status(400).json({
        ok: false,
        msg: 'Collection and pipeline are required'
      });
    }

    const result = await dataProcessor.process(collection, pipeline);

    res.json({
      ok: true,
      collection,
      result,
      count: result.length
    });
  } catch (error) {
    console.error('Error processing data:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al procesar datos'
    });
  }
});

// Get job history
router.get('/jobs/history', (req, res) => {
  try {
    const { jobId } = req.query;
    const history = scheduler.getJobHistory(jobId);
    res.json({
      ok: true,
      history
    });
  } catch (error) {
    console.error('Error getting job history:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener historial de trabajos'
    });
  }
});

// Get scheduled jobs
router.get('/jobs', (req, res) => {
  try {
    const jobs = scheduler.getScheduledJobs();
    res.json({
      ok: true,
      jobs
    });
  } catch (error) {
    console.error('Error getting scheduled jobs:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener trabajos programados'
    });
  }
});

// Run ETL job manually
router.post('/jobs/etl/run', async (req, res) => {
  try {
    const result = await scheduler.runETLJob();
    res.json({
      ok: true,
      result
    });
  } catch (error) {
    console.error('Error running ETL job:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al ejecutar trabajo ETL'
    });
  }
});

// Run aggregation job manually
router.post('/jobs/aggregation/run', async (req, res) => {
  try {
    const result = await scheduler.runAggregationJob();
    res.json({
      ok: true,
      result
    });
  } catch (error) {
    console.error('Error running aggregation job:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al ejecutar trabajo de agregación'
    });
  }
});

// Run report job manually
router.post('/jobs/report/run', async (req, res) => {
  try {
    const result = await scheduler.runReportJob();
    res.json({
      ok: true,
      result
    });
  } catch (error) {
    console.error('Error running report job:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al ejecutar trabajo de reporte'
    });
  }
});

module.exports = router;


