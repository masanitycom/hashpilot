const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Supabase credentials not found in .env.local');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function executeSqlFile(filePath) {
  try {
    console.log(`📄 Reading SQL file: ${filePath}`);
    const sql = fs.readFileSync(filePath, 'utf8');

    console.log(`🔄 Executing SQL...`);
    const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });

    if (error) {
      console.error('❌ Error:', error);
      process.exit(1);
    }

    console.log('✅ SQL executed successfully');
    if (data) {
      console.log('📊 Result:', JSON.stringify(data, null, 2));
    }
  } catch (err) {
    console.error('❌ Exception:', err.message);
    process.exit(1);
  }
}

const sqlFile = process.argv[2];
if (!sqlFile) {
  console.error('Usage: node execute-sql.js <path-to-sql-file>');
  process.exit(1);
}

executeSqlFile(sqlFile);
