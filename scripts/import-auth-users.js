#!/usr/bin/env node
/**
 * Import auth.users data to test environment
 */

const fs = require('fs');
const { Pool } = require('pg');

const TEST_DB_URL = 'postgresql://postgres:8tZ8dZUYScKR@db.objpuphnhcjxrsiydjbf.supabase.co:5432/postgres';

async function importAuthUsers() {
  const pool = new Pool({
    connectionString: TEST_DB_URL,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Reading auth-users.sql...');
    const sql = fs.readFileSync('auth-users.sql', 'utf8');

    console.log('File size:', (sql.length / 1024 / 1024).toFixed(2), 'MB');
    console.log('Importing to test environment...');

    const client = await pool.connect();

    try {
      await client.query(sql);
      console.log('✅ Import completed successfully!');
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('❌ Import failed:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

importAuthUsers();
