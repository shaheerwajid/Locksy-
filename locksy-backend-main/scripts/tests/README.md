# System Testing Suite

Comprehensive test suite for verifying all components of the Locksy Backend System Design Master Template implementation.

## Quick Start

### 1. Start All Services

Before running tests, start all services:

```powershell
.\scripts\start-all-services.ps1
```

This will:
- Start all Docker services (MongoDB, Redis, RabbitMQ, etc.)
- Start all microservices (API Gateway, Metadata Server, Block Server, etc.)
- Start all workers (Video Processing, Analytics)
- Verify all services are healthy

### 2. Run All Tests

Run the comprehensive test suite:

```powershell
.\scripts\tests\run-all.ps1
```

### 3. Run Individual Test Categories

Run specific test categories:

```powershell
# Infrastructure tests
.\scripts\tests\infrastructure\docker-services.ps1
.\scripts\tests\infrastructure\mongodb-replica.ps1

# Service tests
.\scripts\tests\services\api-gateway.ps1
.\scripts\tests\services\metadata-server.ps1
.\scripts\tests\services\block-server.ps1
```

## Test Structure

### Infrastructure Tests
- `docker-services.ps1` - Verifies all Docker Compose services
- `mongodb-replica.ps1` - Tests MongoDB replica set
- `redis.ps1` - Tests Redis connection and operations
- `rabbitmq.ps1` - Tests RabbitMQ queues
- `elasticsearch.ps1` - Tests Elasticsearch
- `zookeeper.ps1` - Tests Zookeeper
- `jaeger.ps1` - Tests Jaeger tracing

### Service Tests
- `api-gateway.ps1` - Tests API Gateway routing and middleware
- `metadata-server.ps1` - Tests Metadata Server
- `block-server.ps1` - Tests Block Server
- `shard-manager.ps1` - Tests Shard Manager
- `warehouse.ps1` - Tests Data Warehouse

### Worker Tests
- `video-workers.ps1` - Tests video processing workers
- `analytics-workers.ps1` - Tests analytics workers

### Queue Tests
- `notification-queue.ps1` - Tests notification queue
- `video-queue.ps1` - Tests video processing queue
- `feed-queue.ps1` - Tests feed generation queue
- `analytics-queue.ps1` - Tests analytics queue

### Flow Tests
- `primary-request.ps1` - Tests primary request flow
- `control-path.ps1` - Tests control path (metadata)
- `data-path.ps1` - Tests data path (files)
- `video-processing.ps1` - Tests video processing pipeline
- `search.ps1` - Tests search flow
- `notification.ps1` - Tests notification flow
- `feed-generation.ps1` - Tests feed generation
- `analytics.ps1` - Tests data warehouse flow
- `cdn.ps1` - Tests CDN flow

### Integration Tests
- `service-discovery.ps1` - Tests Zookeeper service discovery
- `leader-election.ps1` - Tests leader election
- `distributed-lock.ps1` - Tests distributed locking
- `tracing.ps1` - Tests distributed tracing

## Test Utilities

The `utils/` directory contains helper functions used by all tests:
- `test-helpers.ps1` - Common test functions (assertions, HTTP requests, etc.)
- `docker-helper.ps1` - Docker service management
- `report-generator.ps1` - Test report generation

## Prerequisites

1. **Docker Desktop** - Must be running
2. **Node.js** - Installed and in PATH
3. **PowerShell** - Version 5.1 or later
4. **All services started** - Run `start-all-services.ps1` first

## Service URLs

After starting services, they will be available at:

- API Gateway: http://localhost:3001, 3002, 3003
- Metadata Server: http://localhost:3004
- Block Server: http://localhost:3005
- Data Warehouse: http://localhost:3009
- Jaeger UI: http://localhost:16686
- Elasticsearch: http://localhost:9200
- MinIO Console: http://localhost:9001

## Troubleshooting

### Services not starting
- Check Docker Desktop is running
- Check ports are not already in use
- Review logs in `logs/` directory

### Tests failing
- Ensure all services are started and healthy
- Check service health endpoints manually
- Review test output for specific error messages

### Docker services not healthy
- Run `docker-compose ps` to check container status
- Check Docker logs: `docker-compose logs [service-name]`
- Restart Docker services: `docker-compose restart`

## Test Results

Test results are displayed in real-time with color-coded output:
- **Green** - Test passed
- **Red** - Test failed
- **Yellow** - Test warning

A summary is displayed at the end of each test script showing:
- Number of tests passed
- Number of tests failed
- Number of warnings
- Total duration

## Next Steps

After running tests, you can:
1. Review test output for any failures
2. Check service logs in `logs/` directory
3. Verify services are accessible via their health endpoints
4. Run individual test scripts to debug specific components


