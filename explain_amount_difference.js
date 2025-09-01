const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')

// .env.localを手動で読み込み
const envPath = '.env.local'
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8')
  envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=')
    if (key && value) {
      process.env[key.trim()] = value.trim()
    }
  })
}

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function explainAmountDifference() {
  const userId = '7A9637'
  console.log(`\n${'='.repeat(100)}`)
  console.log(`金額差異の詳細説明 - ${userId}`)
  console.log(`${'='.repeat(100)}\n`)
  
  // 全ユーザーデータを取得
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, total_purchases, referrer_user_id')
    .order('created_at', { ascending: true })
  
  if (error) {
    console.error('エラー:', error)
    return
  }
  
  // 紹介ツリーを構築
  const buildTree = (rootId) => {
    const tree = new Map()
    const processed = new Set([rootId])
    
    const level1 = allUsers.filter(u => u.referrer_user_id === rootId)
    if (level1.length > 0) {
      tree.set(1, level1)
      level1.forEach(u => processed.add(u.user_id))
    }
    
    let currentLevel = 1
    while (currentLevel < 50) {
      const currentUsers = tree.get(currentLevel)
      if (!currentUsers?.length) break
      
      const nextLevelUsers = []
      for (const parent of currentUsers) {
        const children = allUsers.filter(u => 
          u.referrer_user_id === parent.user_id && 
          !processed.has(u.user_id)
        )
        children.forEach(child => {
          processed.add(child.user_id)
          nextLevelUsers.push(child)
        })
      }
      
      if (nextLevelUsers.length > 0) {
        tree.set(currentLevel + 1, nextLevelUsers)
      }
      currentLevel++
    }
    return tree
  }
  
  const tree = buildTree(userId)
  
  // 全紹介者を平坦化
  const allReferrals = []
  tree.forEach(users => allReferrals.push(...users))
  
  console.log('【紹介者の詳細分析】')
  console.log(`全紹介者数: ${allReferrals.length}人`)
  
  // 購入状況で分類
  const purchasedReferrals = allReferrals.filter(u => u.total_purchases > 0)
  const unpurchasedReferrals = allReferrals.filter(u => u.total_purchases === 0)
  
  console.log(`購入済み: ${purchasedReferrals.length}人`)
  console.log(`未購入: ${unpurchasedReferrals.length}人`)
  
  // 金額計算の比較
  console.log('\n' + '='.repeat(80))
  console.log('【金額計算方式の比較】')
  console.log('='.repeat(80))
  
  // 方式1: 運用額計算（現在のダッシュボード）
  const operationalAmount = purchasedReferrals.reduce((sum, u) => {
    const nftCount = Math.floor(u.total_purchases / 1100)
    const operational = nftCount * 1000
    return sum + operational
  }, 0)
  
  // 方式2: 実購入額計算（管理画面SQL関数）
  const actualPurchases = purchasedReferrals.reduce((sum, u) => sum + u.total_purchases, 0)
  
  console.log(`\n方式1: 運用額計算`)
  console.log(`  計算式: Math.floor(購入額 / 1100) × 1000`)
  console.log(`  結果: $${operationalAmount} （購入者${purchasedReferrals.length}人のみ）`)
  
  console.log(`\n方式2: 実購入額計算`)
  console.log(`  計算式: 購入額の合計`)
  console.log(`  結果: $${actualPurchases} （購入者${purchasedReferrals.length}人のみ）`)
  
  console.log(`\n差額: $${actualPurchases - operationalAmount}`)
  
  // 具体例を表示
  console.log('\n【具体例】')
  console.log('購入額 → 運用額 の変換例:')
  
  const examples = purchasedReferrals
    .filter(u => u.total_purchases > 1100)
    .slice(0, 10)
    .map(u => ({
      user_id: u.user_id,
      purchase: u.total_purchases,
      operational: Math.floor(u.total_purchases / 1100) * 1000,
      difference: u.total_purchases - Math.floor(u.total_purchases / 1100) * 1000
    }))
    .sort((a, b) => b.difference - a.difference)
  
  examples.forEach((ex, i) => {
    console.log(`${i + 1}. ${ex.user_id}: $${ex.purchase} → $${ex.operational} (差: $${ex.difference})`)
  })
  
  // 切り捨て損失の合計
  const totalLoss = purchasedReferrals.reduce((sum, u) => {
    const operational = Math.floor(u.total_purchases / 1100) * 1000
    return sum + (u.total_purchases - operational)
  }, 0)
  
  console.log(`\n運用額計算での切り捨て損失合計: $${totalLoss}`)
  
  // 現在の表示値との比較
  console.log('\n' + '='.repeat(80))
  console.log('【表示値の説明】')
  console.log('='.repeat(80))
  
  console.log('\n管理画面: 241人, $271,700')
  console.log('  - 人数: 全紹介者（未購入含む）')
  console.log('  - 金額: 実購入額合計')
  console.log('  - データソース: SQL関数')
  
  console.log('\n統一システム（ダッシュボード用）: 162人, $247,000')
  console.log('  - 人数: 購入済み紹介者のみ')
  console.log('  - 金額: 運用額合計（切り捨てあり）')
  console.log('  - データソース: JavaScript計算')
  
  console.log('\n【問題の核心】')
  console.log('1. 人数の違い: 全紹介者 vs 購入者のみ')
  console.log('2. 金額の違い: 実購入額 vs 運用額（切り捨てあり）')
  console.log(`3. 切り捨て損失: $${totalLoss} の差が生じる`)
  
  console.log('\n【解決案】')
  console.log('A. 両画面で同じ金額表示にする:')
  console.log('   - 管理画面: $247,000（運用額）に統一')
  console.log('   - ダッシュボード: $247,000（運用額）')
  console.log('\nB. または両画面で実購入額表示:')
  console.log('   - 管理画面: $271,700（実購入額）')
  console.log('   - ダッシュボード: $271,700（実購入額）')
}

explainAmountDifference().catch(console.error)