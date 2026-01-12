/*
 * Search Routes
 * API endpoints for search functionality
 */

const express = require('express');
const router = express.Router();
const searchService = require('../services/search/searchService');
const { validarJWT } = require('../middlewares/validar-jwt');

/**
 * Search all
 */
router.get('/search', validarJWT, async (req, res) => {
  try {
    const { q, limit = 10 } = req.query;

    if (!q) {
      return res.status(400).json({
        ok: false,
        message: 'Query parameter "q" is required',
      });
    }

    const results = await searchService.aggregateSearch(q, parseInt(limit));

    res.json({
      ok: true,
      results,
    });
  } catch (error) {
    console.error('Search: Error', error);
    res.status(500).json({
      ok: false,
      message: 'Search failed',
    });
  }
});

/**
 * Search users
 */
router.get('/search/users', validarJWT, async (req, res) => {
  try {
    const { q, limit = 10 } = req.query;

    if (!q) {
      return res.status(400).json({
        ok: false,
        message: 'Query parameter "q" is required',
      });
    }

    const users = await searchService.searchUsers(q, parseInt(limit));

    res.json({
      ok: true,
      users,
    });
  } catch (error) {
    console.error('Search: Error', error);
    res.status(500).json({
      ok: false,
      message: 'User search failed',
    });
  }
});

/**
 * Search messages
 */
router.get('/search/messages', validarJWT, async (req, res) => {
  try {
    const { q, limit = 20, userId } = req.query;

    if (!q) {
      return res.status(400).json({
        ok: false,
        message: 'Query parameter "q" is required',
      });
    }

    const messages = await searchService.searchMessages(q, userId, parseInt(limit));

    res.json({
      ok: true,
      messages,
    });
  } catch (error) {
    console.error('Search: Error', error);
    res.status(500).json({
      ok: false,
      message: 'Message search failed',
    });
  }
});

/**
 * Search groups
 */
router.get('/search/groups', validarJWT, async (req, res) => {
  try {
    const { q, limit = 10 } = req.query;

    if (!q) {
      return res.status(400).json({
        ok: false,
        message: 'Query parameter "q" is required',
      });
    }

    const groups = await searchService.searchGroups(q, parseInt(limit));

    res.json({
      ok: true,
      groups,
    });
  } catch (error) {
    console.error('Search: Error', error);
    res.status(500).json({
      ok: false,
      message: 'Group search failed',
    });
  }
});

module.exports = router;

