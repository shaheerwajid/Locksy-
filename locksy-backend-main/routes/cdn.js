/*
 * CDN Routes
 * API endpoints for CDN operations
 */

const { Router } = require('express');
const { validarJWT } = require('../middlewares/validar-jwt');
const cdnService = require('../services/cdn/cdnService');
const staticAssetsManager = require('../services/cdn/static-assets');

const router = Router();

// Get CDN URL for a file
router.get('/url/:filePath(*)', validarJWT, (req, res) => {
  try {
    const filePath = req.params.filePath;
    
    if (!cdnService.isEnabled()) {
      return res.status(404).json({
        ok: false,
        msg: 'CDN not enabled'
      });
    }

    const cdnUrl = cdnService.getCDNUrl(filePath);
    if (!cdnUrl) {
      return res.status(404).json({
        ok: false,
        msg: 'Could not generate CDN URL'
      });
    }

    res.json({
      ok: true,
      url: cdnUrl,
      filePath
    });
  } catch (error) {
    console.error('Error generating CDN URL:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar URL de CDN'
    });
  }
});

// Get static asset URL
router.get('/asset/:assetPath(*)', (req, res) => {
  try {
    const assetPath = req.params.assetPath;
    const assetUrl = staticAssetsManager.getAssetUrl(assetPath);
    
    res.json({
      ok: true,
      url: assetUrl,
      assetPath
    });
  } catch (error) {
    console.error('Error getting asset URL:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener URL de asset'
    });
  }
});

// Get asset manifest
router.get('/manifest', validarJWT, async (req, res) => {
  try {
    const manifest = staticAssetsManager.getManifest();
    const manifestObj = Object.fromEntries(manifest);
    
    res.json({
      ok: true,
      manifest: manifestObj,
      count: manifest.size
    });
  } catch (error) {
    console.error('Error getting manifest:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener manifest'
    });
  }
});

// Regenerate asset manifest
router.post('/manifest/regenerate', validarJWT, async (req, res) => {
  try {
    const manifest = await staticAssetsManager.generateAssetManifest();
    
    res.json({
      ok: true,
      manifest,
      count: Object.keys(manifest).length
    });
  } catch (error) {
    console.error('Error regenerating manifest:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al regenerar manifest'
    });
  }
});

// Purge CDN cache for a file
router.post('/purge/:filePath(*)', validarJWT, async (req, res) => {
  try {
    const filePath = req.params.filePath;
    
    if (!cdnService.isEnabled()) {
      return res.status(404).json({
        ok: false,
        msg: 'CDN not enabled'
      });
    }

    const purged = await cdnService.purgeCache(filePath);
    
    res.json({
      ok: purged,
      msg: purged ? 'Cache purged successfully' : 'Failed to purge cache',
      filePath
    });
  } catch (error) {
    console.error('Error purging cache:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al purgar cache'
    });
  }
});

// Upload static assets to CDN
router.post('/upload-assets', validarJWT, async (req, res) => {
  try {
    const { assetPaths } = req.body;
    
    if (!Array.isArray(assetPaths)) {
      return res.status(400).json({
        ok: false,
        msg: 'assetPaths must be an array'
      });
    }

    const result = await staticAssetsManager.uploadAssetsToCDN(assetPaths);
    
    res.json({
      ok: result.success,
      result
    });
  } catch (error) {
    console.error('Error uploading assets:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al subir assets'
    });
  }
});

module.exports = router;


