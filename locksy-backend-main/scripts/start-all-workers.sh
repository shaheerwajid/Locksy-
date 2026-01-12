#!/bin/bash
#
# Start all worker processes for the Locksy Backend
#
# This script starts all worker processes:
# - Video Processing Workers
# - Analytics Workers
# - Search Indexing Worker (started automatically by Metadata Server)
#
# Make sure all required services are running:
# - MongoDB
# - Redis
# - RabbitMQ
# - Elasticsearch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

echo "Starting all Locksy Backend workers..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH"
    exit 1
fi

# Start Video Workers
echo ""
echo "Starting Video Processing Workers..."
node scripts/start-video-workers.js &
VIDEO_PID=$!
sleep 2

# Start Analytics Workers
echo "Starting Analytics Workers..."
node scripts/start-analytics-workers.js &
ANALYTICS_PID=$!
sleep 2

echo ""
echo "All workers started!"
echo "Video Workers PID: $VIDEO_PID"
echo "Analytics Workers PID: $ANALYTICS_PID"
echo ""
echo "Note: Search Indexing Worker is started automatically by Metadata Server"
echo ""
echo "To stop workers, use: kill $VIDEO_PID $ANALYTICS_PID"






