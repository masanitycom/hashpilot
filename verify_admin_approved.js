const { createClient } = require('@supabase/supabase-js');
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

async function verifyAdminApproved() {
  console.log('🔍 管理者承認ステータスの検証を開始...\n');
  
  const userId = '7A9637';
  
  // 1. nft_purchasesテーブルから承認済み購入を確認
  console.log('📋 nft_purchasesテーブルの確認:');
  const { data: purchases, error: purchasesError } = await supabase
    .from('nft_purchases')
    .select('user_id, amount_usd, nft_quantity, admin_approved, payment_status')
    .order('created_at', { ascending: false });
  
  if (purchasesError) {
    console.log('   nft_purchasesテーブルへのアクセスエラー:', purchasesError.message);
  } else if (purchases) {
    const approvedPurchases = purchases.filter(p => p.admin_approved === true);
    const pendingPurchases = purchases.filter(p => p.admin_approved === false || p.admin_approved === null);
    
    console.log(`   全購入数: ${purchases.length}件`);
    console.log(`   承認済み: ${approvedPurchases.length}件`);
    console.log(`   未承認/保留中: ${pendingPurchases.length}件`);
    
    // ユニークユーザー数
    const approvedUserIds = new Set(approvedPurchases.map(p => p.user_id));
    const allPurchaseUserIds = new Set(purchases.map(p => p.user_id));
    
    console.log(`   承認済みユニークユーザー数: ${approvedUserIds.size}人`);
    console.log(`   全購入ユニークユーザー数: ${allPurchaseUserIds.size}人`);
  }
  
  // 2. usersテーブルのtotal_purchasesフィールドを確認
  console.log('\n📋 usersテーブルの確認:');
  const { data: allUsers, error: usersError } = await supabase
    .from('users')
    .select('user_id, total_purchases, referrer_user_id')
    .gt('total_purchases', 0);
  
  if (usersError) {
    console.log('   エラー:', usersError.message);
    return;
  }
  
  console.log(`   total_purchases > 0のユーザー数: ${allUsers.length}人`);
  
  // 3. total_purchasesとadmin_approvedの関係を確認
  console.log('\n🔄 total_purchasesとadmin_approvedの相関確認:');
  
  if (purchases && allUsers) {
    // total_purchases > 0だが承認済み購入がないユーザーを探す
    const usersWithoutApprovedPurchases = [];
    
    for (const user of allUsers) {
      const userPurchases = purchases.filter(p => p.user_id === user.user_id);
      const approvedPurchases = userPurchases.filter(p => p.admin_approved === true);
      
      if (approvedPurchases.length === 0) {
        usersWithoutApprovedPurchases.push({
          user_id: user.user_id,
          total_purchases: user.total_purchases,
          purchase_count: userPurchases.length,
          approved_count: 0
        });
      }
    }
    
    if (usersWithoutApprovedPurchases.length > 0) {
      console.log(`   ⚠️ total_purchases > 0だが承認済み購入がないユーザー: ${usersWithoutApprovedPurchases.length}人`);
      console.log('   最初の5件:');
      usersWithoutApprovedPurchases.slice(0, 5).forEach(u => {
        console.log(`     - ${u.user_id}: total_purchases=$${u.total_purchases}, 購入記録=${u.purchase_count}件（承認済み0件）`);
      });
    } else {
      console.log('   ✅ 全てのtotal_purchases > 0のユーザーに承認済み購入があります');
    }
  }
  
  // 4. 特定ユーザー（7A9637）の紹介ツリーでの検証
  console.log('\n🎯 ユーザー7A9637の紹介ツリー分析:');
  
  // Level 1-3の計算
  const level1 = allUsers.filter(u => u.referrer_user_id === userId);
  const level2 = allUsers.filter(u => level1.some(l1 => l1.user_id === u.referrer_user_id));
  const level3 = allUsers.filter(u => level2.some(l2 => l2.user_id === u.referrer_user_id));
  
  // Level 4+の計算
  const allProcessedIds = new Set([
    userId,
    ...level1.map(u => u.user_id),
    ...level2.map(u => u.user_id),
    ...level3.map(u => u.user_id)
  ]);
  
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
  console.log(`   Level 4+: ${level4Plus.length}人`);
  
  // 5. 管理者承認のみでフィルターした場合の計算
  if (purchases) {
    console.log('\n📊 管理者承認済みのみでの再計算:');
    
    // 承認済み購入があるユーザーIDのセット
    const approvedUserIds = new Set(
      purchases
        .filter(p => p.admin_approved === true)
        .map(p => p.user_id)
    );
    
    // 承認済みユーザーのみでフィルター
    const approvedUsers = allUsers.filter(u => approvedUserIds.has(u.user_id));
    
    console.log(`   承認済みユーザー数: ${approvedUsers.length}人`);
    
    // 承認済みユーザーのみでLevel 4+を再計算
    const level1Approved = approvedUsers.filter(u => u.referrer_user_id === userId);
    const level2Approved = approvedUsers.filter(u => level1Approved.some(l1 => l1.user_id === u.referrer_user_id));
    const level3Approved = approvedUsers.filter(u => level2Approved.some(l2 => l2.user_id === u.referrer_user_id));
    
    const allProcessedIdsApproved = new Set([
      userId,
      ...level1Approved.map(u => u.user_id),
      ...level2Approved.map(u => u.user_id),
      ...level3Approved.map(u => u.user_id)
    ]);
    
    let currentLevelIdsApproved = new Set(level3Approved.map(u => u.user_id));
    const level4PlusApproved = [];
    let levelApproved = 4;
    
    while (currentLevelIdsApproved.size > 0 && levelApproved <= 500) {
      const nextLevel = approvedUsers.filter(u => 
        currentLevelIdsApproved.has(u.referrer_user_id || '') && 
        !allProcessedIdsApproved.has(u.user_id)
      );
      
      if (nextLevel.length === 0) break;
      
      level4PlusApproved.push(...nextLevel);
      const newIds = new Set(nextLevel.map(u => u.user_id));
      newIds.forEach(id => allProcessedIdsApproved.add(id));
      currentLevelIdsApproved = newIds;
      levelApproved++;
    }
    
    console.log(`   Level 1（承認済みのみ）: ${level1Approved.length}人`);
    console.log(`   Level 2（承認済みのみ）: ${level2Approved.length}人`);
    console.log(`   Level 3（承認済みのみ）: ${level3Approved.length}人`);
    console.log(`   Level 4+（承認済みのみ）: ${level4PlusApproved.length}人`);
    
    if (level4PlusApproved.length !== level4Plus.length) {
      console.log(`\n   ⚠️ 差異検出: 承認済みのみ=${level4PlusApproved.length}人 vs total_purchases>0=${level4Plus.length}人`);
      console.log(`   差分: ${level4Plus.length - level4PlusApproved.length}人`);
    } else {
      console.log('\n   ✅ 両方の計算結果が一致しています');
    }
  }
  
  // 6. 最終結論
  console.log('\n' + '='.repeat(60));
  console.log('📌 結論:');
  console.log('='.repeat(60));
  
  console.log('現在のダッシュボードは:');
  console.log('  - usersテーブルのtotal_purchases > 0でフィルター');
  console.log('  - nft_purchasesのadmin_approvedは直接チェックしていない');
  console.log('  - total_purchasesは管理者が承認時に更新される想定');
  console.log('\n重要: total_purchasesが正しく管理者承認と同期していれば問題なし');
}

verifyAdminApproved().catch(console.error);