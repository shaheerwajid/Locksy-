/*
 * Shard Manager Routes
 * API endpoints for shard management
 */

const express = require('express');
const router = express.Router();
const shardRouter = require('./shardRouter');
const shardMonitor = require('./shardMonitor');

// Get shard information
router.get('/shards', async (req, res) => {
  try {
    const metadata = await shardRouter.getAllShardMetadata();
    res.json({
      ok: true,
      shards: metadata,
      shardCount: shardRouter.getShardCount()
    });
  } catch (error) {
    console.error('Error getting shards:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener información de shards'
    });
  }
});

// Get shard health
router.get('/shards/health', async (req, res) => {
  try {
    const health = await shardMonitor.getHealthStatus();
    res.json({
      ok: true,
      health
    });
  } catch (error) {
    console.error('Error getting shard health:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener estado de salud de shards'
    });
  }
});

// Get shard performance metrics
router.get('/shards/metrics', async (req, res) => {
  try {
    const shardIndex = req.query.shardIndex ? parseInt(req.query.shardIndex) : null;
    const metrics = await shardMonitor.getPerformanceMetrics(shardIndex);
    res.json({
      ok: true,
      metrics
    });
  } catch (error) {
    console.error('Error getting shard metrics:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener métricas de shards'
    });
  }
});

// Route query to shards
router.post('/shards/route', async (req, res) => {
  try {
    const { collectionName, query } = req.body;
    
    if (!collectionName || !query) {
      return res.status(400).json({
        ok: false,
        msg: 'collectionName and query are required'
      });
    }

    const shards = shardRouter.getShardsForQuery(collectionName, query);
    res.json({
      ok: true,
      shards,
      shardCount: shards.length
    });
  } catch (error) {
    console.error('Error routing query:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al enrutar consulta'
    });
  }
});

module.exports = router;


