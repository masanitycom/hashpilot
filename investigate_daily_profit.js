#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase configuration in environment variables');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function investigateDailyProfit() {
  console.log('=== INVESTIGATING DAILY PROFIT RECORDS ===\n');
  
  try {
    // 1. Check total records in user_daily_profit
    console.log('1. Total records in user_daily_profit table:');
    const { data: totalRecords, error: totalError } = await supabase
      .from('user_daily_profit')
      .select('*', { count: 'exact' });
    
    if (totalError) {
      console.error('Error fetching total records:', totalError);
    } else {
      console.log(`Total records: ${totalRecords?.length || 0}`);
      if (totalRecords && totalRecords.length > 0) {
        console.log('Sample records:');
        totalRecords.slice(0, 5).forEach((record, index) => {
          console.log(`  ${index + 1}. User: ${record.user_id}, Date: ${record.date}, Profit: ${record.daily_profit}`);
        });
      }
    }
    
    console.log('\n2. Distinct users with daily profit:');
    // Get distinct users with daily profit
    const { data: distinctUsers, error: distinctError } = await supabase
      .from('user_daily_profit')
      .select('user_id')
      .order('user_id');
    
    if (distinctError) {
      console.error('Error fetching distinct users:', distinctError);
    } else {
      const uniqueUsers = [...new Set(distinctUsers?.map(u => u.user_id) || [])];
      console.log(`Number of unique users with daily profit: ${uniqueUsers.length}`);
      console.log('User IDs:', uniqueUsers);
    }
    
    console.log('\n3. User daily profit summary:');
    // Get user profit summary using a more complex query
    const { data: profitData, error: profitError } = await supabase
      .from('user_daily_profit')
      .select('user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase');
    
    if (profitError) {
      console.error('Error fetching profit data:', profitError);
    } else if (profitData && profitData.length > 0) {
      // Group by user_id and calculate summary
      const userSummary = {};
      profitData.forEach(record => {
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
      
      console.log('User profit summary:');
      sortedUsers.forEach((user, index) => {
        console.log(`  ${index + 1}. User: ${user.user_id}`);
        console.log(`     Profit days: ${user.profit_days}`);
        console.log(`     Total profit: $${user.total_profit_received.toFixed(2)}`);
        console.log(`     Average daily: $${(user.total_profit_received / user.profit_days).toFixed(2)}`);
        console.log(`     First profit: ${user.first_profit_date}`);
        console.log(`     Last profit: ${user.last_profit_date}`);
        console.log('');
      });
    }
    
    console.log('\n4. User details for those with daily profit:');
    // Get user details
    if (distinctUsers && distinctUsers.length > 0) {
      const userIds = [...new Set(distinctUsers.map(u => u.user_id))];
      const { data: userDetails, error: userError } = await supabase
        .from('users')
        .select('user_id, email, full_name, total_purchases, is_active, has_approved_nft, created_at')
        .in('user_id', userIds);
      
      if (userError) {
        console.error('Error fetching user details:', userError);
      } else if (userDetails && userDetails.length > 0) {
        console.log('User details:');
        userDetails.forEach((user, index) => {
          console.log(`  ${index + 1}. User ID: ${user.user_id}`);
          console.log(`     Email: ${user.email}`);
          console.log(`     Full Name: ${user.full_name}`);
          console.log(`     Total Purchases: $${user.total_purchases}`);
          console.log(`     Active: ${user.is_active}`);
          console.log(`     Has Approved NFT: ${user.has_approved_nft}`);
          console.log(`     Created: ${user.created_at}`);
          console.log('');
        });
      }
    }
    
    console.log('\n5. Purchase history for users with daily profit:');
    // Get purchase history
    if (distinctUsers && distinctUsers.length > 0) {
      const userIds = [...new Set(distinctUsers.map(u => u.user_id))];
      const { data: purchases, error: purchaseError } = await supabase
        .from('purchases')
        .select('user_id, nft_quantity, amount_usd, payment_status, admin_approved, created_at, is_auto_purchase')
        .in('user_id', userIds)
        .order('user_id, created_at');
      
      if (purchaseError) {
        console.error('Error fetching purchase history:', purchaseError);
      } else if (purchases && purchases.length > 0) {
        console.log('Purchase history:');
        purchases.forEach((purchase, index) => {
          console.log(`  ${index + 1}. User: ${purchase.user_id}`);
          console.log(`     NFT Quantity: ${purchase.nft_quantity}`);
          console.log(`     Amount: $${purchase.amount_usd}`);
          console.log(`     Payment Status: ${purchase.payment_status}`);
          console.log(`     Admin Approved: ${purchase.admin_approved}`);
          console.log(`     Auto Purchase: ${purchase.is_auto_purchase}`);
          console.log(`     Created: ${purchase.created_at}`);
          console.log('');
        });
      }
    }
    
  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

investigateDailyProfit();