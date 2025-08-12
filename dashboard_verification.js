const { createClient } = require('@supabase/supabase-js');
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

async function verifyDashboardCalculation() {
  console.log('🎯 実際のダッシュボードロジックで検証中...\n');
  
  const userId = '7A9637';
  
  // ダッシュボードと全く同じクエリとロジック
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, total_purchases, referrer_user_id')
    .gt('total_purchases', 0);

  if (error) {
    console.error('エラー:', error);
    return;
  }

  console.log(`総投資済みユーザー数: ${allUsers.length}人`);
  
  // ダッシュボードのロジックを完全再現
  const level1 = allUsers.filter(u => u.referrer_user_id === userId);
  const level2 = allUsers.filter(u => level1.some(l1 => l1.user_id === u.referrer_user_id));
  const level3 = allUsers.filter(u => level2.some(l2 => l2.user_id === u.referrer_user_id));

  // Level 4以降の計算（ダッシュボードと同じロジック）
  const allProcessedIds = new Set([
    userId,
    ...level1.map(u => u.user_id),
    ...level2.map(u => u.user_id),
    ...level3.map(u => u.user_id)
  ]);

  let currentLevelIds = new Set(level3.map(u => u.user_id));
  const level4Plus = [];
  
  let level = 4;
  let iterations = 0;
  
  console.log('\nLevel計算詳細:');
  console.log(`Level 1: ${level1.length}人`);
  console.log(`Level 2: ${level2.length}人`);  
  console.log(`Level 3: ${level3.length}人`);
  
  while (currentLevelIds.size > 0 && level <= 500) {
    iterations++;
    const nextLevel = allUsers.filter(u => 
      currentLevelIds.has(u.referrer_user_id || '') && 
      !allProcessedIds.has(u.user_id)
    );
    
    if (nextLevel.length === 0) break;
    
    console.log(`Level ${level}: ${nextLevel.length}人`);
    level4Plus.push(...nextLevel);
    
    const newIds = new Set(nextLevel.map(u => u.user_id));
    newIds.forEach(id => allProcessedIds.add(id));
    currentLevelIds = newIds;
    level++;
    
    // 安全装置
    if (iterations > 100) {
      console.log('⚠️ 100回反復に達したため停止');
      break;
    }
  }
  
  const totalAll = level1.length + level2.length + level3.length + level4Plus.length;
  
  console.log('\n=== 最終結果 ===');
  console.log(`Level 1: ${level1.length}人`);
  console.log(`Level 2: ${level2.length}人`);
  console.log(`Level 3: ${level3.length}人`);
  console.log(`Level 4+: ${level4Plus.length}人`);
  console.log(`合計: ${totalAll}人`);
  console.log(`最大レベル: ${level-1}`);
  console.log(`反復回数: ${iterations}`);
  
  // 投資額計算（ダッシュボードと同じ）
  const calculateInvestment = (users) => 
    users.reduce((sum, u) => sum + Math.floor((u.total_purchases || 0) / 1100) * 1000, 0);
  
  const level1Investment = calculateInvestment(level1);
  const level2Investment = calculateInvestment(level2);
  const level3Investment = calculateInvestment(level3);
  const level4PlusInvestment = calculateInvestment(level4Plus);
  
  console.log('\n=== 投資額計算 ===');
  console.log(`Level 1投資額: $${level1Investment.toLocaleString()}`);
  console.log(`Level 2投資額: $${level2Investment.toLocaleString()}`);
  console.log(`Level 3投資額: $${level3Investment.toLocaleString()}`);
  console.log(`Level 4+投資額: $${level4PlusInvestment.toLocaleString()}`);
  
  // 利益計算
  const level1Profit = level1Investment * 0.2;
  const level2Profit = level2Investment * 0.1;
  const level3Profit = level3Investment * 0.05;
  const level4PlusProfit = level4PlusInvestment * 0; // Level4+は0%
  
  console.log('\n=== 利益計算 ===');
  console.log(`Level 1利益 (20%): $${level1Profit.toLocaleString()}`);
  console.log(`Level 2利益 (10%): $${level2Profit.toLocaleString()}`);
  console.log(`Level 3利益 (5%): $${level3Profit.toLocaleString()}`);
  console.log(`Level 4+利益 (0%): $${level4PlusProfit.toLocaleString()}`);
  console.log(`合計利益: $${(level1Profit + level2Profit + level3Profit + level4PlusProfit).toLocaleString()}`);
  
  return {
    level1: level1.length,
    level2: level2.length, 
    level3: level3.length,
    level4Plus: level4Plus.length,
    maxLevel: level-1,
    totalInvestment: level1Investment + level2Investment + level3Investment + level4PlusInvestment,
    totalProfit: level1Profit + level2Profit + level3Profit + level4PlusProfit
  };
}

verifyDashboardCalculation().catch(console.error);