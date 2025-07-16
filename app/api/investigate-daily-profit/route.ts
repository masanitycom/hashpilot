import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

export async function GET() {
  try {
    console.log('=== INVESTIGATING DAILY PROFIT RECORDS ===\n');
    
    const results = {
      totalRecords: 0,
      sampleRecords: [],
      distinctUsers: [],
      userSummary: [],
      userDetails: [],
      purchaseHistory: []
    };
    
    // 1. Check total records in user_daily_profit
    console.log('1. Fetching total records in user_daily_profit table...');
    const { data: totalRecords, error: totalError } = await supabase
      .from('user_daily_profit')
      .select('*')
      .order('date', { ascending: false });
    
    if (totalError) {
      console.error('Error fetching total records:', totalError);
      return NextResponse.json({ error: 'Failed to fetch total records', details: totalError }, { status: 500 });
    }
    
    results.totalRecords = totalRecords?.length || 0;
    results.sampleRecords = totalRecords?.slice(0, 10) || [];
    
    if (totalRecords && totalRecords.length > 0) {
      // 2. Get distinct users with daily profit
      console.log('2. Processing distinct users with daily profit...');
      const uniqueUsers = [...new Set(totalRecords.map(u => u.user_id))];
      results.distinctUsers = uniqueUsers;
      
      // 3. Create user profit summary
      console.log('3. Creating user profit summary...');
      const userSummary: any = {};
      totalRecords.forEach(record => {
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
      results.userSummary = Object.values(userSummary).sort((a: any, b: any) => b.total_profit_received - a.total_profit_received);
      
      // 4. Get user details
      console.log('4. Fetching user details...');
      if (uniqueUsers.length > 0) {
        const { data: userDetails, error: userError } = await supabase
          .from('users')
          .select('user_id, email, full_name, total_purchases, is_active, has_approved_nft, created_at')
          .in('user_id', uniqueUsers);
        
        if (userError) {
          console.error('Error fetching user details:', userError);
        } else {
          results.userDetails = userDetails || [];
        }
        
        // 5. Get purchase history
        console.log('5. Fetching purchase history...');
        const { data: purchases, error: purchaseError } = await supabase
          .from('purchases')
          .select('user_id, nft_quantity, amount_usd, payment_status, admin_approved, created_at, is_auto_purchase')
          .in('user_id', uniqueUsers)
          .order('user_id, created_at');
        
        if (purchaseError) {
          console.error('Error fetching purchase history:', purchaseError);
        } else {
          results.purchaseHistory = purchases || [];
        }
      }
    }
    
    return NextResponse.json(results);
    
  } catch (error) {
    console.error('Unexpected error:', error);
    return NextResponse.json({ error: 'Unexpected error occurred', details: error }, { status: 500 });
  }
}