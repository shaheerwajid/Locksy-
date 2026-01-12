/*
 * Feed Routes
 * API endpoints for feed generation and retrieval
 */

const { Router } = require('express');
const { validarJWT } = require('../middlewares/validar-jwt');
const feedGenerator = require('../services/feed/generator');
const feedAggregator = require('../services/feed/aggregator');

const router = Router();

// Helper function to transform feed to items array
function transformFeedToItems(feed) {
  const items = [];
  
  // Add messages as feed items
  if (feed.messages && Array.isArray(feed.messages)) {
    feed.messages.forEach(msg => {
      items.push({
        type: 'message',
        data: msg,
        timestamp: msg.createdAt || msg.fecha || new Date().toISOString()
      });
    });
  }
  
  // Add contacts as feed items
  if (feed.contacts && Array.isArray(feed.contacts)) {
    feed.contacts.forEach(contact => {
      items.push({
        type: 'contact',
        data: contact,
        timestamp: contact.fecha || contact.createdAt || new Date().toISOString()
      });
    });
  }
  
  // Add groups as feed items
  if (feed.groups && Array.isArray(feed.groups)) {
    feed.groups.forEach(group => {
      items.push({
        type: 'group',
        data: group,
        timestamp: group.fecha || group.createdAt || new Date().toISOString()
      });
    });
  }
  
  // Sort by timestamp (newest first)
  return items.sort((a, b) => {
    const timeA = new Date(a.timestamp || 0).getTime();
    const timeB = new Date(b.timestamp || 0).getTime();
    return timeB - timeA;
  });
}

// Get user feed
router.get('/user', validarJWT, async (req, res) => {
  try {
    const userId = req.uid;
    const result = await feedGenerator.getUserFeed(userId);
    
    // Transform feed into items array format
    if (result.feed) {
      const items = transformFeedToItems(result.feed);
      res.json({
        ok: true,
        items: items
      });
    } else {
      // Feed generation in progress
      res.json(result);
    }
  } catch (error) {
    console.error('Error getting user feed:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener feed de usuario'
    });
  }
});

// Generate user feed
router.post('/user/generate', validarJWT, async (req, res) => {
  try {
    const userId = req.uid;
    const options = req.body.options || {};
    const result = await feedGenerator.generateUserFeed(userId, options);
    res.json(result);
  } catch (error) {
    console.error('Error generating user feed:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar feed de usuario'
    });
  }
});

// Get group feed
router.get('/group/:groupId', validarJWT, async (req, res) => {
  try {
    const { groupId } = req.params;
    const result = await feedGenerator.getGroupFeed(groupId);
    
    // Transform feed into items array format
    if (result.feed) {
      const items = transformFeedToItems(result.feed);
      res.json({
        ok: true,
        items: items
      });
    } else {
      // Feed generation in progress
      res.json(result);
    }
  } catch (error) {
    console.error('Error getting group feed:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener feed de grupo'
    });
  }
});

// Generate group feed
router.post('/group/:groupId/generate', validarJWT, async (req, res) => {
  try {
    const { groupId } = req.params;
    const options = req.body.options || {};
    const result = await feedGenerator.generateGroupFeed(groupId, options);
    res.json(result);
  } catch (error) {
    console.error('Error generating group feed:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar feed de grupo'
    });
  }
});

// Generate activity feed
router.post('/activity/generate', validarJWT, async (req, res) => {
  try {
    const userId = req.uid;
    const options = req.body.options || {};
    const result = await feedGenerator.generateActivityFeed(userId, options);
    res.json(result);
  } catch (error) {
    console.error('Error generating activity feed:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar feed de actividad'
    });
  }
});

module.exports = router;


