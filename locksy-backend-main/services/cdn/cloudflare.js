/*
 * CloudFlare CDN Client
 * CloudFlare-specific CDN operations
 */

const fetch = require('node-fetch');

class CloudFlareCDN {
  constructor() {
    this.zoneId = process.env.CLOUDFLARE_ZONE_ID;
    this.apiToken = process.env.CLOUDFLARE_API_TOKEN;
    this.baseUrl = process.env.CDN_BASE_URL;
  }

  /**
   * Purge cache for specific files
   * @param {Array<string>} urls - URLs to purge
   * @returns {Promise<boolean>} True if successful
   */
  async purgeFiles(urls) {
    try {
      if (!this.zoneId || !this.apiToken) {
        console.warn('CloudFlareCDN: Credentials not configured');
        return false;
      }

      const response = await fetch(`https://api.cloudflare.com/client/v4/zones/${this.zoneId}/purge_cache`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          files: urls
        })
      });

      const result = await response.json();
      return result.success === true;
    } catch (error) {
      console.error('CloudFlareCDN: Purge error:', error.message);
      return false;
    }
  }

  /**
   * Purge entire cache
   * @returns {Promise<boolean>} True if successful
   */
  async purgeAll() {
    try {
      if (!this.zoneId || !this.apiToken) {
        console.warn('CloudFlareCDN: Credentials not configured');
        return false;
      }

      const response = await fetch(`https://api.cloudflare.com/client/v4/zones/${this.zoneId}/purge_cache`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          purge_everything: true
        })
      });

      const result = await response.json();
      return result.success === true;
    } catch (error) {
      console.error('CloudFlareCDN: Purge all error:', error.message);
      return false;
    }
  }
}

module.exports = CloudFlareCDN;


