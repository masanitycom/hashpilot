const { createClient } = require('@supabase/supabase-js');
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

async function comprehensiveVerification() {
  const userId = '7A9637';
  console.log('🔍 Level4+紹介者数の完全検証を開始します...\n');
  
  // 全ユーザーデータを取得
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, total_purchases, referrer_user_id')
    .gt('total_purchases', 0);

  if (error) {
    console.error('❌ データ取得エラー:', error);
    return;
  }

  console.log(`📊 投資済みユーザー総数: ${allUsers.length}人\n`);

  // 方法1: 現在のダッシュボードロジックと同じ方法
  const method1Result = await method1_DashboardLogic(allUsers, userId);
  
  // 方法2: 完全再帰的な方法（重複チェックあり）
  const method2Result = await method2_RecursiveWithDuplication(allUsers, userId);
  
  // 方法3: SQL的な方法（WITH RECURSIVE模擬）
  const method3Result = await method3_SQLLikeApproach(allUsers, userId);
  
  // 方法4: ユーザー別詳細分析
  const method4Result = await method4_DetailedUserAnalysis(allUsers, userId);

  // 結果比較
  console.log('\n' + '='.repeat(60));
  console.log('🎯 最終検証結果');
  console.log('='.repeat(60));
  
  console.log(`方法1 (ダッシュボードロジック): Level4+ = ${method1Result.level4Plus}人`);
  console.log(`方法2 (再帰+重複チェック):     Level4+ = ${method2Result.level4Plus}人`);
  console.log(`方法3 (SQL的アプローチ):      Level4+ = ${method3Result.level4Plus}人`);
  console.log(`方法4 (詳細ユーザー分析):      Level4+ = ${method4Result.level4Plus}人`);
  
  const results = [method1Result.level4Plus, method2Result.level4Plus, method3Result.level4Plus, method4Result.level4Plus];
  const allMatch = results.every(r => r === results[0]);
  
  if (allMatch) {
    console.log(`\n✅ 全ての方法で一致: ${results[0]}人`);
    console.log('🎉 計算ロジックは正確です');
  } else {
    console.log('\n❌ 計算結果に相違があります！');
    console.log('🚨 本番稼働前に必ず修正が必要です');
    
    // 相違の詳細分析
    await analyzeDifferences(allUsers, userId, method1Result, method2Result, method3Result, method4Result);
  }
}

// 方法1: 現在のダッシュボードロジック
async function method1_DashboardLogic(allUsers, userId) {
  console.log('📝 方法1: ダッシュボードロジックで計算中...');
  
  const level1 = allUsers.filter(u => u.referrer_user_id === userId);
  const level2 = allUsers.filter(u => level1.some(l1 => l1.user_id === u.referrer_user_id));
  const level3 = allUsers.filter(u => level2.some(l2 => l2.user_id === u.referrer_user_id));
  
  const allProcessedIds = new Set([userId, ...level1.map(u => u.user_id), ...level2.map(u => u.user_id), ...level3.map(u => u.user_id)]);
  let currentLevelIds = new Set(level3.map(u => u.user_id));
  const level4Plus = [];
  
  let level = 4;
  while (currentLevelIds.size > 0 && level <= 500) {
    const nextLevel = allUsers.filter(u => 
      currentLevelIds.has(u.referrer_user_id || '') && 
      !allProcessedIds.has(u.user_id)
    );
    if (nextLevel.length === 0) break;
    
    level4Plus.push(...nextLevel);
    const newIds = new Set(nextLevel.map(u => u.user_id));
    newIds.forEach(id => allProcessedIds.add(id));
    currentLevelIds = newIds;
    level++;
  }
  
  console.log(`   Level 1: ${level1.length}人`);
  console.log(`   Level 2: ${level2.length}人`);
  console.log(`   Level 3: ${level3.length}人`);
  console.log(`   Level 4+: ${level4Plus.length}人 (最大深度: ${level-1})`);
  
  return { level1: level1.length, level2: level2.length, level3: level3.length, level4Plus: level4Plus.length, maxLevel: level-1 };
}

// 方法2: 完全再帰的な方法（重複チェックあり）
async function method2_RecursiveWithDuplication(allUsers, userId) {
  console.log('📝 方法2: 再帰+重複チェックで計算中...');
  
  const processed = new Set();
  const levelCounts = { 1: 0, 2: 0, 3: 0, '4+': 0 };
  
  function processLevel(parentIds, currentLevel) {
    const children = [];
    
    for (const parentId of parentIds) {
      const directChildren = allUsers.filter(u => 
        u.referrer_user_id === parentId && !processed.has(u.user_id)
      );
      
      for (const child of directChildren) {
        processed.add(child.user_id);
        children.push(child.user_id);
        
        if (currentLevel <= 3) {
          levelCounts[currentLevel]++;
        } else {
          levelCounts['4+']++;
        }
      }
    }
    
    if (children.length > 0 && currentLevel < 500) {
      processLevel(children, currentLevel + 1);
    }
  }
  
  processLevel([userId], 1);
  
  console.log(`   Level 1: ${levelCounts[1]}人`);
  console.log(`   Level 2: ${levelCounts[2]}人`);
  console.log(`   Level 3: ${levelCounts[3]}人`);
  console.log(`   Level 4+: ${levelCounts['4+']}人`);
  
  return { level1: levelCounts[1], level2: levelCounts[2], level3: levelCounts[3], level4Plus: levelCounts['4+'] };
}

// 方法3: SQL的なアプローチ
async function method3_SQLLikeApproach(allUsers, userId) {
  console.log('📝 方法3: SQL的アプローチで計算中...');
  
  // ユーザーマップ作成
  const userMap = new Map();
  allUsers.forEach(user => {
    userMap.set(user.user_id, user);
  });
  
  // 各ユーザーのレベルを計算
  const userLevels = new Map();
  
  function getUserLevel(targetUserId) {
    if (userLevels.has(targetUserId)) {
      return userLevels.get(targetUserId);
    }
    
    const user = userMap.get(targetUserId);
    if (!user || !user.referrer_user_id) {
      userLevels.set(targetUserId, 0);
      return 0;
    }
    
    if (user.referrer_user_id === userId) {
      userLevels.set(targetUserId, 1);
      return 1;
    }
    
    const parentLevel = getUserLevel(user.referrer_user_id);
    const currentLevel = parentLevel > 0 ? parentLevel + 1 : 0;
    userLevels.set(targetUserId, currentLevel);
    return currentLevel;
  }
  
  // 全ユーザーのレベルを計算
  const levelCounts = { 1: 0, 2: 0, 3: 0, '4+': 0 };
  
  for (const user of allUsers) {
    if (user.user_id === userId) continue;
    
    const level = getUserLevel(user.user_id);
    if (level === 1) levelCounts[1]++;
    else if (level === 2) levelCounts[2]++;
    else if (level === 3) levelCounts[3]++;
    else if (level >= 4) levelCounts['4+']++;
  }
  
  console.log(`   Level 1: ${levelCounts[1]}人`);
  console.log(`   Level 2: ${levelCounts[2]}人`);
  console.log(`   Level 3: ${levelCounts[3]}人`);
  console.log(`   Level 4+: ${levelCounts['4+']}人`);
  
  return { level1: levelCounts[1], level2: levelCounts[2], level3: levelCounts[3], level4Plus: levelCounts['4+'] };
}

// 方法4: 詳細ユーザー分析
async function method4_DetailedUserAnalysis(allUsers, userId) {
  console.log('📝 方法4: 詳細ユーザー分析で計算中...');
  
  // 全ユーザーの紹介経路を追跡
  const userPaths = new Map();
  
  function tracePath(targetUserId, path = []) {
    const user = allUsers.find(u => u.user_id === targetUserId);
    if (!user || !user.referrer_user_id) return null;
    
    const newPath = [targetUserId, ...path];
    
    if (user.referrer_user_id === userId) {
      return newPath;
    }
    
    // 循環参照チェック
    if (newPath.includes(user.referrer_user_id)) {
      console.warn(`⚠️ 循環参照検出: ${user.referrer_user_id} -> ${targetUserId}`);
      return null;
    }
    
    return tracePath(user.referrer_user_id, newPath);
  }
  
  const levelCounts = { 1: 0, 2: 0, 3: 0, '4+': 0 };
  const level4PlusUsers = [];
  
  for (const user of allUsers) {
    if (user.user_id === userId) continue;
    
    const path = tracePath(user.user_id);
    if (path) {
      const level = path.length;
      if (level === 1) levelCounts[1]++;
      else if (level === 2) levelCounts[2]++;
      else if (level === 3) levelCounts[3]++;
      else if (level >= 4) {
        levelCounts['4+']++;
        level4PlusUsers.push({ userId: user.user_id, level, path });
      }
      
      userPaths.set(user.user_id, { level, path });
    }
  }
  
  console.log(`   Level 1: ${levelCounts[1]}人`);
  console.log(`   Level 2: ${levelCounts[2]}人`);
  console.log(`   Level 3: ${levelCounts[3]}人`);
  console.log(`   Level 4+: ${levelCounts['4+']}人`);
  
  // Level 4+ユーザーの詳細
  console.log(`\n   Level 4+ユーザーの内訳:`);
  const levelBreakdown = {};
  level4PlusUsers.forEach(u => {
    levelBreakdown[u.level] = (levelBreakdown[u.level] || 0) + 1;
  });
  
  Object.keys(levelBreakdown).sort((a, b) => a - b).forEach(level => {
    console.log(`     Level ${level}: ${levelBreakdown[level]}人`);
  });
  
  return { level1: levelCounts[1], level2: levelCounts[2], level3: levelCounts[3], level4Plus: levelCounts['4+'], level4PlusUsers };
}

// 相違分析
async function analyzeDifferences(allUsers, userId, m1, m2, m3, m4) {
  console.log('\n🔍 相違分析を開始...');
  
  // どの方法が異なるかを特定
  const results = [
    { name: '方法1', result: m1 },
    { name: '方法2', result: m2 },
    { name: '方法3', result: m3 },
    { name: '方法4', result: m4 }
  ];
  
  console.log('\n詳細比較:');
  results.forEach(r => {
    console.log(`${r.name}: L1=${r.result.level1}, L2=${r.result.level2}, L3=${r.result.level3}, L4+=${r.result.level4Plus}`);
  });
  
  // 潜在的な問題を特定
  console.log('\n🚨 潜在的な問題:');
  
  // 循環参照チェック
  const circularRefs = [];
  for (const user of allUsers) {
    const visited = new Set();
    let current = user.user_id;
    
    while (current) {
      if (visited.has(current)) {
        circularRefs.push(current);
        break;
      }
      visited.add(current);
      const parent = allUsers.find(u => u.user_id === current);
      current = parent?.referrer_user_id;
    }
  }
  
  if (circularRefs.length > 0) {
    console.log(`   循環参照: ${circularRefs.length}件`);
  } else {
    console.log('   循環参照: なし ✅');
  }
  
  // 孤児ノードチェック
  const referrerIds = new Set(allUsers.map(u => u.referrer_user_id).filter(Boolean));
  const userIds = new Set(allUsers.map(u => u.user_id));
  const orphanReferrers = [...referrerIds].filter(id => !userIds.has(id) && id !== userId);
  
  if (orphanReferrers.length > 0) {
    console.log(`   存在しない紹介者: ${orphanReferrers.length}件`);
  } else {
    console.log('   存在しない紹介者: なし ✅');
  }
}

comprehensiveVerification().catch(console.error);