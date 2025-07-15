const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkNFTStatus() {
  const userIds = ['Y9FVT1', '7A9637'];
  
  console.log('=== CHECKING NFT STATUS FOR USERS:', userIds.join(', '), '===\n');
  
  try {
    // Query 1: Check purchases table with operation start calculation
    console.log('=== PURCHASES TABLE CHECK ===');
    const { data: purchasesData, error: purchasesError } = await supabase
      .from('purchases')
      .select(`
        user_id,
        amount_usd,
        nft_quantity,
        admin_approved,
        admin_approved_at,
        payment_status,
        created_at
      `)
      .in('user_id', userIds)
      .order('created_at', { ascending: true });

    if (purchasesError) {
      console.error('Purchases query error:', purchasesError);
    } else {
      purchasesData.forEach(purchase => {
        const operationStartDate = purchase.admin_approved_at 
          ? new Date(new Date(purchase.admin_approved_at).getTime() + 15 * 24 * 60 * 60 * 1000)
          : null;
        
        const operationStatus = purchase.admin_approved_at
          ? (operationStartDate && operationStartDate <= new Date() ? 'Started' : 'Waiting')
          : 'Not Approved';

        console.log(`User: ${purchase.user_id}`);
        console.log(`  Amount: $${purchase.amount_usd} (${purchase.nft_quantity} NFT)`);
        console.log(`  Admin Approved: ${purchase.admin_approved}`);
        console.log(`  Approved At: ${purchase.admin_approved_at || 'Not approved'}`);
        console.log(`  Operation Start Date: ${operationStartDate ? operationStartDate.toISOString().split('T')[0] : 'N/A'}`);
        console.log(`  Operation Status: ${operationStatus}`);
        console.log(`  Payment Status: ${purchase.payment_status}`);
        console.log(`  Created: ${purchase.created_at}`);
        console.log('---');
      });
    }

    // Query 2: Check daily profit records
    console.log('\n=== DAILY PROFIT RECORDS CHECK ===');
    const { data: dailyProfitData, error: dailyProfitError } = await supabase
      .from('user_daily_profit')
      .select('user_id, daily_profit, date, yield_rate, base_amount')
      .in('user_id', userIds)
      .order('date', { ascending: false });

    if (dailyProfitError) {
      console.error('Daily profit query error:', dailyProfitError);
    } else {
      const profitSummary = userIds.map(userId => {
        const userProfits = dailyProfitData?.filter(p => p.user_id === userId) || [];
        return {
          user_id: userId,
          profit_days: userProfits.length,
          total_profit: userProfits.reduce((sum, p) => sum + (p.daily_profit || 0), 0),
          first_profit_date: userProfits.length > 0 ? userProfits[userProfits.length - 1]?.date : null,
          latest_profit_date: userProfits.length > 0 ? userProfits[0]?.date : null
        };
      });

      profitSummary.forEach(summary => {
        console.log(`User: ${summary.user_id}`);
        console.log(`  Profit Days: ${summary.profit_days}`);
        console.log(`  Total Profit: $${summary.total_profit.toFixed(2)}`);
        console.log(`  First Profit: ${summary.first_profit_date || 'None'}`);
        console.log(`  Latest Profit: ${summary.latest_profit_date || 'None'}`);
        console.log('---');
      });
    }

    // Query 3: Check affiliate cycle status
    console.log('\n=== AFFILIATE CYCLE STATUS CHECK ===');
    const { data: affiliateCycleData, error: affiliateCycleError } = await supabase
      .from('affiliate_cycle')
      .select(`
        user_id,
        total_nft_count,
        available_usdt,
        phase,
        cum_usdt,
        next_action,
        updated_at
      `)
      .in('user_id', userIds);

    if (affiliateCycleError) {
      console.error('Affiliate cycle query error:', affiliateCycleError);
    } else {
      affiliateCycleData.forEach(cycle => {
        console.log(`User: ${cycle.user_id}`);
        console.log(`  Total NFT Count: ${cycle.total_nft_count}`);
        console.log(`  Available USDT: $${cycle.available_usdt}`);
        console.log(`  Phase: ${cycle.phase}`);
        console.log(`  Cumulative USDT: $${cycle.cum_usdt}`);
        console.log(`  Next Action: ${cycle.next_action}`);
        console.log(`  Updated: ${cycle.updated_at}`);
        console.log('---');
      });
    }

    // Query 4: Check users table
    console.log('\n=== USERS TABLE CHECK ===');
    const { data: usersData, error: usersError } = await supabase
      .from('users')
      .select(`
        user_id,
        email,
        full_name,
        has_approved_nft,
        is_active,
        created_at
      `)
      .in('user_id', userIds);

    if (usersError) {
      console.error('Users query error:', usersError);
    } else {
      usersData.forEach(user => {
        console.log(`User: ${user.user_id}`);
        console.log(`  Email: ${user.email}`);
        console.log(`  Name: ${user.full_name || 'Not set'}`);
        console.log(`  Has Approved NFT: ${user.has_approved_nft}`);
        console.log(`  Is Active: ${user.is_active}`);
        console.log(`  Created: ${user.created_at}`);
        console.log('---');
      });
    }

    console.log('\n=== ANALYSIS ===');
    console.log(`Current Date: ${new Date().toISOString().split('T')[0]}`);
    console.log('Note: If admin_approved_at + 15 days <= current date, daily profits should be running');
    
  } catch (error) {
    console.error('Script error:', error);
  }
}

checkNFTStatus();