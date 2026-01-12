/*
 * Migration Script: Remove Private Keys from Database
 * 
 * This script removes all privateKey fields from user documents.
 * Private keys should NEVER be stored on the server.
 * 
 * Usage:
 *   node scripts/migrations/remove_private_keys.js
 * 
 * Or via Docker:
 *   docker-compose exec app node scripts/migrations/remove_private_keys.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const Usuario = require('../../models/usuario');

async function migrate() {
  try {
    console.log('=== Migration: Remove Private Keys ===');
    console.log('Connecting to database...');

    // Connect to MongoDB
    await mongoose.connect(process.env.DB_CNN, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log('Database connected');

    // Optional: Backup private keys before removal (commented out for security)
    // Uncomment only if you need to backup for migration purposes
    /*
    console.log('Creating backup of private keys...');
    const usersWithPrivateKeys = await Usuario.find({ privateKey: { $exists: true, $ne: null } })
      .select('_id email privateKey')
      .lean();
    
    const backupPath = path.join(__dirname, `../../backups/private_keys_backup_${Date.now()}.json`);
    fs.mkdirSync(path.dirname(backupPath), { recursive: true });
    fs.writeFileSync(backupPath, JSON.stringify(usersWithPrivateKeys, null, 2));
    console.log(`Backup saved to: ${backupPath}`);
    console.log(`Backed up ${usersWithPrivateKeys.length} private keys`);
    */

    // Find all users with privateKey field
    const usersWithPrivateKeys = await Usuario.find({ 
      privateKey: { $exists: true, $ne: null } 
    }).select('_id email nombre');

    console.log(`Found ${usersWithPrivateKeys.length} users with privateKey field`);

    if (usersWithPrivateKeys.length === 0) {
      console.log('No private keys to remove. Migration complete.');
      await mongoose.connection.close();
      return;
    }

    // Remove privateKey field from all users
    const result = await Usuario.updateMany(
      { privateKey: { $exists: true } },
      { $unset: { privateKey: 1 } }
    );

    console.log(`Removed privateKey from ${result.modifiedCount} user(s)`);
    console.log('Migration completed successfully');

    // Verify removal
    const remaining = await Usuario.countDocuments({ 
      privateKey: { $exists: true, $ne: null } 
    });
    
    if (remaining === 0) {
      console.log('✓ Verification: No private keys remaining in database');
    } else {
      console.warn(`⚠ Warning: ${remaining} private key(s) still exist in database`);
    }

    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
migrate();

