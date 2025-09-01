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

async function verify7A9637() {
  const userId = '7A9637'
  console.log(`\n${'='.repeat(100)}`)
  console.log(`7A9637 (masakuma1108@gmail.com) の完全な検証`)
  console.log(`${'='.repeat(100)}\n`)
  
  // 全ユーザーデータを取得
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, total_purchases, referrer_user_id, created_at')
    .order('created_at', { ascending: true })
  
  if (error) {
    console.error('ユーザーデータ取得エラー:', error)
    return
  }
  
  // ユーザー情報
  const targetUser = allUsers.find(u => u.user_id === userId)
  if (!targetUser) {
    console.log('ユーザーが見つかりません')
    return
  }
  
  console.log('【ユーザー情報】')
  console.log(`Email: ${targetUser.email}`)
  console.log(`個人購入額: $${targetUser.total_purchases}`)
  console.log(`運用額: $${Math.floor(targetUser.total_purchases / 1100) * 1000}`)
  console.log(`登録日: ${targetUser.created_at}`)
  
  // ===== ダッシュボードの計算方法（正確な再現） =====
  console.log('\n' + '='.repeat(80))
  console.log('【ダッシュボードの計算ロジック】（app/dashboard/page.tsx）')
  console.log('='.repeat(80))
  
  // total_purchases > 0 のユーザーのみ
  const purchasedUsers = allUsers.filter(u => u.total_purchases > 0)
  console.log(`購入済みユーザー総数: ${purchasedUsers.length}人`)
  
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
  const levelBreakdown = new Map() // レベル別の詳細
  
  while (currentLevelIds.size > 0 && level <= 500) {
    const nextLevel = purchasedUsers.filter(u => 
      currentLevelIds.has(u.referrer_user_id || '') && 
      !allProcessedIds.has(u.user_id)
    )
    if (nextLevel.length === 0) break
    
    levelBreakdown.set(level, nextLevel)
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
  
  console.log(`\nLevel 1: ${dashLevel1.length}人, $${dashLevel1Investment}`)
  console.log(`Level 2: ${dashLevel2.length}人, $${dashLevel2Investment}`)
  console.log(`Level 3: ${dashLevel3.length}人, $${dashLevel3Investment}`)
  console.log(`Level 4+: ${dashLevel4Plus.length}人, $${dashLevel4PlusInvestment}`)
  
  // Level 4+の詳細
  if (levelBreakdown.size > 0) {
    console.log('\nLevel 4+の詳細:')
    for (const [lvl, users] of levelBreakdown) {
      const investment = calculateInvestment(users)
      console.log(`  Level ${lvl}: ${users.length}人, $${investment}`)
    }
  }
  
  const dashTotalCount = dashLevel1.length + dashLevel2.length + dashLevel3.length + dashLevel4Plus.length
  const dashTotalInvestment = dashLevel1Investment + dashLevel2Investment + dashLevel3Investment + dashLevel4PlusInvestment
  
  console.log(`\n【ダッシュボード合計】`)
  console.log(`総紹介人数: ${dashTotalCount}人`)
  console.log(`紹介投資額: $${dashTotalInvestment}`)
  
  // ===== 管理画面の計算方法（get_referral_stats の推定） =====
  console.log('\n' + '='.repeat(80))
  console.log('【管理画面の計算ロジック（推定）】')
  console.log('='.repeat(80))
  
  // 管理画面は全ユーザーを対象にしている可能性
  console.log('\n方法1: 全ユーザー（購入有無に関わらず）を対象')
  
  // 全レベルを再帰的に取得（購入有無に関わらず）
  const getAllReferrals = (rootId, processed = new Set()) => {
    if (processed.has(rootId)) return { users: [], count: 0, investment: 0 }
    processed.add(rootId)
    
    const directReferrals = allUsers.filter(u => u.referrer_user_id === rootId)
    let allReferrals = [...directReferrals]
    let totalInvestment = 0
    
    for (const ref of directReferrals) {
      const investment = Math.floor((ref.total_purchases || 0) / 1100) * 1000
      totalInvestment += investment
      
      const subTree = getAllReferrals(ref.user_id, processed)
      allReferrals.push(...subTree.users)
      totalInvestment += subTree.investment
    }
    
    return { 
      users: allReferrals, 
      count: allReferrals.length,
      investment: totalInvestment 
    }
  }
  
  const adminStats1 = getAllReferrals(userId)
  console.log(`総紹介人数: ${adminStats1.count}人`)
  console.log(`総購入額: $${adminStats1.investment}`)
  
  // 方法2: 直接紹介と間接紹介を別計算
  console.log('\n方法2: 直接紹介と間接紹介を分けて計算')
  
  const directReferrals = allUsers.filter(u => u.referrer_user_id === userId)
  const directCount = directReferrals.length
  const directInvestment = calculateInvestment(directReferrals)
  
  // 間接紹介（全レベル）
  let indirectCount = 0
  let indirectInvestment = 0
  const processedForIndirect = new Set([userId])
  
  const queue = [...directReferrals.map(u => u.user_id)]
  while (queue.length > 0) {
    const currentId = queue.shift()
    if (processedForIndirect.has(currentId)) continue
    processedForIndirect.add(currentId)
    
    const refs = allUsers.filter(u => u.referrer_user_id === currentId)
    indirectCount += refs.length
    indirectInvestment += calculateInvestment(refs)
    queue.push(...refs.map(u => u.user_id))
  }
  
  console.log(`直接紹介: ${directCount}人, $${directInvestment}`)
  console.log(`間接紹介: ${indirectCount}人, $${indirectInvestment}`)
  console.log(`合計: ${directCount + indirectCount}人, $${directInvestment + indirectInvestment}`)
  
  // ===== 差異分析 =====
  console.log('\n' + '='.repeat(80))
  console.log('【差異分析】')
  console.log('='.repeat(80))
  
  console.log('\nダッシュボード表示:')
  console.log(`  総紹介者: 159人`)
  console.log(`  紹介投資額: $244,000`)
  
  console.log('\n管理画面表示:')
  console.log(`  総紹介人数: 241人`)
  console.log(`  総購入額: $271,700`)
  
  console.log('\n実際の計算結果:')
  console.log(`  ダッシュボード計算: ${dashTotalCount}人, $${dashTotalInvestment}`)
  console.log(`  管理画面計算（方法1）: ${adminStats1.count}人, $${adminStats1.investment}`)
  console.log(`  管理画面計算（方法2）: ${directCount + indirectCount}人, $${directInvestment + indirectInvestment}`)
  
  // 差異の原因を特定
  console.log('\n【差異の原因】')
  
  // 購入していないユーザーを含む計算
  const allReferralsIncludingNoPurchase = []
  const processedAll = new Set()
  const queueAll = [userId]
  
  while (queueAll.length > 0) {
    const currentId = queueAll.shift()
    if (processedAll.has(currentId)) continue
    processedAll.add(currentId)
    
    const refs = allUsers.filter(u => u.referrer_user_id === currentId)
    allReferralsIncludingNoPurchase.push(...refs)
    queueAll.push(...refs.map(u => u.user_id))
  }
  
  const noPurchaseUsers = allReferralsIncludingNoPurchase.filter(u => u.total_purchases === 0)
  const purchaseUsers = allReferralsIncludingNoPurchase.filter(u => u.total_purchases > 0)
  
  console.log(`\n全紹介者（購入有無含む）: ${allReferralsIncludingNoPurchase.length}人`)
  console.log(`  - 購入済み: ${purchaseUsers.length}人`)
  console.log(`  - 未購入: ${noPurchaseUsers.length}人`)
  
  // ユーザーIDの重複チェック
  const uniqueIds = new Set(allReferralsIncludingNoPurchase.map(u => u.user_id))
  console.log(`\nユニークID数: ${uniqueIds.size}`)
  console.log(`重複カウント: ${allReferralsIncludingNoPurchase.length - uniqueIds.size}`)
  
  // Level別の詳細表示
  console.log('\n【レベル別詳細（購入者のみ）】')
  console.log('Level 1:')
  dashLevel1.slice(0, 3).forEach(u => {
    console.log(`  ${u.user_id}: $${Math.floor(u.total_purchases / 1100) * 1000}`)
  })
  if (dashLevel1.length > 3) console.log(`  ... 他${dashLevel1.length - 3}人`)
  
  console.log('\nLevel 2:')
  dashLevel2.slice(0, 3).forEach(u => {
    console.log(`  ${u.user_id}: $${Math.floor(u.total_purchases / 1100) * 1000}`)
  })
  if (dashLevel2.length > 3) console.log(`  ... 他${dashLevel2.length - 3}人`)
}

verify7A9637().catch(console.error)