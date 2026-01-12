/*
 * Static Assets CDN Manager
 * Manages static assets (CSS, JS, fonts, images) on CDN
 */

const cdnService = require('./cdnService');
const fs = require('fs').promises;
const path = require('path');

class StaticAssetsManager {
  constructor() {
    this.publicPath = path.join(__dirname, '../../public');
    this.assetManifest = new Map();
  }

  /**
   * Get CDN URL for static asset
   * @param {string} assetPath - Asset path relative to /public
   * @returns {string} CDN URL or local URL
   */
  getAssetUrl(assetPath) {
    // Remove leading slash if present
    const cleanPath = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
    
    // Ensure it's in public directory
    if (!cleanPath.startsWith('public/')) {
      const fullPath = `public/${cleanPath}`;
      return cdnService.getFileUrl(fullPath, `/${cleanPath}`);
    }

    return cdnService.getFileUrl(cleanPath, `/${cleanPath}`);
  }

  /**
   * Generate CDN URLs for all static assets
   * @returns {Promise<Object>} Map of asset paths to CDN URLs
   */
  async generateAssetManifest() {
    try {
      const manifest = {};
      
      // Scan public directory for assets
      const scanDirectory = async (dir, basePath = '') => {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        
        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          const relativePath = path.join(basePath, entry.name).replace(/\\/g, '/');
          
          if (entry.isDirectory()) {
            await scanDirectory(fullPath, relativePath);
          } else {
            // Generate CDN URL for file
            const publicPath = `public/${relativePath}`;
            manifest[`/${relativePath}`] = cdnService.getFileUrl(publicPath, `/${relativePath}`);
          }
        }
      };

      await scanDirectory(this.publicPath);
      this.assetManifest = new Map(Object.entries(manifest));
      
      return manifest;
    } catch (error) {
      console.error('StaticAssetsManager: Error generating manifest:', error.message);
      return {};
    }
  }

  /**
   * Get asset manifest
   * @returns {Map} Asset manifest
   */
  getManifest() {
    return this.assetManifest;
  }

  /**
   * Check if asset exists locally
   * @param {string} assetPath - Asset path
   * @returns {Promise<boolean>} True if exists
   */
  async assetExists(assetPath) {
    try {
      const cleanPath = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
      const fullPath = path.join(this.publicPath, cleanPath);
      await fs.access(fullPath);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Upload static assets to CDN (for CloudFlare/CloudFront)
   * @param {Array<string>} assetPaths - Asset paths to upload
   * @returns {Promise<Object>} Upload results
   */
  async uploadAssetsToCDN(assetPaths = []) {
    if (!cdnService.isEnabled()) {
      return { success: false, message: 'CDN not enabled' };
    }

    try {
      const results = [];
      
      for (const assetPath of assetPaths) {
        const cleanPath = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
        const fullPath = path.join(this.publicPath, cleanPath);
        
        try {
          const stats = await fs.stat(fullPath);
          if (stats.isFile()) {
            // In a real implementation, upload to CDN storage
            // For now, just mark as available
            results.push({
              path: assetPath,
              status: 'available',
              cdnUrl: cdnService.getCDNUrl(`public/${cleanPath}`)
            });
          }
        } catch (error) {
          results.push({
            path: assetPath,
            status: 'error',
            error: error.message
          });
        }
      }

      return { success: true, results };
    } catch (error) {
      console.error('StaticAssetsManager: Error uploading assets:', error.message);
      return { success: false, error: error.message };
    }
  }
}

// Export singleton instance
const staticAssetsManager = new StaticAssetsManager();
module.exports = staticAssetsManager;


