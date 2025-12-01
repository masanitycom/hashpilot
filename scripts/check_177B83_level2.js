const { createClient } = require('@supabase/supabase-js');

// Load environment variables
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://soghqozaxfswtxxbgeer.supabase.co';
const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function checkLevel2Detail() {
  console.log('========================================');
  console.log('177B83のLevel 2紹介報酬の詳細確認');
  console.log('========================================\n');

  // 1. Level 2紹介報酬の概要
  console.log('=== 1. 177B83のLevel 2紹介報酬の概要（11月） ===');
  const { data: overview, error: error1 } = await supabase
    .from('user_referral_profit')
    .select('referral_level, profit_amount, child_user_id, date')
    .eq('user_id', '177B83')
    .gte('date', '2025-11-01')
    .lte('date', '2025-11-30');

  if (error1) {
    console.error('Error:', error1);
    return;
  }

  const byLevel = {};
  overview.forEach(row => {
    if (!byLevel[row.referral_level]) {
      byLevel[row.referral_level] = {
        record_count: 0,
        unique_children: new Set(),
        unique_dates: new Set(),
        total_profit: 0,
        profits: []
      };
    }
    byLevel[row.referral_level].record_count++;
    byLevel[row.referral_level].unique_children.add(row.child_user_id);
    byLevel[row.referral_level].unique_dates.add(row.date);
    byLevel[row.referral_level].total_profit += parseFloat(row.profit_amount);
    byLevel[row.referral_level].profits.push(parseFloat(row.profit_amount));
  });

  Object.keys(byLevel).sort().forEach(level => {
    const stats = byLevel[level];
    const avg = stats.total_profit / stats.record_count;
    const min = Math.min(...stats.profits);
    const max = Math.max(...stats.profits);
    console.log(`Level ${level}:`);
    console.log(`  レコード数: ${stats.record_count}`);
    console.log(`  ユニーク子ユーザー数: ${stats.unique_children.size}`);
    console.log(`  ユニーク日数: ${stats.unique_dates.size}`);
    console.log(`  合計金額: $${stats.total_profit.toFixed(3)}`);
    console.log(`  平均: $${avg.toFixed(3)}`);
    console.log(`  最小: $${min.toFixed(3)}`);
    console.log(`  最大: $${max.toFixed(3)}`);
    console.log('');
  });

  // 2. Level 2の子ユーザー一覧
  console.log('=== 2. Level 2の子ユーザー一覧（上位20名） ===');
  const level2Data = overview.filter(r => r.referral_level === 2);
  const byChild = {};
  level2Data.forEach(row => {
    if (!byChild[row.child_user_id]) {
      byChild[row.child_user_id] = {
        record_count: 0,
        total_profit: 0,
        dates: []
      };
    }
    byChild[row.child_user_id].record_count++;
    byChild[row.child_user_id].total_profit += parseFloat(row.profit_amount);
    byChild[row.child_user_id].dates.push(row.date);
  });

  const childArray = Object.entries(byChild).map(([child_user_id, stats]) => ({
    child_user_id,
    record_count: stats.record_count,
    total_profit: stats.total_profit,
    first_date: stats.dates.sort()[0],
    last_date: stats.dates.sort()[stats.dates.length - 1]
  })).sort((a, b) => b.total_profit - a.total_profit).slice(0, 20);

  childArray.forEach(child => {
    console.log(`${child.child_user_id}: レコード${child.record_count}件, $${child.total_profit.toFixed(3)}, ${child.first_date} 〜 ${child.last_date}`);
  });
  console.log('');

  // 3. 11/26のLevel 2紹介報酬詳細
  console.log('=== 3. 11/26のLevel 2紹介報酬詳細 ===');
  const { data: nov26Level2, error: error3 } = await supabase
    .from('user_referral_profit')
    .select('child_user_id, profit_amount')
    .eq('user_id', '177B83')
    .eq('referral_level', 2)
    .eq('date', '2025-11-26');

  if (error3) {
    console.error('Error:', error3);
    return;
  }

  for (const row of nov26Level2) {
    // Get child's daily profit
    const { data: childProfit } = await supabase
      .from('user_daily_profit')
      .select('daily_profit')
      .eq('user_id', row.child_user_id)
      .eq('date', '2025-11-26')
      .single();

    // Get child's email and NFT count
    const { data: childUser } = await supabase
      .from('users')
      .select('email')
      .eq('user_id', row.child_user_id)
      .single();

    const { data: childNFTs } = await supabase
      .from('nft_master')
      .select('id')
      .eq('user_id', row.child_user_id)
      .is('buyback_date', null);

    const dailyProfit = childProfit ? parseFloat(childProfit.daily_profit) : 0;
    const expected = dailyProfit * 0.10;
    const difference = parseFloat(row.profit_amount) - expected;

    console.log(`${row.child_user_id} (${childUser?.email}):`);
    console.log(`  記録された報酬: $${parseFloat(row.profit_amount).toFixed(3)}`);
    console.log(`  子の日利: $${dailyProfit.toFixed(3)}`);
    console.log(`  期待値(10%): $${expected.toFixed(3)}`);
    console.log(`  差額: $${difference.toFixed(3)}`);
    console.log(`  NFT数: ${childNFTs?.length || 0}`);
    console.log('');
  }

  // 4. 紹介ツリーの確認
  console.log('=== 4. 177B83の紹介ツリー ===');

  // Level 1
  const { data: level1Users } = await supabase
    .from('users')
    .select('user_id, email, operation_start_date')
    .eq('referrer_user_id', '177B83');

  console.log(`Level 1（直接紹介）: ${level1Users?.length || 0}名`);

  // Level 2
  if (level1Users && level1Users.length > 0) {
    const level1Ids = level1Users.map(u => u.user_id);
    const { data: level2Users } = await supabase
      .from('users')
      .select('user_id, email, referrer_user_id, operation_start_date')
      .in('referrer_user_id', level1Ids);

    console.log(`Level 2（間接紹介）: ${level2Users?.length || 0}名`);

    if (level2Users && level2Users.length > 0) {
      for (const l2 of level2Users.slice(0, 10)) {
        const { data: nfts } = await supabase
          .from('nft_master')
          .select('id')
          .eq('user_id', l2.user_id)
          .is('buyback_date', null);

        const level1User = level1Users.find(u => u.user_id === l2.referrer_user_id);

        console.log(`  ${l2.user_id} → ${l2.referrer_user_id} (${level1User?.email}), NFT: ${nfts?.length || 0}個, 運用開始: ${l2.operation_start_date || 'NULL'}`);
      }
      if (level2Users.length > 10) {
        console.log(`  ... and ${level2Users.length - 10} more`);
      }
    }
  }
  console.log('');

  // 6. 日別のLevel 2レコード数
  console.log('=== 6. 日別のLevel 2レコード数 ===');
  const byDate = {};
  level2Data.forEach(row => {
    if (!byDate[row.date]) {
      byDate[row.date] = {
        record_count: 0,
        unique_children: new Set(),
        total_profit: 0
      };
    }
    byDate[row.date].record_count++;
    byDate[row.date].unique_children.add(row.child_user_id);
    byDate[row.date].total_profit += parseFloat(row.profit_amount);
  });

  const dateArray = Object.entries(byDate).map(([date, stats]) => ({
    date,
    record_count: stats.record_count,
    unique_children: stats.unique_children.size,
    total_profit: stats.total_profit,
    records_per_child: stats.record_count / stats.unique_children.size
  })).sort((a, b) => b.date.localeCompare(a.date)).slice(0, 10);

  dateArray.forEach(d => {
    console.log(`${d.date}: ${d.record_count}件, ${d.unique_children}名, $${d.total_profit.toFixed(3)}, 1人あたり${d.records_per_child.toFixed(1)}件`);
  });
  console.log('');

  // サマリー
  console.log('===========================================');
  console.log('📊 177B83のLevel 2紹介報酬分析');
  console.log('===========================================');

  const level2Stats = byLevel[2];
  if (level2Stats) {
    console.log('Level 2紹介報酬:');
    console.log(`  レコード数: ${level2Stats.record_count}`);
    console.log(`  ユニーク子ユーザー数: ${level2Stats.unique_children.size}`);
    console.log(`  合計金額: $${level2Stats.total_profit.toFixed(3)}`);
    console.log('');

    // Calculate expected total
    const level2UserIds = Array.from(level2Stats.unique_children);
    const { data: level2DailyProfits } = await supabase
      .from('user_daily_profit')
      .select('daily_profit')
      .in('user_id', level2UserIds)
      .gte('date', '2025-11-01')
      .lte('date', '2025-11-30');

    const expectedTotal = level2DailyProfits?.reduce((sum, row) => sum + parseFloat(row.daily_profit) * 0.10, 0) || 0;

    console.log(`期待値: $${expectedTotal.toFixed(3)}`);
    console.log(`実際: $${level2Stats.total_profit.toFixed(3)}`);
    console.log(`差額: $${(level2Stats.total_profit - expectedTotal).toFixed(3)}`);
    console.log('');

    const recordsPerChild = level2Stats.record_count / level2Stats.unique_children.size;
    console.log(`1人あたりのレコード数: ${recordsPerChild.toFixed(1)}`);
    if (recordsPerChild > 30) {
      console.log('🚨 異常: 1人あたり30レコード以上（重複の可能性）');
    }
  }
  console.log('===========================================');
}

checkLevel2Detail().catch(console.error);
