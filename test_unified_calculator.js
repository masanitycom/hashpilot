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

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Supabase環境変数が設定されていません')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseAnonKey)

// 統一計算ロジック（JavaScriptで再実装）
class UnifiedReferralCalculator {
  constructor() {
    this.allUsers = []
  }
  
  async loadAllUsers() {
    const { data, error } = await supabase
      .from('users')
      .select('user_id, email, total_purchases, referrer_user_id, created_at')
      .order('created_at', { ascending: true })
    
    if (error) {
      throw new Error(`ユーザーデータ取得エラー: ${error.message}`)
    }
    
    this.allUsers = data || []
  }
  
  buildReferralTree(rootUserId) {
    const tree = new Map()
    const processed = new Set([rootUserId])
    
    // Level 1: 直接紹介者
    const level1 = this.allUsers.filter(u => u.referrer_user_id === rootUserId)
    if (level1.length > 0) {
      tree.set(1, level1)
      level1.forEach(u => processed.add(u.user_id))
    }
    
    let currentLevel = 1
    const maxLevels = 100
    
    while (currentLevel < maxLevels) {
      const currentLevelUsers = tree.get(currentLevel)
      if (!currentLevelUsers || currentLevelUsers.length === 0) break
      
      const nextLevelUsers = []
      
      for (const parent of currentLevelUsers) {
        const children = this.allUsers.filter(u => 
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
  
  calculateLevelBreakdown(tree) {
    const breakdown = []
    
    for (const [level, users] of tree) {
      const purchasedUsers = users.filter(u => u.total_purchases > 0)
      const investment = purchasedUsers.reduce((sum, u) => 
        sum + Math.floor(u.total_purchases / 1100) * 1000, 0
      )
      
      breakdown.push({
        level,
        totalCount: users.length,
        purchasedCount: purchasedUsers.length,
        investment
      })
    }
    
    return breakdown.sort((a, b) => a.level - b.level)
  }
  
  calculateBasicStats(tree, levelBreakdown) {
    const allReferrals = []
    tree.forEach(users => allReferrals.push(...users))
    
    const purchasedReferrals = allReferrals.filter(u => u.total_purchases > 0)
    
    return {
      totalReferrals: allReferrals.length,
      purchasedReferrals: purchasedReferrals.length,
      unpurchasedReferrals: allReferrals.length - purchasedReferrals.length,
      
      totalInvestment: levelBreakdown.reduce((sum, l) => sum + l.investment, 0),
      actualPurchases: purchasedReferrals.reduce((sum, u) => sum + u.total_purchases, 0),
      
      directReferrals: levelBreakdown.find(l => l.level === 1)?.totalCount || 0,
      indirectReferrals: allReferrals.length - (levelBreakdown.find(l => l.level === 1)?.totalCount || 0)
    }
  }
  
  async calculateCompleteStats(userId) {
    if (this.allUsers.length === 0) {
      await this.loadAllUsers()
    }
    
    const referralTree = this.buildReferralTree(userId)
    const levelBreakdown = this.calculateLevelBreakdown(referralTree)
    const stats = this.calculateBasicStats(referralTree, levelBreakdown)
    
    return {
      ...stats,
      levelBreakdown,
      maxLevel: Math.max(...levelBreakdown.map(l => l.level), 0)
    }
  }
}

function formatUnifiedStats(stats) {
  return {
    // ダッシュボード用（購入者ベース）
    dashboard: {
      totalReferrals: stats.purchasedReferrals,
      totalInvestment: stats.totalInvestment,
      level4Plus: stats.levelBreakdown
        .filter(l => l.level >= 4)
        .reduce((sum, l) => sum + l.purchasedCount, 0),
      level4PlusInvestment: stats.levelBreakdown
        .filter(l => l.level >= 4)
        .reduce((sum, l) => sum + l.investment, 0)
    },
    
    // 管理画面用（全紹介者ベース）- 運用額で統一
    admin: {
      totalReferrals: stats.totalReferrals,
      totalInvestment: stats.totalInvestment, // 運用額（手数料除く）
      purchasedCount: stats.purchasedReferrals,
      unpurchasedCount: stats.unpurchasedReferrals
    },
    
    // 詳細情報
    details: {
      maxLevel: stats.maxLevel,
      levelBreakdown: stats.levelBreakdown
    }
  }
}

async function testUnifiedCalculator() {
  const userId = '7A9637'
  console.log(`\n${'='.repeat(100)}`)
  console.log(`統一計算システム検証 - ${userId}`)
  console.log(`${'='.repeat(100)}\n`)
  
  const calculator = new UnifiedReferralCalculator()
  const stats = await calculator.calculateCompleteStats(userId)
  const formatted = formatUnifiedStats(stats)
  
  console.log('【完全統計】')
  console.log(`全紹介者: ${stats.totalReferrals}人`)
  console.log(`購入済み紹介者: ${stats.purchasedReferrals}人`)
  console.log(`未購入紹介者: ${stats.unpurchasedReferrals}人`)
  console.log(`運用額合計: $${stats.totalInvestment}`)
  console.log(`実購入額合計: $${stats.actualPurchases}`)
  console.log(`最大レベル: ${stats.maxLevel}`)
  
  console.log('\n【ダッシュボード表示用】')
  console.log(`総紹介者: ${formatted.dashboard.totalReferrals}人 （購入者のみ）`)
  console.log(`紹介投資額: $${formatted.dashboard.totalInvestment} （運用額）`)
  console.log(`Level 4+: ${formatted.dashboard.level4Plus}人, $${formatted.dashboard.level4PlusInvestment}`)
  
  console.log('\n【管理画面表示用】')
  console.log(`総紹介人数: ${formatted.admin.totalReferrals}人 （全紹介者）`)
  console.log(`総購入額: $${formatted.admin.totalInvestment} （実購入額）`)
  console.log(`購入済み: ${formatted.admin.purchasedCount}人`)
  console.log(`未購入: ${formatted.admin.unpurchasedCount}人`)
  
  // 現在の表示値と比較
  console.log('\n' + '='.repeat(80))
  console.log('【現在の表示値との比較】')
  console.log('='.repeat(80))
  
  console.log('\n現在のダッシュボード:')
  console.log('  総紹介者: 159人')
  console.log('  紹介投資額: $244,000')
  
  console.log('\n統一システム（ダッシュボード用）:')
  console.log(`  総紹介者: ${formatted.dashboard.totalReferrals}人`)
  console.log(`  紹介投資額: $${formatted.dashboard.totalInvestment}`)
  
  console.log('\n現在の管理画面:')
  console.log('  総紹介人数: 241人')
  console.log('  総購入額: $271,700')
  
  console.log('\n統一システム（管理画面用）:')
  console.log(`  総紹介人数: ${formatted.admin.totalReferrals}人`)
  console.log(`  総購入額: $${formatted.admin.totalInvestment}`)
  
  // SQL関数との比較
  console.log('\n' + '='.repeat(80))
  console.log('【SQL関数結果との比較】')
  console.log('='.repeat(80))
  
  try {
    const { data: statsResult } = await supabase.rpc('get_referral_stats', {
      target_user_id: userId
    })
    
    if (statsResult && statsResult[0]) {
      const sqlStats = statsResult[0]
      console.log('\nSQL関数結果:')
      console.log(`  総人数: ${sqlStats.total_direct_referrals + sqlStats.total_indirect_referrals}人`)
      console.log(`  総購入額: $${sqlStats.total_referral_purchases}`)
      
      console.log('\n統一システム:')
      console.log(`  総人数: ${stats.totalReferrals}人`)
      console.log(`  総購入額: $${stats.actualPurchases}`)
      
      // 一致チェック
      const peopleMatch = stats.totalReferrals === (sqlStats.total_direct_referrals + sqlStats.total_indirect_referrals)
      const amountMatch = Math.abs(stats.actualPurchases - sqlStats.total_referral_purchases) < 100
      
      console.log('\n一致度チェック:')
      console.log(`  人数一致: ${peopleMatch ? '✅' : '❌'} (差: ${Math.abs(stats.totalReferrals - (sqlStats.total_direct_referrals + sqlStats.total_indirect_referrals))})`)
      console.log(`  金額一致: ${amountMatch ? '✅' : '❌'} (差: $${Math.abs(stats.actualPurchases - sqlStats.total_referral_purchases)})`)
    }
  } catch (error) {
    console.log('SQL関数との比較エラー:', error.message)
  }
  
  // レベル別詳細
  console.log('\n【レベル別詳細】')
  stats.levelBreakdown.slice(0, 10).forEach(level => {
    console.log(`Level ${level.level}: 全${level.totalCount}人, 購入済み${level.purchasedCount}人, $${level.investment}`)
  })
  if (stats.levelBreakdown.length > 10) {
    console.log(`... 他${stats.levelBreakdown.length - 10}レベル`)
  }
}

testUnifiedCalculator().catch(console.error)