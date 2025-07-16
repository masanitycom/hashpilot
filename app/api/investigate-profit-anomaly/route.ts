import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

const supabase = createClient(supabaseUrl, supabaseKey);

export async function GET(request: NextRequest) {
  try {
    console.log('🔍 7A9637利益異常調査開始');
    
    // 1. 7A9637の基本情報を確認
    const { data: user7A9637, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('user_id', '7A9637')
      .single();
    
    if (userError) {
      console.error('❌ 7A9637ユーザー情報取得エラー:', userError);
    }
    
    // 2. 7A9637の購入情報を確認
    const { data: purchases7A9637, error: purchaseError } = await supabase
      .from('purchases')
      .select('*')
      .eq('user_id', '7A9637')
      .order('purchase_date', { ascending: false });
    
    if (purchaseError) {
      console.error('❌ 7A9637購入情報取得エラー:', purchaseError);
    }
    
    // 3. 7A9637のaffiliate_cycle状況を確認
    const { data: cycle7A9637, error: cycleError } = await supabase
      .from('affiliate_cycle')
      .select('*')
      .eq('user_id', '7A9637')
      .single();
    
    if (cycleError) {
      console.error('❌ 7A9637サイクル情報取得エラー:', cycleError);
    }
    
    // 4. 7A9637の利益履歴を確認
    const { data: profits7A9637, error: profitError } = await supabase
      .from('user_daily_profit')
      .select('*')
      .eq('user_id', '7A9637')
      .order('date', { ascending: false });
    
    if (profitError) {
      console.error('❌ 7A9637利益履歴取得エラー:', profitError);
    }
    
    // 5. 全ユーザーの利益履歴を確認
    const { data: allProfits, error: allProfitError } = await supabase
      .from('user_daily_profit')
      .select('*')
      .order('date', { ascending: false });
    
    if (allProfitError) {
      console.error('❌ 全利益履歴取得エラー:', allProfitError);
    }
    
    // 6. 運用開始済みユーザーの確認
    const { data: activeUsers, error: activeUserError } = await supabase
      .from('users')
      .select(`
        user_id,
        email,
        full_name,
        has_approved_nft,
        is_active,
        total_purchases,
        purchases!inner (
          purchase_date,
          admin_approved,
          nft_quantity,
          amount_usd
        )
      `)
      .eq('has_approved_nft', true)
      .eq('is_active', true)
      .not('purchases.admin_approved', 'is', null);
    
    if (activeUserError) {
      console.error('❌ 運用開始済みユーザー取得エラー:', activeUserError);
    }
    
    // 7. affiliate_cycleテーブルの全データを確認
    const { data: allCycles, error: allCycleError } = await supabase
      .from('affiliate_cycle')
      .select('*')
      .order('user_id');
    
    if (allCycleError) {
      console.error('❌ 全サイクル情報取得エラー:', allCycleError);
    }
    
    // 8. 最新の日利設定を確認
    const { data: latestYield, error: yieldError } = await supabase
      .from('daily_yield_log')
      .select('*')
      .order('date', { ascending: false })
      .limit(1);
    
    if (yieldError) {
      console.error('❌ 最新日利設定取得エラー:', yieldError);
    }
    
    // 9. 利益が0でないユーザーの一覧
    const { data: usersWithProfit, error: profitUserError } = await supabase
      .from('user_daily_profit')
      .select('user_id, SUM(daily_profit) as total_profit')
      .group('user_id')
      .having('SUM(daily_profit) > 0');
    
    if (profitUserError) {
      console.error('❌ 利益ありユーザー取得エラー:', profitUserError);
    }
    
    // 10. 15日経過条件を満たすユーザーの確認
    const { data: eligibleUsers, error: eligibleError } = await supabase
      .from('purchases')
      .select(`
        user_id,
        purchase_date,
        admin_approved,
        nft_quantity,
        amount_usd,
        users!inner (
          user_id,
          email,
          full_name,
          has_approved_nft,
          is_active
        )
      `)
      .not('admin_approved', 'is', null)
      .eq('users.has_approved_nft', true)
      .eq('users.is_active', true)
      .lte('admin_approved', new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString());
    
    if (eligibleError) {
      console.error('❌ 15日経過ユーザー取得エラー:', eligibleError);
    }
    
    const response = {
      timestamp: new Date().toISOString(),
      investigation: {
        user_7A9637: {
          user_info: user7A9637,
          purchases: purchases7A9637,
          cycle_info: cycle7A9637,
          profit_history: profits7A9637
        },
        system_overview: {
          all_profits: allProfits,
          active_users: activeUsers,
          all_cycles: allCycles,
          latest_yield_setting: latestYield,
          users_with_profit: usersWithProfit,
          eligible_15day_users: eligibleUsers
        },
        analysis: {
          total_users_with_profit: usersWithProfit?.length || 0,
          user_7A9637_total_profit: profits7A9637?.reduce((sum, p) => sum + (p.daily_profit || 0), 0) || 0,
          eligible_users_count: eligibleUsers?.length || 0,
          cycle_users_count: allCycles?.length || 0
        }
      }
    };
    
    console.log('✅ 調査完了:', response);
    
    return NextResponse.json(response);
    
  } catch (error) {
    console.error('❌ 調査中にエラーが発生:', error);
    return NextResponse.json({ 
      error: '調査中にエラーが発生しました',
      details: error instanceof Error ? error.message : String(error)
    }, { status: 500 });
  }
}