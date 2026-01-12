const mongoose = require("mongoose");
const { configureReadPreference } = require("./read-preference");

const dbConnection = async () => {
  console.log("=============== DB mongoose ===========");
  try {
    // Check if already connected
    if (mongoose.connection.readyState === 1) {
      console.log("DB already connected, reusing connection");
      return;
    }

    let connectionString = process.env.DB_CNN || 'mongodb://localhost:27017/cryptochat';
    const replicaSetName = process.env.MONGODB_REPLICA_SET_NAME;
    const readPreference = process.env.MONGODB_READ_PREFERENCE || 'secondaryPreferred';
    
    // Parse connection string to extract base URL and query parameters
    const urlParts = connectionString.split('?');
    const baseUrl = urlParts[0];
    const queryParams = urlParts[1] || '';
    
    // Parse query parameters
    const params = new URLSearchParams(queryParams);
    
    // Remove readPreference from connection string if not a replica set
    // readPreference is only valid for replica sets, not single instances
    if (!replicaSetName) {
      // Remove readPreference from params
      params.delete('readPreference');
      
      // Rebuild connection string
      const remainingParams = params.toString();
      connectionString = remainingParams ? `${baseUrl}?${remainingParams}` : baseUrl;
    } else {
      // Add readPreference if replica set is configured and not already present
      if (!params.has('readPreference')) {
        params.set('readPreference', readPreference);
        connectionString = `${baseUrl}?${params.toString()}`;
      }
    }
    
    console.log('Connecting to MongoDB:', baseUrl.replace(/\/\/.*@/, '//***:***@')); // Hide credentials in logs
    
    // Build connection options
    const connectionOptions = {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 30000, // 30 seconds for server selection
      socketTimeoutMS: 45000, // 45 seconds for socket operations
      connectTimeoutMS: 30000, // 30 seconds for initial connection
      // Write concern for replica set
      ...(replicaSetName && {
        writeConcern: {
          w: 'majority',
          j: true,
          wtimeout: 10000
        }
      })
    };

    await mongoose.connect(connectionString, connectionOptions);
    
    // Configure read preferences if replica set is configured
    if (replicaSetName) {
      const readPref = process.env.MONGODB_READ_PREFERENCE || 'secondaryPreferred';
      configureReadPreference(readPref);
      console.log(`DB Online - Replica Set: ${replicaSetName}, Read Preference: ${readPref}`);
    } else {
      console.log("DB Online - Single instance");
    }

    // Connection event handlers
    mongoose.connection.on('error', (err) => {
      console.error('MongoDB connection error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      console.warn('MongoDB disconnected');
    });

    mongoose.connection.on('reconnected', () => {
      console.log('MongoDB reconnected');
    });

    // Log replica set status if connected
    if (replicaSetName) {
      const admin = mongoose.connection.db.admin();
      admin.command({ replSetGetStatus: 1 }).then((status) => {
        console.log('Replica Set Status:', {
          setName: status.set,
          members: status.members.length,
          primary: status.members.find(m => m.stateStr === 'PRIMARY')?.name
        });
      }).catch((err) => {
        console.warn('Could not get replica set status:', err.message);
      });
    }
  } catch (error) {
    console.error('Database connection error:', error);
    console.warn('Application will continue, but database operations will fail');
    // Don't throw - allow application to start for debugging
    // In production, health checks will catch this and mark as unhealthy
  }
};

module.exports = {
  dbConnection,
};
