const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkAllUsers() {
  console.log('=== CHECKING ALL USERS AND RECENT ACTIVITY ===\n');
  
  try {
    // Check all users
    console.log('=== ALL USERS (FIRST 10) ===');
    const { data: usersData, error: usersError } = await supabase
      .from('users')
      .select('user_id, email, has_approved_nft, is_active, created_at')
      .order('created_at', { ascending: false })
      .limit(10);

    if (usersError) {
      console.error('Users query error:', usersError);
    } else {
      console.log(`Found ${usersData.length} users:`);
      usersData.forEach(user => {
        console.log(`  ${user.user_id} - ${user.email} - NFT: ${user.has_approved_nft} - Active: ${user.is_active}`);
      });
    }

    // Check recent purchases
    console.log('\n=== RECENT PURCHASES (LAST 10) ===');
    const { data: purchasesData, error: purchasesError } = await supabase
      .from('purchases')
      .select('user_id, amount_usd, admin_approved, admin_approved_at, created_at')
      .order('created_at', { ascending: false })
      .limit(10);

    if (purchasesError) {
      console.error('Purchases query error:', purchasesError);
    } else {
      console.log(`Found ${purchasesData.length} purchases:`);
      purchasesData.forEach(purchase => {
        const operationStartDate = purchase.admin_approved_at 
          ? new Date(new Date(purchase.admin_approved_at).getTime() + 15 * 24 * 60 * 60 * 1000)
          : null;
        
        const operationStatus = purchase.admin_approved_at
          ? (operationStartDate && operationStartDate <= new Date() ? 'Started' : 'Waiting')
          : 'Not Approved';

        console.log(`  ${purchase.user_id} - $${purchase.amount_usd} - ${operationStatus} - ${purchase.created_at}`);
      });
    }

    // Check affiliate cycle data
    console.log('\n=== AFFILIATE CYCLE DATA (FIRST 10) ===');
    const { data: cycleData, error: cycleError } = await supabase
      .from('affiliate_cycle')
      .select('user_id, total_nft_count, available_usdt, phase, updated_at')
      .order('updated_at', { ascending: false })
      .limit(10);

    if (cycleError) {
      console.error('Affiliate cycle query error:', cycleError);
    } else {
      console.log(`Found ${cycleData.length} cycle records:`);
      cycleData.forEach(cycle => {
        console.log(`  ${cycle.user_id} - ${cycle.total_nft_count} NFTs - $${cycle.available_usdt} USDT - ${cycle.phase}`);
      });
    }

    // Check for any daily profits
    console.log('\n=== RECENT DAILY PROFITS (LAST 10) ===');
    const { data: profitData, error: profitError } = await supabase
      .from('user_daily_profit')
      .select('user_id, daily_profit, date')
      .order('date', { ascending: false })
      .limit(10);

    if (profitError) {
      console.error('Daily profit query error:', profitError);
    } else {
      console.log(`Found ${profitData.length} daily profit records:`);
      profitData.forEach(profit => {
        console.log(`  ${profit.user_id} - $${profit.daily_profit} on ${profit.date}`);
      });
    }

    // Search for users with similar IDs
    console.log('\n=== SEARCHING FOR USERS WITH SIMILAR IDs ===');
    const searchIds = ['Y9FVT1', '7A9637'];
    for (const searchId of searchIds) {
      const { data: searchResults, error: searchError } = await supabase
        .from('users')
        .select('user_id, email')
        .ilike('user_id', `%${searchId.slice(-3)}%`); // Search for last 3 characters

      if (!searchError && searchResults.length > 0) {
        console.log(`Similar to ${searchId}:`);
        searchResults.forEach(user => {
          console.log(`  ${user.user_id} - ${user.email}`);
        });
      }
    }
    
  } catch (error) {
    console.error('Script error:', error);
  }
}

checkAllUsers();