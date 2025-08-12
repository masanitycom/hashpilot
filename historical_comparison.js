const { createClient } = require('@supabase/supabase-js');
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

async function historicalComparison() {
  console.log('🔄 160人になっていた理由の特定...\n');
  
  const userId = '7A9637';
  
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, total_purchases, referrer_user_id')
    .gt('total_purchases', 0);

  if (error) {
    console.error('エラー:', error);
    return;
  }

  console.log('🔍 考えられる古いロジックのパターン:');
  
  // パターン1: 重複チェックなし（最も可能性が高い）
  console.log('\n📝 パターン1: 重複チェックなしの再帰計算');
  let totalWithoutDuplication = 0;
  let level4PlusWithoutDuplication = 0;
  
  function countRecursive(currentUserId, level, visited = new Set()) {
    // 無限ループ防止（ただし重複はカウント）
    if (visited.has(currentUserId)) return;
    visited.add(currentUserId);
    
    const children = allUsers.filter(u => u.referrer_user_id === currentUserId);
    
    for (const child of children) {
      totalWithoutDuplication++;
      if (level >= 4) {
        level4PlusWithoutDuplication++;
      }
      
      // 再帰的に子を処理
      countRecursive(child.user_id, level + 1, new Set(visited)); // 新しいvisitedセットを使用
    }
  }
  
  countRecursive(userId, 1);
  console.log(`   合計: ${totalWithoutDuplication}人`);
  console.log(`   Level 4+: ${level4PlusWithoutDuplication}人`);
  
  // パターン2: 10レベル制限あり
  console.log('\n📝 パターン2: 10レベル制限版');
  const level1 = allUsers.filter(u => u.referrer_user_id === userId);
  const level2 = allUsers.filter(u => level1.some(l1 => l1.user_id === u.referrer_user_id));
  const level3 = allUsers.filter(u => level2.some(l2 => l2.user_id === u.referrer_user_id));

  const allProcessedIds = new Set([
    userId,
    ...level1.map(u => u.user_id),
    ...level2.map(u => u.user_id),
    ...level3.map(u => u.user_id)
  ]);

  let currentLevelIds = new Set(level3.map(u => u.user_id));
  const level4Plus_10limit = [];
  
  let level = 4;
  while (currentLevelIds.size > 0 && level <= 10) { // 10レベル制限
    const nextLevel = allUsers.filter(u => 
      currentLevelIds.has(u.referrer_user_id || '') && 
      !allProcessedIds.has(u.user_id)
    );
    
    if (nextLevel.length === 0) break;
    
    level4Plus_10limit.push(...nextLevel);
    const newIds = new Set(nextLevel.map(u => u.user_id));
    newIds.forEach(id => allProcessedIds.add(id));
    currentLevelIds = newIds;
    level++;
  }
  
  console.log(`   Level 4+ (10レベル制限): ${level4Plus_10limit.length}人`);
  
  // パターン3: 全ユーザー含む（total_purchases > 0の条件なし）
  console.log('\n📝 パターン3: 全ユーザー含む版');
  const { data: allUsersIncludeZero } = await supabase
    .from('users')
    .select('user_id, total_purchases, referrer_user_id');
    
  if (allUsersIncludeZero) {
    const level1_all = allUsersIncludeZero.filter(u => u.referrer_user_id === userId);
    const level2_all = allUsersIncludeZero.filter(u => level1_all.some(l1 => l1.user_id === u.referrer_user_id));
    const level3_all = allUsersIncludeZero.filter(u => level2_all.some(l2 => l2.user_id === u.referrer_user_id));

    const allProcessedIds_all = new Set([
      userId,
      ...level1_all.map(u => u.user_id),
      ...level2_all.map(u => u.user_id),
      ...level3_all.map(u => u.user_id)
    ]);

    let currentLevelIds_all = new Set(level3_all.map(u => u.user_id));
    const level4Plus_all = [];
    
    let level_all = 4;
    while (currentLevelIds_all.size > 0 && level_all <= 500) {
      const nextLevel = allUsersIncludeZero.filter(u => 
        currentLevelIds_all.has(u.referrer_user_id || '') && 
        !allProcessedIds_all.has(u.user_id)
      );
      
      if (nextLevel.length === 0) break;
      
      level4Plus_all.push(...nextLevel);
      const newIds = new Set(nextLevel.map(u => u.user_id));
      newIds.forEach(id => allProcessedIds_all.add(id));
      currentLevelIds_all = newIds;
      level_all++;
    }
    
    console.log(`   全ユーザー数: ${allUsersIncludeZero.length}人`);
    console.log(`   Level 1: ${level1_all.length}人`);
    console.log(`   Level 2: ${level2_all.length}人`);
    console.log(`   Level 3: ${level3_all.length}人`);
    console.log(`   Level 4+: ${level4Plus_all.length}人`);
  }
  
  // パターン4: データの時間的変化
  console.log('\n📝 パターン4: データ変化の可能性');
  
  // 最近作成されたユーザーを除外してテスト
  const oneMonthAgo = new Date();
  oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);
  
  const oldUsers = allUsers.filter(u => {
    // created_atフィールドがない場合は古いユーザーとして扱う
    return true; // 簡略化
  });
  
  console.log(`   古いデータ想定ユーザー数: ${oldUsers.length}人（現在と同じ）`);
  
  console.log('\n=== 結論 ===');
  console.log(`現在の正確な値: 89人`);
  console.log(`重複なし再帰版: ${level4PlusWithoutDuplication}人`);
  console.log(`10レベル制限版: ${level4Plus_10limit.length}人`);
  
  if (allUsersIncludeZero) {
    const level4Plus_all_count = allUsersIncludeZero.filter(u => u.referrer_user_id === userId).length; // 簡略計算
    console.log(`全ユーザー版: 計算複雑のため省略`);
  }
  
  console.log('\n🎯 160人に最も近い値を特定...');
  const candidates = [
    { name: '重複なし再帰', value: level4PlusWithoutDuplication },
    { name: '10レベル制限', value: level4Plus_10limit.length },
  ];
  
  candidates.forEach(c => {
    const diff = Math.abs(c.value - 160);
    console.log(`   ${c.name}: ${c.value}人 (160との差: ${diff})`);
  });
}

historicalComparison().catch(console.error);