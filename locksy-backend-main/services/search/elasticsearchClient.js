/*
 * Elasticsearch Client
 * Manages Elasticsearch connection and basic operations
 */

const elasticsearch = require('elasticsearch');
const config = require('../../config');

let client = null;

/**
 * Initialize Elasticsearch client
 */
function initializeElasticsearch() {
  if (client) {
    return client;
  }

  try {
    const esConfig = config.elasticsearch;

    client = new elasticsearch.Client({
      host: `${esConfig.host}:${esConfig.port}`,
      log: 'error',
    });

    // Test connection
    client.ping({
      requestTimeout: 3000,
    }, (error) => {
      if (error) {
        console.warn('Elasticsearch: Connection failed', error.message);
      } else {
        console.log('Elasticsearch: Connected');
      }
    });

    return client;
  } catch (error) {
    console.error('Elasticsearch: Initialization failed', error.message);
    return null;
  }
}

/**
 * Get Elasticsearch client
 */
function getClient() {
  if (!client) {
    return initializeElasticsearch();
  }
  return client;
}

/**
 * Check if Elasticsearch is available
 */
async function isAvailable() {
  try {
    const esClient = getClient();
    if (!esClient) {
      return false;
    }

    await esClient.ping();
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  initializeElasticsearch,
  getClient,
  isAvailable,
};

