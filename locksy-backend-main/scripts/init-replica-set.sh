#!/bin/bash
# Initialize MongoDB Replica Set
# This script initializes the replica set after all MongoDB containers are running

echo "Waiting for MongoDB instances to be ready..."
sleep 10

echo "Initializing replica set..."

mongosh --host mongodb-primary:27017 <<EOF
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: 'mongodb-primary:27017', priority: 2 },
    { _id: 1, host: 'mongodb-secondary1:27017', priority: 1 },
    { _id: 2, host: 'mongodb-secondary2:27017', priority: 1 }
  ]
})
EOF

echo "Replica set initialization complete"
echo "Checking status..."
mongosh --host mongodb-primary:27017 --eval "rs.status()"


