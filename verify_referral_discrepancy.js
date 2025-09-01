const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')

// .env.localを手動で読み込む
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

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Supabase環境変数が設定されていません')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseAnonKey)

// 特定ユーザーの紹介ツリーを検証
async function verifyUserReferralTree(userId) {
  console.log(`\n===== ${userId} の紹介ツリー検証 =====`)
  
  // 全ユーザーデータを取得
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, total_purchases, referrer_user_id')
    .order('created_at', { ascending: true })
  
  if (error) {
    console.error('ユーザーデータ取得エラー:', error)
    return
  }
  
  // このユーザーの情報
  const targetUser = allUsers.find(u => u.user_id === userId)
  if (!targetUser) {
    console.log(`ユーザー ${userId} が見つかりません`)
    return
  }
  
  console.log(`\nターゲットユーザー: ${targetUser.email}`)
  console.log(`個人購入額: $${targetUser.total_purchases}`)
  console.log(`運用額: $${Math.floor(targetUser.total_purchases / 1100) * 1000}`)
  
  // 管理画面の紹介ツリー計算ロジック（fallback）を再現
  console.log('\n【管理画面の計算方法（紹介ツリー）】')
  
  // Level 1の直接紹介者
  const level1Users = allUsers.filter(u => u.referrer_user_id === userId)
  console.log(`Level 1: ${level1Users.length}人`)
  
  let adminTreeTotal = 0
  let adminTreeCount = 0
  
  for (const user1 of level1Users) {
    const amount1 = Math.floor(user1.total_purchases / 1100) * 1000
    adminTreeTotal += amount1
    if (amount1 > 0) adminTreeCount++
    
    // Level 2
    const level2Users = allUsers.filter(u => u.referrer_user_id === user1.user_id)
    for (const user2 of level2Users) {
      const amount2 = Math.floor(user2.total_purchases / 1100) * 1000
      adminTreeTotal += amount2
      if (amount2 > 0) adminTreeCount++
      
      // Level 3
      const level3Users = allUsers.filter(u => u.referrer_user_id === user2.user_id)
      for (const user3 of level3Users) {
        const amount3 = Math.floor(user3.total_purchases / 1100) * 1000
        adminTreeTotal += amount3
        if (amount3 > 0) adminTreeCount++
      }
    }
  }
  
  console.log(`総購入額（Level 1-3）: $${adminTreeTotal}`)
  console.log(`総人数（購入者のみ）: ${adminTreeCount}人`)
  
  // ダッシュボードの計算ロジックを再現
  console.log('\n【ダッシュボードの計算方法】')
  
  // total_purchases > 0 のユーザーのみ取得
  const purchasedUsers = allUsers.filter(u => u.total_purchases > 0)
  
  // Level 1
  const dashLevel1 = purchasedUsers.filter(u => u.referrer_user_id === userId)
  const dashLevel1Ids = new Set(dashLevel1.map(u => u.user_id))
  
  // Level 2
  const dashLevel2 = purchasedUsers.filter(u => dashLevel1Ids.has(u.referrer_user_id || ''))
  const dashLevel2Ids = new Set(dashLevel2.map(u => u.user_id))
  
  // Level 3
  const dashLevel3 = purchasedUsers.filter(u => dashLevel2Ids.has(u.referrer_user_id || ''))
  const dashLevel3Ids = new Set(dashLevel3.map(u => u.user_id))
  
  // Level 4+（最大500レベルまで）
  let dashLevel4Plus = []
  let currentLevelIds = new Set(dashLevel3Ids)
  let allProcessedIds = new Set([...dashLevel1Ids, ...dashLevel2Ids, ...dashLevel3Ids])
  
  let level = 4
  while (currentLevelIds.size > 0 && level <= 500) {
    const nextLevel = purchasedUsers.filter(u => 
      currentLevelIds.has(u.referrer_user_id || '') && 
      !allProcessedIds.has(u.user_id)
    )
    if (nextLevel.length === 0) break
    
    dashLevel4Plus.push(...nextLevel)
    const newIds = new Set(nextLevel.map(u => u.user_id))
    newIds.forEach(id => allProcessedIds.add(id))
    currentLevelIds = newIds
    level++
  }
  
  // 投資額計算
  const calculateInvestment = (users) => 
    users.reduce((sum, u) => sum + Math.floor((u.total_purchases || 0) / 1100) * 1000, 0)
  
  const dashLevel1Investment = calculateInvestment(dashLevel1)
  const dashLevel2Investment = calculateInvestment(dashLevel2)
  const dashLevel3Investment = calculateInvestment(dashLevel3)
  const dashLevel4PlusInvestment = calculateInvestment(dashLevel4Plus)
  
  console.log(`Level 1: ${dashLevel1.length}人, $${dashLevel1Investment}`)
  console.log(`Level 2: ${dashLevel2.length}人, $${dashLevel2Investment}`)
  console.log(`Level 3: ${dashLevel3.length}人, $${dashLevel3Investment}`)
  console.log(`Level 4+: ${dashLevel4Plus.length}人, $${dashLevel4PlusInvestment}`)
  console.log(`総紹介人数: ${dashLevel1.length + dashLevel2.length + dashLevel3.length + dashLevel4Plus.length}人`)
  console.log(`総購入額: $${dashLevel1Investment + dashLevel2Investment + dashLevel3Investment + dashLevel4PlusInvestment}`)
  
  // 比較結果
  console.log('\n【比較結果】')
  console.log('管理画面（Level 1-3のみ）:')
  console.log(`  人数: ${adminTreeCount}人`)
  console.log(`  金額: $${adminTreeTotal}`)
  console.log('ダッシュボード（全レベル）:')
  console.log(`  人数: ${dashLevel1.length + dashLevel2.length + dashLevel3.length + dashLevel4Plus.length}人`)
  console.log(`  金額: $${dashLevel1Investment + dashLevel2Investment + dashLevel3Investment + dashLevel4PlusInvestment}`)
  
  // 差異の原因
  console.log('\n【差異の原因】')
  console.log('1. 管理画面の紹介ツリーはLevel 1-3のみ表示')
  console.log('2. ダッシュボードは全レベル（Level 4+含む）を計算')
  console.log('3. 管理画面は全ユーザーを対象、ダッシュボードはtotal_purchases > 0のみ')
  
  // Level 4以降の詳細
  if (dashLevel4Plus.length > 0) {
    console.log(`\nLevel 4以降の${dashLevel4Plus.length}人が管理画面に表示されていません:`)
    dashLevel4Plus.slice(0, 5).forEach(u => {
      console.log(`  - ${u.user_id}: $${Math.floor(u.total_purchases / 1100) * 1000}`)
    })
    if (dashLevel4Plus.length > 5) {
      console.log(`  ... 他${dashLevel4Plus.length - 5}人`)
    }
  }
}

// 全体統計の検証
async function verifyOverallStats() {
  console.log('\n===== 全体統計の検証 =====')
  
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, total_purchases, referrer_user_id')
    .order('total_purchases', { ascending: false })
  
  if (error) {
    console.error('ユーザーデータ取得エラー:', error)
    return
  }
  
  const purchasedUsers = allUsers.filter(u => u.total_purchases > 0)
  const topInvestors = purchasedUsers.slice(0, 10)
  
  console.log(`\n全ユーザー数: ${allUsers.length}人`)
  console.log(`投資済みユーザー: ${purchasedUsers.length}人`)
  console.log(`総投資額: $${purchasedUsers.reduce((sum, u) => sum + Math.floor(u.total_purchases / 1100) * 1000, 0)}`)
  
  console.log('\n【TOP10投資家】')
  topInvestors.forEach((u, i) => {
    const investment = Math.floor(u.total_purchases / 1100) * 1000
    console.log(`${i + 1}. ${u.user_id} (${u.email}): $${investment}`)
  })
}

// メイン処理
async function main() {
  console.log('紹介ツリーとダッシュボードの数値不一致を検証します...\n')
  
  // 全体統計を表示
  await verifyOverallStats()
  
  // 特定のユーザーを検証（例: 複数のユーザーを検証）
  // 紹介者が多いユーザーで検証
  const testUserIds = ['B51CA4', '66D65D', '07712F'] // 紹介者が多いユーザーで検証
  
  for (const userId of testUserIds) {
    await verifyUserReferralTree(userId)
  }
  
  console.log('\n===== 検証完了 =====')
  console.log('\n【推奨される修正】')
  console.log('1. 管理画面の紹介ツリーでLevel 4以降も表示する')
  console.log('2. または、ダッシュボードでLevel 1-3のみの統計も別途表示する')
  console.log('3. 両画面で同じ計算ロジックを使用する')
  console.log('4. get_referral_tree と get_referral_stats のSQL関数を実装する')
}

main().catch(console.error)