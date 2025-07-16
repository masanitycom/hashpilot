// Simple script to investigate daily profit records
// Run this in the browser console or use Node.js with minimal dependencies

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

async function investigateDailyProfit() {
  console.log('=== INVESTIGATING DAILY PROFIT RECORDS ===\n');
  
  try {
    // 1. Check total records in user_daily_profit
    console.log('1. Fetching user_daily_profit records...');
    const dailyProfitRecords = await fetchData('user_daily_profit', '*', { order: 'date.desc' });
    
    console.log(`Total records in user_daily_profit: ${dailyProfitRecords.length}`);
    
    if (dailyProfitRecords.length > 0) {
      console.log('\\nFirst 5 records:');
      dailyProfitRecords.slice(0, 5).forEach((record, index) => {
        console.log(`  ${index + 1}. User: ${record.user_id}, Date: ${record.date}, Profit: $${record.daily_profit}`);
      });
      
      // 2. Get distinct users
      const uniqueUsers = [...new Set(dailyProfitRecords.map(record => record.user_id))];
      console.log(`\\nDistinct users with daily profit: ${uniqueUsers.length}`);
      console.log('User IDs:', uniqueUsers);
      
      // 3. Create user summary
      const userSummary = {};
      dailyProfitRecords.forEach(record => {
        const userId = record.user_id;
        if (!userSummary[userId]) {
          userSummary[userId] = {
            user_id: userId,
            profit_days: 0,
            total_profit_received: 0,
            first_profit_date: record.date,
            last_profit_date: record.date,
            profits: []
          };
        }
        
        userSummary[userId].profit_days++;
        userSummary[userId].total_profit_received += parseFloat(record.daily_profit || 0);
        userSummary[userId].profits.push(record);
        
        if (record.date < userSummary[userId].first_profit_date) {
          userSummary[userId].first_profit_date = record.date;
        }
        if (record.date > userSummary[userId].last_profit_date) {
          userSummary[userId].last_profit_date = record.date;
        }
      });
      
      // Sort by total profit received
      const sortedUsers = Object.values(userSummary).sort((a, b) => b.total_profit_received - a.total_profit_received);
      
      console.log('\\n=== USER PROFIT SUMMARY ===');
      sortedUsers.forEach((user, index) => {
        console.log(`${index + 1}. User: ${user.user_id}`);
        console.log(`   Profit days: ${user.profit_days}`);
        console.log(`   Total profit: $${user.total_profit_received.toFixed(2)}`);
        console.log(`   Average daily: $${(user.total_profit_received / user.profit_days).toFixed(2)}`);
        console.log(`   First profit: ${user.first_profit_date}`);
        console.log(`   Last profit: ${user.last_profit_date}`);
        console.log('');
      });
      
      // 4. Get user details
      if (uniqueUsers.length > 0) {
        console.log('\\n=== USER DETAILS ===');
        const userDetails = await fetchData('users', 'user_id,email,full_name,total_purchases,is_active,has_approved_nft,created_at');
        
        const profitUsers = userDetails.filter(user => uniqueUsers.includes(user.user_id));
        console.log(`Found ${profitUsers.length} user details out of ${uniqueUsers.length} profit users`);
        
        profitUsers.forEach((user, index) => {
          console.log(`${index + 1}. User ID: ${user.user_id}`);
          console.log(`   Email: ${user.email}`);
          console.log(`   Full Name: ${user.full_name}`);
          console.log(`   Total Purchases: $${user.total_purchases}`);
          console.log(`   Active: ${user.is_active}`);
          console.log(`   Has Approved NFT: ${user.has_approved_nft}`);
          console.log(`   Created: ${user.created_at}`);
          console.log('');
        });
        
        // 5. Get purchase history
        console.log('\\n=== PURCHASE HISTORY ===');
        const purchases = await fetchData('purchases', 'user_id,nft_quantity,amount_usd,payment_status,admin_approved,created_at,is_auto_purchase', { order: 'created_at.desc' });
        
        const profitUserPurchases = purchases.filter(purchase => uniqueUsers.includes(purchase.user_id));
        console.log(`Found ${profitUserPurchases.length} purchases for profit users`);
        
        profitUserPurchases.forEach((purchase, index) => {
          console.log(`${index + 1}. User: ${purchase.user_id}`);
          console.log(`   NFT Quantity: ${purchase.nft_quantity}`);
          console.log(`   Amount: $${purchase.amount_usd}`);
          console.log(`   Payment Status: ${purchase.payment_status}`);
          console.log(`   Admin Approved: ${purchase.admin_approved}`);
          console.log(`   Auto Purchase: ${purchase.is_auto_purchase}`);
          console.log(`   Created: ${purchase.created_at}`);
          console.log('');
        });
      }
    } else {
      console.log('No daily profit records found in the database.');
    }
    
  } catch (error) {
    console.error('Error occurred:', error);
  }
}

// Run the investigation
investigateDailyProfit();