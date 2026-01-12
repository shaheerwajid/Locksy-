/*
 * Proxy Routes
 * Routes other requests to appropriate services
 */

const express = require('express');
const router = express.Router();

// Health check routes (bypasses gateway processing)
router.get('/health', (req, res) => {
    res.json({
        ok: true,
        status: 'healthy',
        timestamp: new Date().toISOString()
    });
});

router.get('/health/ready', async (req, res) => {
    try {
        const mongoose = require('mongoose');
        const dbStatus = mongoose.connection.readyState === 1;
        
        if (dbStatus) {
            res.json({
                ok: true,
                status: 'ready',
                checks: {
                    database: 'connected'
                }
            });
        } else {
            res.status(503).json({
                ok: false,
                status: 'not ready',
                checks: {
                    database: 'disconnected'
                }
            });
        }
    } catch (error) {
        res.status(503).json({
            ok: false,
            status: 'not ready',
            error: error.message
        });
    }
});

router.get('/health/live', (req, res) => {
    res.json({
        ok: true,
        status: 'alive'
    });
});

// Search routes
router.use('/search', require('../../routes/search'));

// Test/debug routes
router.use('/pruebas', require('../../routes/pruebas'));

// Default route - return 404 for unmatched routes
router.use('*', (req, res) => {
    res.status(404).json({
        ok: false,
        msg: 'Route not found'
    });
});

// CDN routes
router.use('/cdn', require('../../routes/cdn'));

module.exports = router;

