# PowerShell script to initialize MongoDB Replica Set
# Run this after all MongoDB containers are started

Write-Host "Waiting for MongoDB instances to be ready..."
Start-Sleep -Seconds 10

Write-Host "Initializing replica set..."

# Initialize replica set
docker exec locksy-mongodb-primary mongosh --eval @"
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: 'mongodb-primary:27017', priority: 2 },
    { _id: 1, host: 'mongodb-secondary1:27017', priority: 1 },
    { _id: 2, host: 'mongodb-secondary2:27017', priority: 1 }
  ]
})
"@

Write-Host "Replica set initialization complete"
Write-Host "Checking status..."
docker exec locksy-mongodb-primary mongosh --eval "rs.status()"


