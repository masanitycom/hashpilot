// Script to investigate database with admin authentication
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

// Function to authenticate as admin
async function authenticateAsAdmin() {
  const response = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': supabaseAnonKey,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: 'basarasystems@gmail.com',
      password: 'Admin@123'
    })
  });
  
  if (!response.ok) {
    throw new Error(`Auth failed: ${response.status}`);
  }
  
  const data = await response.json();
  return data.access_token;
}

// Function to make authenticated API calls
async function fetchDataWithAuth(table, select = '*', filters = {}) {
  const token = await authenticateAsAdmin();
  
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  url.searchParams.append('select', select);
  
  Object.entries(filters).forEach(([key, value]) => {
    url.searchParams.append(key, value);
  });
  
  const response = await fetch(url, {
    headers: {
      'apikey': supabaseAnonKey,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  return response.json();
}

async function investigateWithAdminAuth() {
  console.log('=== INVESTIGATING WITH ADMIN AUTHENTICATION ===\n');
  
  try {
    console.log('Authenticating as admin...');
    
    // 1. Check users table
    console.log('1. Fetching users records...');
    const users = await fetchDataWithAuth('users', '*', { order: 'created_at.desc' });
    
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

    // 2. Check purchases table
    console.log('2. Fetching purchases records...');
    const purchases = await fetchDataWithAuth('purchases', '*', { order: 'created_at.desc' });
    
    console.log(`Total records in purchases: ${purchases.length}`);
    
    if (purchases.length > 0) {
      console.log('\nFirst 10 purchase records:');
      purchases.slice(0, 10).forEach((record, index) => {
        console.log(`  ${index + 1}. User: ${record.user_id}`);
        console.log(`     NFT Quantity: ${record.nft_quantity}`);
        console.log(`     Amount: $${record.amount_usd}`);
        console.log(`     Payment Status: ${record.payment_status}`);
        console.log(`     Admin Approved: ${record.admin_approved}`);
        console.log(`     Auto Purchase: ${record.is_auto_purchase || false}`);
        console.log(`     Created: ${record.created_at}`);
        console.log('');
      });
    }

    // 3. Check affiliate_cycle table
    console.log('3. Fetching affiliate_cycle records...');
    const affiliateCycles = await fetchDataWithAuth('affiliate_cycle', '*', { order: 'cycle_start_date.desc' });
    
    console.log(`Total records in affiliate_cycle: ${affiliateCycles.length}`);
    
    if (affiliateCycles.length > 0) {
      console.log('\nFirst 10 affiliate_cycle records:');
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

    // 4. Check user_daily_profit table
    console.log('4. Fetching user_daily_profit records...');
    const dailyProfits = await fetchDataWithAuth('user_daily_profit', '*', { order: 'date.desc' });
    
    console.log(`Total records in user_daily_profit: ${dailyProfits.length}`);
    
    if (dailyProfits.length > 0) {
      console.log('\nFirst 20 daily profit records:');
      dailyProfits.slice(0, 20).forEach((record, index) => {
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

    // 5. Analysis
    console.log('=== ANALYSIS ===');
    
    // Users with approved NFT
    const approvedNftUsers = users.filter(user => user.has_approved_nft);
    console.log(`Users with approved NFT: ${approvedNftUsers.length}`);
    
    // Approved purchases
    const approvedPurchases = purchases.filter(purchase => purchase.admin_approved);
    console.log(`Approved purchases: ${approvedPurchases.length}`);
    
    // Users with cycles
    const usersWithCycles = affiliateCycles.filter(cycle => cycle.total_nft_count > 0);
    console.log(`Users with active cycles: ${usersWithCycles.length}`);
    
    // Users with daily profit
    const usersWithDailyProfit = [...new Set(dailyProfits.map(profit => profit.user_id))];
    console.log(`Users with daily profit records: ${usersWithDailyProfit.length}`);
    
    // Calculate total profit distributed
    const totalProfitDistributed = dailyProfits.reduce((sum, profit) => sum + parseFloat(profit.daily_profit || 0), 0);
    console.log(`Total profit distributed: $${totalProfitDistributed.toFixed(2)}`);
    
    // User profit summary
    if (dailyProfits.length > 0) {
      const userProfitSummary = {};
      dailyProfits.forEach(profit => {
        const userId = profit.user_id;
        if (!userProfitSummary[userId]) {
          userProfitSummary[userId] = {
            totalProfit: 0,
            profitDays: 0,
            firstDate: profit.date,
            lastDate: profit.date
          };
        }
        userProfitSummary[userId].totalProfit += parseFloat(profit.daily_profit || 0);
        userProfitSummary[userId].profitDays++;
        
        if (profit.date < userProfitSummary[userId].firstDate) {
          userProfitSummary[userId].firstDate = profit.date;
        }
        if (profit.date > userProfitSummary[userId].lastDate) {
          userProfitSummary[userId].lastDate = profit.date;
        }
      });
      
      console.log('\n=== USER PROFIT SUMMARY ===');
      Object.entries(userProfitSummary).forEach(([userId, summary]) => {
        console.log(`User: ${userId}`);
        console.log(`  Total Profit: $${summary.totalProfit.toFixed(2)}`);
        console.log(`  Profit Days: ${summary.profitDays}`);
        console.log(`  Average Daily: $${(summary.totalProfit / summary.profitDays).toFixed(2)}`);
        console.log(`  First Date: ${summary.firstDate}`);
        console.log(`  Last Date: ${summary.lastDate}`);
        console.log('');
      });
    }
    
  } catch (error) {
    console.error('Error occurred:', error);
    console.error('Stack:', error.stack);
  }
}

// Run the investigation
investigateWithAdminAuth();