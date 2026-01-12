#!/usr/bin/env node
/*
 * Index Existing Data Script
 * Bulk indexes all existing users, messages, and groups into Elasticsearch
 */

require('dotenv').config();
const mongoose = require('mongoose');
const indexer = require('../services/search/indexer');
const { dbConnection } = require('../database/config');

async function indexAllData() {
  try {
    console.log('Connecting to database...');
    await dbConnection();
    
    // Load models
    const Usuario = require('../models/usuario');
    const Mensaje = require('../models/mensaje');
    const Grupo = require('../models/grupo');
    
    console.log('Starting data indexing...\n');
    
    // Index users
    console.log('Indexing users...');
    const users = await Usuario.find({}).lean();
    let userCount = 0;
    for (const user of users) {
      await indexer.indexUser(user);
      userCount++;
      if (userCount % 100 === 0) {
        console.log(`  Indexed ${userCount} users...`);
      }
    }
    console.log(`✓ Indexed ${userCount} users\n`);
    
    // Index messages
    console.log('Indexing messages...');
    const messages = await Mensaje.find({}).lean();
    let messageCount = 0;
    for (const message of messages) {
      await indexer.indexMessage(message);
      messageCount++;
      if (messageCount % 100 === 0) {
        console.log(`  Indexed ${messageCount} messages...`);
      }
    }
    console.log(`✓ Indexed ${messageCount} messages\n`);
    
    // Index groups
    console.log('Indexing groups...');
    const groups = await Grupo.find({}).lean();
    let groupCount = 0;
    for (const group of groups) {
      await indexer.indexGroup(group);
      groupCount++;
      if (groupCount % 10 === 0) {
        console.log(`  Indexed ${groupCount} groups...`);
      }
    }
    console.log(`✓ Indexed ${groupCount} groups\n`);
    
    console.log('✅ Data indexing complete!');
    console.log(`Total indexed: ${userCount} users, ${messageCount} messages, ${groupCount} groups`);
    
    process.exit(0);
  } catch (error) {
    console.error('Error indexing data:', error);
    process.exit(1);
  }
}

indexAllData();






