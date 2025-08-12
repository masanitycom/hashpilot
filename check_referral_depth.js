const { createClient } = require('@supabase/supabase-js');
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

async function checkReferralDepth() {
  const userId = '7A9637';
  
  const { data: allUsers } = await supabase
    .from('users')
    .select('user_id, total_purchases, referrer_user_id')
    .gt('total_purchases', 0);

  console.log('Total users with purchases:', allUsers.length);

  // 実際の最大深度を確認
  let maxDepth = 0;
  let currentLevelUsers = [userId];
  let level = 0;
  let totalCount = 0;
  let level4PlusCount = 0;

  while (currentLevelUsers.length > 0) {
    level++;
    const nextLevelUsers = [];
    
    for (const parentId of currentLevelUsers) {
      const children = allUsers.filter(u => u.referrer_user_id === parentId);
      nextLevelUsers.push(...children.map(c => c.user_id));
    }
    
    if (nextLevelUsers.length > 0) {
      console.log(`Level ${level}: ${nextLevelUsers.length} users`);
      totalCount += nextLevelUsers.length;
      if (level >= 4) {
        level4PlusCount += nextLevelUsers.length;
      }
      maxDepth = level;
      currentLevelUsers = nextLevelUsers;
    } else {
      break;
    }
    
    // 安全装置
    if (level > 1000) {
      console.log('⚠️ 1000レベルに達したため停止');
      break;
    }
  }
  
  console.log('\n📊 結果:');
  console.log('最大深度:', maxDepth, 'レベル');
  console.log('Level 1-3:', totalCount - level4PlusCount);
  console.log('Level 4以降:', level4PlusCount);
  console.log('全ユーザー合計:', totalCount);
  
  if (maxDepth > 100) {
    console.log('\n🚨 100レベルを超えています！制限を調整する必要があります');
  } else {
    console.log('\n✅ 100レベル制限は十分です');
  }
  
  // 160人になる理由を探る
  console.log('\n🔍 160人との差分を調査:');
  console.log('現在のLevel4以降:', level4PlusCount);
  console.log('オリジナル（推定）:', '160');
  console.log('差分:', 160 - level4PlusCount);
  
  // 重複チェックなしでの計算も実行
  await checkWithoutDuplicateChecking(allUsers, userId);
}

// オリジナル版のような重複チェックなしの計算
async function checkWithoutDuplicateChecking(allUsers, userId) {
  console.log('\n🔄 重複チェックなし版（オリジナルを模擬）:');
  
  let totalCountWithDuplicates = 0;
  
  // 再帰的にカウント（重複チェックなし）
  async function countRecursive(currentUserId, level) {
    const children = allUsers.filter(u => u.referrer_user_id === currentUserId);
    
    if (children.length > 0) {
      totalCountWithDuplicates += children.length;
      
      for (const child of children) {
        await countRecursive(child.user_id, level + 1);
      }
    }
  }
  
  await countRecursive(userId, 1);
  
  console.log('重複チェックなし合計:', totalCountWithDuplicates);
  console.log('これでも160に届かない場合、他の要因があります');
}

checkReferralDepth().catch(console.error);