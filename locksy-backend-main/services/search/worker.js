/*
 * Search Indexing Worker Service
 * Starts the search indexing consumer to process queued indexing tasks
 */

const searchIndexingConsumer = require('./consumer');

let isStarted = false;

/**
 * Start search indexing worker
 */
function startSearchIndexingWorker() {
  if (isStarted) {
    console.log('Search Indexing Worker: Already running');
    return;
  }

  try {
    searchIndexingConsumer.start();
    isStarted = true;
    console.log('Search Indexing Worker: Started');
  } catch (error) {
    console.error('Search Indexing Worker: Failed to start', error.message);
  }
}

/**
 * Stop search indexing worker
 */
async function stopSearchIndexingWorker() {
  if (!isStarted) {
    return;
  }

  try {
    await searchIndexingConsumer.stop();
    isStarted = false;
    console.log('Search Indexing Worker: Stopped');
  } catch (error) {
    console.error('Search Indexing Worker: Error stopping', error.message);
  }
}

module.exports = {
  startSearchIndexingWorker,
  stopSearchIndexingWorker
};






