/*
 * CDN Service
 * CDN abstraction layer for different CDN providers
 */

const config = require('../../config');
const cacheService = require('../cache/cacheService');

class CDNService {
  constructor() {
    this.enabled = config.cdn.enabled;
    this.baseUrl = config.cdn.baseUrl;
    this.cdnProvider = process.env.CDN_PROVIDER || 'cloudflare'; // cloudflare, cloudfront, custom
  }

  /**
   * Generate CDN URL
   * @param {string} filePath - File path
   * @returns {string} CDN URL
   */
  getCDNUrl(filePath) {
    if (!this.enabled || !this.baseUrl) {
      return null; // CDN not enabled
    }

    // Remove leading slash if present
    const cleanPath = filePath.startsWith('/') ? filePath.substring(1) : filePath;

    // Generate CDN URL
    const cdnUrl = `${this.baseUrl}/${cleanPath}`;
    return cdnUrl;
  }

  /**
   * Get file URL (CDN or fallback)
   * @param {string} filePath - File path
   * @param {string} fallbackUrl - Fallback URL if CDN unavailable
   * @returns {string} File URL
   */
  getFileUrl(filePath, fallbackUrl = null) {
    if (this.enabled && this.baseUrl) {
      const cdnUrl = this.getCDNUrl(filePath);
      if (cdnUrl) {
        return cdnUrl;
      }
    }

    // Fallback to provided URL or original path
    return fallbackUrl || filePath;
  }

  /**
   * Check if CDN is enabled
   * @returns {boolean} True if enabled
   */
  isEnabled() {
    return this.enabled && !!this.baseUrl;
  }

  /**
   * Purge CDN cache for file
   * @param {string} filePath - File path
   * @returns {Promise<boolean>} True if purged
   */
  async purgeCache(filePath) {
    if (!this.isEnabled()) {
      return false;
    }

    try {
      // Implementation depends on CDN provider
      switch (this.cdnProvider) {
        case 'cloudflare':
          return await this.purgeCloudflareCache(filePath);
        case 'cloudfront':
          return await this.purgeCloudFrontCache(filePath);
        default:
          console.warn(`CDNService: Purge not implemented for provider ${this.cdnProvider}`);
          return false;
      }
    } catch (error) {
      console.error('CDNService: Error purging cache:', error.message);
      return false;
    }
  }

  /**
   * Purge CloudFlare cache
   * @param {string} filePath - File path
   * @returns {Promise<boolean>} True if purged
   */
  async purgeCloudflareCache(filePath) {
    try {
      const cloudflareZoneId = process.env.CLOUDFLARE_ZONE_ID;
      const cloudflareApiToken = process.env.CLOUDFLARE_API_TOKEN;

      if (!cloudflareZoneId || !cloudflareApiToken) {
        console.warn('CDNService: CloudFlare credentials not configured');
        return false;
      }

      const url = this.getCDNUrl(filePath);
      if (!url) {
        return false;
      }

      // CloudFlare API call to purge cache
      const fetch = require('node-fetch');
      const response = await fetch(`https://api.cloudflare.com/client/v4/zones/${cloudflareZoneId}/purge_cache`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${cloudflareApiToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          files: [url]
        })
      });

      return response.ok;
    } catch (error) {
      console.error('CDNService: CloudFlare purge error:', error.message);
      return false;
    }
  }

  /**
   * Purge CloudFront cache
   * @param {string} filePath - File path
   * @returns {Promise<boolean>} True if purged
   */
  async purgeCloudFrontCache(filePath) {
    try {
      const AWS = require('aws-sdk');
      const cloudfrontDistributionId = process.env.CLOUDFRONT_DISTRIBUTION_ID;

      if (!cloudfrontDistributionId) {
        console.warn('CDNService: CloudFront distribution ID not configured');
        return false;
      }

      const url = this.getCDNUrl(filePath);
      if (!url) {
        return false;
      }

      const cloudfront = new AWS.CloudFront();
      const params = {
        DistributionId: cloudfrontDistributionId,
        InvalidationBatch: {
          CallerReference: `invalidation-${Date.now()}-${Math.random()}`,
          Paths: {
            Quantity: 1,
            Items: [url]
          }
        }
      };

      await cloudfront.createInvalidation(params).promise();
      return true;
    } catch (error) {
      console.error('CDNService: CloudFront purge error:', error.message);
      return false;
    }
  }
}

// Export singleton instance
const cdnService = new CDNService();
module.exports = cdnService;


