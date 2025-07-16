// Comprehensive database status check
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

async function checkDatabaseStatus() {
  console.log('=== DATABASE STATUS CHECK ===\n');
  
  const tables = [
    'users',
    'purchases', 
    'user_daily_profit',
    'affiliate_cycle',
    'withdrawal_requests',
    'daily_yield_log',
    'system_logs'
  ];
  
  for (const table of tables) {
    try {
      console.log(`Checking table: ${table}`);
      const data = await fetchData(table, '*', { limit: '5' });
      console.log(`  Records: ${data.length}`);
      
      if (data.length > 0) {
        console.log(`  Sample record structure:`);
        const sampleRecord = data[0];
        Object.keys(sampleRecord).forEach(key => {
          console.log(`    ${key}: ${sampleRecord[key]}`);
        });
      }
      console.log('');
    } catch (error) {
      console.error(`  Error accessing ${table}:`, error.message);
      console.log('');
    }
  }
  
  // Check for specific data patterns
  console.log('=== SPECIFIC DATA CHECKS ===\n');
  
  try {
    // Check users with NFT purchases
    console.log('1. Users with NFT purchases:');
    const users = await fetchData('users', 'user_id,email,total_purchases,has_approved_nft,created_at');
    const usersWithPurchases = users.filter(user => user.total_purchases > 0);
    console.log(`   Users with purchases: ${usersWithPurchases.length} out of ${users.length}`);
    
    if (usersWithPurchases.length > 0) {
      usersWithPurchases.slice(0, 5).forEach((user, index) => {
        console.log(`   ${index + 1}. ${user.email} - $${user.total_purchases} - NFT: ${user.has_approved_nft}`);
      });
    }
    console.log('');
    
    // Check purchases
    console.log('2. Purchase records:');
    const purchases = await fetchData('purchases', 'user_id,nft_quantity,amount_usd,admin_approved,created_at,is_auto_purchase');
    console.log(`   Total purchases: ${purchases.length}`);
    
    if (purchases.length > 0) {
      const approvedPurchases = purchases.filter(p => p.admin_approved);
      const autoPurchases = purchases.filter(p => p.is_auto_purchase);
      console.log(`   Approved purchases: ${approvedPurchases.length}`);
      console.log(`   Auto purchases: ${autoPurchases.length}`);
      
      console.log('   Recent purchases:');
      purchases.slice(0, 5).forEach((purchase, index) => {
        console.log(`   ${index + 1}. User: ${purchase.user_id}, NFT: ${purchase.nft_quantity}, Amount: $${purchase.amount_usd}, Approved: ${purchase.admin_approved}`);
      });
    }
    console.log('');
    
    // Check affiliate cycle
    console.log('3. Affiliate cycle records:');
    const affiliateCycle = await fetchData('affiliate_cycle', 'user_id,phase,total_nft_count,cum_usdt,available_usdt');
    console.log(`   Affiliate cycle records: ${affiliateCycle.length}`);
    
    if (affiliateCycle.length > 0) {
      affiliateCycle.slice(0, 5).forEach((cycle, index) => {
        console.log(`   ${index + 1}. User: ${cycle.user_id}, Phase: ${cycle.phase}, NFT: ${cycle.total_nft_count}, USDT: ${cycle.cum_usdt}`);
      });
    }
    console.log('');
    
    // Check daily yield log
    console.log('4. Daily yield log:');
    const dailyYieldLog = await fetchData('daily_yield_log', 'date,yield_rate,user_rate,is_month_end', { order: 'date.desc' });
    console.log(`   Daily yield log records: ${dailyYieldLog.length}`);
    
    if (dailyYieldLog.length > 0) {
      console.log('   Recent yield settings:');
      dailyYieldLog.slice(0, 5).forEach((log, index) => {
        console.log(`   ${index + 1}. Date: ${log.date}, Yield: ${log.yield_rate}%, User: ${log.user_rate}%, Month End: ${log.is_month_end}`);
      });
    }
    console.log('');
    
    // Check withdrawal requests
    console.log('5. Withdrawal requests:');
    const withdrawals = await fetchData('withdrawal_requests', 'user_id,amount,status,created_at');
    console.log(`   Withdrawal requests: ${withdrawals.length}`);
    
    if (withdrawals.length > 0) {
      withdrawals.slice(0, 5).forEach((withdrawal, index) => {
        console.log(`   ${index + 1}. User: ${withdrawal.user_id}, Amount: $${withdrawal.amount}, Status: ${withdrawal.status}`);
      });
    }
    console.log('');
    
    // Check system logs
    console.log('6. System logs:');
    const systemLogs = await fetchData('system_logs', 'log_type,operation,message,created_at', { order: 'created_at.desc' });
    console.log(`   System logs: ${systemLogs.length}`);
    
    if (systemLogs.length > 0) {
      console.log('   Recent system logs:');
      systemLogs.slice(0, 5).forEach((log, index) => {
        console.log(`   ${index + 1}. Type: ${log.log_type}, Operation: ${log.operation}, Message: ${log.message}`);
      });
    }
    console.log('');
    
  } catch (error) {
    console.error('Error during specific checks:', error);
  }
}

// Run the check
checkDatabaseStatus();