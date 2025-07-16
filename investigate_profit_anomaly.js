#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');

// Environment variables - adjust these as needed
const supabaseUrl = 'https://eynhcxzgfgbpnfqnuqul.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5bmhjeHpnZmdpcG5mcW51cXVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjA2MjEyMjMsImV4cCI6MjAzNjE5NzIyM30.8_mELQGxFUYxGn_VYNQzJVzYKEBcyQRjLgLQKC0L8Gg';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function investigateProfitAnomaly() {
  console.log('🔍 7A9637利益異常調査開始 🔍\n');
  
  try {
    // 1. 7A9637の基本情報を確認
    console.log('1. 7A9637ユーザーの基本情報:');
    const { data: user7A9637, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('user_id', '7A9637')
      .single();
    
    if (userError) {
      console.error('❌ 7A9637ユーザー情報取得エラー:', userError);
    } else {
      console.log('✅ 7A9637ユーザー情報:');
      console.log('   Email:', user7A9637.email);
      console.log('   Full Name:', user7A9637.full_name);
      console.log('   Total Purchases:', user7A9637.total_purchases);
      console.log('   Has Approved NFT:', user7A9637.has_approved_nft);
      console.log('   Is Active:', user7A9637.is_active);
      console.log('   Created:', user7A9637.created_at);
    }
    
    // 2. 7A9637の購入履歴を確認
    console.log('\n2. 7A9637の購入履歴:');
    const { data: purchases7A9637, error: purchaseError } = await supabase
      .from('purchases')
      .select('*')
      .eq('user_id', '7A9637')
      .order('purchase_date', { ascending: false });
    
    if (purchaseError) {
      console.error('❌ 7A9637購入履歴取得エラー:', purchaseError);
    } else {
      console.log(`✅ 7A9637の購入記録数: ${purchases7A9637.length}`);
      purchases7A9637.forEach((purchase, index) => {
        console.log(`   ${index + 1}. NFT数: ${purchase.nft_quantity}, 金額: $${purchase.amount_usd}`);
        console.log(`      購入日: ${purchase.purchase_date}`);
        console.log(`      管理者承認: ${purchase.admin_approved}`);
        console.log(`      自動購入: ${purchase.is_auto_purchase}`);
        console.log(`      支払い状況: ${purchase.payment_status}`);
        console.log('');
      });
    }
    
    // 3. 7A9637のaffiliate_cycle状況を確認
    console.log('\n3. 7A9637のaffiliate_cycle状況:');
    const { data: cycle7A9637, error: cycleError } = await supabase
      .from('affiliate_cycle')
      .select('*')
      .eq('user_id', '7A9637')
      .single();
    
    if (cycleError) {
      console.error('❌ 7A9637サイクル情報取得エラー:', cycleError);
    } else {
      console.log('✅ 7A9637サイクル情報:');
      console.log('   Phase:', cycle7A9637.phase);
      console.log('   Total NFT Count:', cycle7A9637.total_nft_count);
      console.log('   Cumulative USDT:', cycle7A9637.cum_usdt);
      console.log('   Available USDT:', cycle7A9637.available_usdt);
      console.log('   Auto NFT Count:', cycle7A9637.auto_nft_count);
      console.log('   Manual NFT Count:', cycle7A9637.manual_nft_count);
      console.log('   Cycle Number:', cycle7A9637.cycle_number);
      console.log('   Cycle Start Date:', cycle7A9637.cycle_start_date);
    }
    
    // 4. 7A9637の利益履歴を確認
    console.log('\n4. 7A9637の利益履歴:');
    const { data: profits7A9637, error: profitError } = await supabase
      .from('user_daily_profit')
      .select('*')
      .eq('user_id', '7A9637')
      .order('date', { ascending: false });
    
    if (profitError) {
      console.error('❌ 7A9637利益履歴取得エラー:', profitError);
    } else {
      console.log(`✅ 7A9637の利益記録数: ${profits7A9637.length}`);
      const totalProfit = profits7A9637.reduce((sum, p) => sum + (p.daily_profit || 0), 0);
      console.log(`   合計利益: $${totalProfit.toFixed(2)}`);
      
      profits7A9637.forEach((profit, index) => {
        console.log(`   ${index + 1}. 日付: ${profit.date}, 利益: $${profit.daily_profit}`);
        console.log(`      利率: ${profit.yield_rate}%, ユーザー率: ${profit.user_rate}%`);
        console.log(`      ベース金額: $${profit.base_amount}, フェーズ: ${profit.phase}`);
        console.log('');
      });
    }
    
    // 5. 全ユーザーの利益履歴を確認
    console.log('\n5. 全ユーザーの利益履歴:');
    const { data: allProfits, error: allProfitError } = await supabase
      .from('user_daily_profit')
      .select('*')
      .order('date', { ascending: false });
    
    if (allProfitError) {
      console.error('❌ 全利益履歴取得エラー:', allProfitError);
    } else {
      console.log(`✅ 全利益記録数: ${allProfits.length}`);
      
      // ユーザー別の利益集計
      const userProfits = {};
      allProfits.forEach(profit => {
        if (!userProfits[profit.user_id]) {
          userProfits[profit.user_id] = 0;
        }
        userProfits[profit.user_id] += profit.daily_profit || 0;
      });
      
      console.log('   ユーザー別利益合計:');
      Object.entries(userProfits).forEach(([userId, totalProfit]) => {
        console.log(`   ${userId}: $${totalProfit.toFixed(2)}`);
      });
    }
    
    // 6. 運用開始済みユーザーの確認
    console.log('\n6. 運用開始済みユーザーの確認:');
    const { data: activeUsers, error: activeUserError } = await supabase
      .from('users')
      .select('user_id, email, full_name, has_approved_nft, is_active, total_purchases')
      .eq('has_approved_nft', true)
      .eq('is_active', true);
    
    if (activeUserError) {
      console.error('❌ 運用開始済みユーザー取得エラー:', activeUserError);
    } else {
      console.log(`✅ 運用開始済みユーザー数: ${activeUsers.length}`);
      activeUsers.forEach((user, index) => {
        console.log(`   ${index + 1}. ${user.user_id}: ${user.email} (投資額: $${user.total_purchases})`);
      });
    }
    
    // 7. affiliate_cycleテーブルの全データを確認
    console.log('\n7. affiliate_cycleテーブルの全データ:');
    const { data: allCycles, error: allCycleError } = await supabase
      .from('affiliate_cycle')
      .select('*')
      .order('user_id');
    
    if (allCycleError) {
      console.error('❌ 全サイクル情報取得エラー:', allCycleError);
    } else {
      console.log(`✅ affiliate_cycleレコード数: ${allCycles.length}`);
      allCycles.forEach((cycle, index) => {
        console.log(`   ${index + 1}. ${cycle.user_id}: NFT=${cycle.total_nft_count}, USDT=${cycle.cum_usdt}, フェーズ=${cycle.phase}`);
      });
    }
    
    // 8. 15日経過条件を満たすユーザーの確認
    console.log('\n8. 15日経過条件を満たすユーザーの確認:');
    const fifteenDaysAgo = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000);
    const { data: eligibleUsers, error: eligibleError } = await supabase
      .from('purchases')
      .select('user_id, purchase_date, admin_approved, nft_quantity, amount_usd')
      .not('admin_approved', 'is', null)
      .lte('admin_approved', fifteenDaysAgo.toISOString());
    
    if (eligibleError) {
      console.error('❌ 15日経過ユーザー取得エラー:', eligibleError);
    } else {
      console.log(`✅ 15日経過ユーザー数: ${eligibleUsers.length}`);
      
      // ユーザー別にグループ化
      const userGroups = {};
      eligibleUsers.forEach(purchase => {
        if (!userGroups[purchase.user_id]) {
          userGroups[purchase.user_id] = [];
        }
        userGroups[purchase.user_id].push(purchase);
      });
      
      Object.entries(userGroups).forEach(([userId, purchases]) => {
        console.log(`   ${userId}: ${purchases.length}件の購入（承認日: ${purchases[0].admin_approved}）`);
        const totalNFT = purchases.reduce((sum, p) => sum + p.nft_quantity, 0);
        const totalAmount = purchases.reduce((sum, p) => sum + p.amount_usd, 0);
        console.log(`      合計NFT: ${totalNFT}, 合計金額: $${totalAmount}`);
      });
    }
    
    // 9. 最新の日利設定を確認
    console.log('\n9. 最新の日利設定:');
    const { data: latestYield, error: yieldError } = await supabase
      .from('daily_yield_log')
      .select('*')
      .order('date', { ascending: false })
      .limit(5);
    
    if (yieldError) {
      console.error('❌ 最新日利設定取得エラー:', yieldError);
    } else {
      console.log(`✅ 最新の日利設定 (最新5件):`);
      latestYield.forEach((yield_, index) => {
        console.log(`   ${index + 1}. 日付: ${yield_.date}`);
        console.log(`      利率: ${yield_.yield_rate}%, マージン: ${yield_.margin_rate}%, ユーザー率: ${yield_.user_rate}%`);
        console.log(`      月末処理: ${yield_.is_month_end}`);
        console.log('');
      });
    }
    
    // 10. 分析結果
    console.log('\n🔍 分析結果:');
    console.log('====================================');
    console.log(`• 利益を受けているユーザー数: ${Object.keys(userProfits || {}).length}`);
    console.log(`• 7A9637の合計利益: $${totalProfit.toFixed(2)}`);
    console.log(`• 運用開始済みユーザー数: ${activeUsers.length}`);
    console.log(`• 15日経過ユーザー数: ${Object.keys(userGroups || {}).length}`);
    console.log(`• affiliate_cycleレコード数: ${allCycles.length}`);
    
  } catch (error) {
    console.error('❌ 調査中にエラーが発生:', error);
  }
}

investigateProfitAnomaly();