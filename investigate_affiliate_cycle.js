// Script to investigate affiliate cycle records
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

// Function to make API calls directly
async function fetchData(table, select = '*', filters = {}) {
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  url.searchParams.append('select', select);
  
  Object.entries(filters).forEach(([key, value]) => {
    url.searchParams.append(key, value);
  });
  
  const response = await fetch(url, {
    headers: {
      'apikey': supabaseAnonKey,
      'Authorization': `Bearer ${supabaseAnonKey}`,
      'Content-Type': 'application/json'
    }
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  return response.json();
}

async function investigateAffiliateSystem() {
  console.log('=== INVESTIGATING AFFILIATE SYSTEM ===\n');
  
  try {
    // 1. Check affiliate_cycle table
    console.log('1. Fetching affiliate_cycle records...');
    const affiliateCycles = await fetchData('affiliate_cycle', '*', { order: 'cycle_start_date.desc' });
    
    console.log(`Total records in affiliate_cycle: ${affiliateCycles.length}`);
    
    if (affiliateCycles.length > 0) {
      console.log('\nFirst 10 records:');
      affiliateCycles.slice(0, 10).forEach((record, index) => {
        console.log(`  ${index + 1}. User: ${record.user_id}`);
        console.log(`     Phase: ${record.phase}`);
        console.log(`     Total NFT Count: ${record.total_nft_count}`);
        console.log(`     Cumulative USDT: $${record.cum_usdt}`);
        console.log(`     Available USDT: $${record.available_usdt}`);
        console.log(`     Cycle Number: ${record.cycle_number}`);
        console.log(`     Cycle Start: ${record.cycle_start_date}`);
        console.log('');
      });
    }

    // 2. Check purchases table
    console.log('2. Fetching purchases records...');
    const purchases = await fetchData('purchases', '*', { order: 'created_at.desc' });
    
    console.log(`Total records in purchases: ${purchases.length}`);
    
    if (purchases.length > 0) {
      console.log('\nFirst 10 purchase records:');
      purchases.slice(0, 10).forEach((record, index) => {
        console.log(`  ${index + 1}. User: ${record.user_id}`);
        console.log(`     NFT Quantity: ${record.nft_quantity}`);
        console.log(`     Amount: $${record.amount_usd}`);
        console.log(`     Payment Status: ${record.payment_status}`);
        console.log(`     Admin Approved: ${record.admin_approved}`);
        console.log(`     Auto Purchase: ${record.is_auto_purchase}`);
        console.log(`     Created: ${record.created_at}`);
        console.log('');
      });
    }

    // 3. Check users table
    console.log('3. Fetching users records...');
    const users = await fetchData('users', '*', { order: 'created_at.desc' });
    
    console.log(`Total records in users: ${users.length}`);
    
    if (users.length > 0) {
      console.log('\nFirst 10 user records:');
      users.slice(0, 10).forEach((record, index) => {
        console.log(`  ${index + 1}. User ID: ${record.user_id}`);
        console.log(`     Email: ${record.email}`);
        console.log(`     Full Name: ${record.full_name}`);
        console.log(`     Total Purchases: $${record.total_purchases}`);
        console.log(`     Is Active: ${record.is_active}`);
        console.log(`     Has Approved NFT: ${record.has_approved_nft}`);
        console.log(`     Created: ${record.created_at}`);
        console.log('');
      });
    }

    // 4. Check daily_yield_log table
    console.log('4. Fetching daily_yield_log records...');
    const yieldLogs = await fetchData('daily_yield_log', '*', { order: 'date.desc' });
    
    console.log(`Total records in daily_yield_log: ${yieldLogs.length}`);
    
    if (yieldLogs.length > 0) {
      console.log('\nFirst 10 yield log records:');
      yieldLogs.slice(0, 10).forEach((record, index) => {
        console.log(`  ${index + 1}. Date: ${record.date}`);
        console.log(`     Yield Rate: ${record.yield_rate}`);
        console.log(`     Margin Rate: ${record.margin_rate}`);
        console.log(`     User Rate: ${record.user_rate}`);
        console.log(`     Is Month End: ${record.is_month_end}`);
        console.log(`     Created: ${record.created_at}`);
        console.log('');
      });
    }

    // 5. Check user_daily_profit table
    console.log('5. Fetching user_daily_profit records...');
    const dailyProfits = await fetchData('user_daily_profit', '*', { order: 'date.desc' });
    
    console.log(`Total records in user_daily_profit: ${dailyProfits.length}`);
    
    if (dailyProfits.length > 0) {
      console.log('\nFirst 10 daily profit records:');
      dailyProfits.slice(0, 10).forEach((record, index) => {
        console.log(`  ${index + 1}. User: ${record.user_id}`);
        console.log(`     Date: ${record.date}`);
        console.log(`     Daily Profit: $${record.daily_profit}`);
        console.log(`     Yield Rate: ${record.yield_rate}`);
        console.log(`     User Rate: ${record.user_rate}`);
        console.log(`     Base Amount: $${record.base_amount}`);
        console.log(`     Phase: ${record.phase}`);
        console.log(`     Created: ${record.created_at}`);
        console.log('');
      });
    }

    // 6. Summary analysis
    console.log('=== SYSTEM ANALYSIS ===');
    
    const approvedNftUsers = users.filter(user => user.has_approved_nft);
    console.log(`Users with approved NFT: ${approvedNftUsers.length}`);
    
    const approvedPurchases = purchases.filter(purchase => purchase.admin_approved);
    console.log(`Approved purchases: ${approvedPurchases.length}`);
    
    const userIdsWithCycles = affiliateCycles.map(cycle => cycle.user_id);
    const userIdsWithPurchases = purchases.map(purchase => purchase.user_id);
    
    console.log(`Users with cycles: ${userIdsWithCycles.length}`);
    console.log(`Users with purchases: ${userIdsWithPurchases.length}`);
    
    const usersWithBoth = userIdsWithCycles.filter(id => userIdsWithPurchases.includes(id));
    console.log(`Users with both cycles and purchases: ${usersWithBoth.length}`);
    
    // Check if there's a mismatch between users with NFTs and profit records
    const usersWith23Profit = dailyProfits.filter(profit => parseFloat(profit.daily_profit) > 23);
    console.log(`Daily profit records with >$23: ${usersWith23Profit.length}`);
    
    if (usersWith23Profit.length > 0) {
      console.log('\nHigh profit records:');
      usersWith23Profit.forEach(record => {
        console.log(`  User: ${record.user_id}, Profit: $${record.daily_profit}, Date: ${record.date}`);
      });
    }
    
  } catch (error) {
    console.error('Error occurred:', error);
  }
}

// Run the investigation
investigateAffiliateSystem();