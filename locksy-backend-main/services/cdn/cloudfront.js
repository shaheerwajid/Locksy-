/*
 * AWS CloudFront CDN Client
 * CloudFront-specific CDN operations
 */

const AWS = require('aws-sdk');

class CloudFrontCDN {
  constructor() {
    this.distributionId = process.env.CLOUDFRONT_DISTRIBUTION_ID;
    
    // Configure AWS SDK
    AWS.config.update({
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      region: process.env.AWS_REGION || 'us-east-1'
    });

    this.cloudfront = new AWS.CloudFront();
  }

  /**
   * Create invalidation for specific paths
   * @param {Array<string>} paths - Paths to invalidate
   * @returns {Promise<string>} Invalidation ID
   */
  async createInvalidation(paths) {
    try {
      if (!this.distributionId) {
        console.warn('CloudFrontCDN: Distribution ID not configured');
        return null;
      }

      const params = {
        DistributionId: this.distributionId,
        InvalidationBatch: {
          CallerReference: `invalidation-${Date.now()}-${Math.random().toString(36).substring(7)}`,
          Paths: {
            Quantity: paths.length,
            Items: paths
          }
        }
      };

      const result = await this.cloudfront.createInvalidation(params).promise();
      return result.Invalidation.Id;
    } catch (error) {
      console.error('CloudFrontCDN: Invalidation error:', error.message);
      throw error;
    }
  }

  /**
   * Get invalidation status
   * @param {string} invalidationId - Invalidation ID
   * @returns {Promise<Object>} Invalidation status
   */
  async getInvalidationStatus(invalidationId) {
    try {
      if (!this.distributionId) {
        return null;
      }

      const params = {
        DistributionId: this.distributionId,
        Id: invalidationId
      };

      const result = await this.cloudfront.getInvalidation(params).promise();
      return {
        id: result.Invalidation.Id,
        status: result.Invalidation.Status,
        createTime: result.Invalidation.CreateTime
      };
    } catch (error) {
      console.error('CloudFrontCDN: Get invalidation status error:', error.message);
      throw error;
    }
  }
}

module.exports = CloudFrontCDN;


