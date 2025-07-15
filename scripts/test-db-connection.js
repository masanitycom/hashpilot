// Test database connection and run verification queries
const { createClient } = require('@supabase/supabase-js');

// Read environment variables directly from .env.local
const fs = require('fs');
const path = require('path');

// Read .env.local file
const envPath = path.join(__dirname, '..', '.env.local');
const envContent = fs.readFileSync(envPath, 'utf8');

let supabaseUrl = '';
let supabaseKey = '';

envContent.split('\n').forEach(line => {
  if (line.startsWith('NEXT_PUBLIC_SUPABASE_URL=')) {
    supabaseUrl = line.split('=')[1];
  }
  if (line.startsWith('NEXT_PUBLIC_SUPABASE_ANON_KEY=')) {
    supabaseKey = line.split('=')[1];
  }
});

console.log('=== ENVIRONMENT CHECK ===');
console.log('Supabase URL:', supabaseUrl);
console.log('Supabase Key:', supabaseKey ? `${supabaseKey.substring(0, 20)}...` : 'NOT SET');

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing environment variables!');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function runTests() {
  console.log('\n=== BASIC TABLE COUNTS ===');
  
  try {
    // Test users table
    const { data: users, error: usersError, count: usersCount } = await supabase
      .from('users')
      .select('*', { count: 'exact', head: true });
    
    console.log('Users table:', usersError ? `ERROR: ${usersError.message}` : `${usersCount} rows`);

    // Test purchases table
    const { data: purchases, error: purchasesError, count: purchasesCount } = await supabase
      .from('purchases')
      .select('*', { count: 'exact', head: true });
    
    console.log('Purchases table:', purchasesError ? `ERROR: ${purchasesError.message}` : `${purchasesCount} rows`);

    // Test user_daily_profit table
    const { data: profits, error: profitsError, count: profitsCount } = await supabase
      .from('user_daily_profit')
      .select('*', { count: 'exact', head: true });
    
    console.log('Daily profits table:', profitsError ? `ERROR: ${profitsError.message}` : `${profitsCount} rows`);

    // Test affiliate_cycle table
    const { data: cycles, error: cyclesError, count: cyclesCount } = await supabase
      .from('affiliate_cycle')
      .select('*', { count: 'exact', head: true });
    
    console.log('Affiliate cycle table:', cyclesError ? `ERROR: ${cyclesError.message}` : `${cyclesCount} rows`);

    console.log('\n=== SPECIFIC USER 7A9637 CHECK ===');
    
    const { data: specificUser, error: specificUserError } = await supabase
      .from('users')
      .select('*')
      .eq('user_id', '7A9637')
      .single();
    
    if (specificUserError) {
      console.log('User 7A9637 ERROR:', specificUserError.message);
    } else {
      console.log('User 7A9637 found:', specificUser);
    }

    console.log('\n=== SIMILAR USER IDs ===');
    
    const { data: similarUsers, error: similarError } = await supabase
      .from('users')
      .select('user_id, email, full_name, total_purchases, is_active, created_at')
      .or('user_id.like.%7A9637%,user_id.like.%7A%,user_id.like.%9637%')
      .order('created_at', { ascending: false });
    
    if (similarError) {
      console.log('Similar users ERROR:', similarError.message);
    } else {
      console.log('Similar users found:', similarUsers);
    }

    console.log('\n=== RECENT DAILY PROFITS ===');
    
    const { data: recentProfits, error: recentProfitsError } = await supabase
      .from('user_daily_profit')
      .select('user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at')
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (recentProfitsError) {
      console.log('Recent profits ERROR:', recentProfitsError.message);
    } else {
      console.log('Recent profits:', recentProfits);
    }

    console.log('\n=== RECENT PURCHASES ===');
    
    const { data: recentPurchases, error: recentPurchasesError } = await supabase
      .from('purchases')
      .select('user_id, nft_quantity, amount_usd, payment_status, admin_approved, created_at')
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (recentPurchasesError) {
      console.log('Recent purchases ERROR:', recentPurchasesError.message);
    } else {
      console.log('Recent purchases:', recentPurchases);
    }

    console.log('\n=== USER AUTH STATUS ===');
    
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError) {
      console.log('Auth ERROR:', authError.message);
    } else {
      console.log('Current user:', user ? user.id : 'No authenticated user');
    }

  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

runTests().then(() => {
  console.log('\n=== TEST COMPLETE ===');
}).catch(console.error);