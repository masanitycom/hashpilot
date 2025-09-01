const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
const path = require('path')

// .env.localファイルを読み込み
const envPath = path.join(__dirname, '.env.local')
const envContent = fs.readFileSync(envPath, 'utf8')
const envVars = {}
envContent.split('\n').forEach(line => {
  const [key, ...valueParts] = line.split('=')
  if (key && valueParts.length > 0) {
    envVars[key.trim()] = valueParts.join('=').trim()
  }
})

const supabase = createClient(
  envVars.NEXT_PUBLIC_SUPABASE_URL,
  envVars.SUPABASE_SERVICE_ROLE_KEY || envVars.NEXT_PUBLIC_SUPABASE_ANON_KEY
)

// 統一計算ロジックの実装
class UnifiedReferralCalculator {
  constructor(allUsers) {
    this.allUsers = allUsers
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
  
  calculateStats(userId) {
    const tree = this.buildReferralTree(userId)
    let totalInvestment = 0
    let totalReferrals = 0
    let purchasedReferrals = 0
    
    tree.forEach((users, level) => {
      users.forEach(user => {
        totalReferrals++
        if (user.total_purchases > 0) {
          purchasedReferrals++
          // 運用額計算（手数料除く）
          const investment = Math.floor(user.total_purchases / 1100) * 1000
          totalInvestment += investment
        }
      })
    })
    
    return {
      totalReferrals,
      purchasedReferrals,
      totalInvestment,
      treeDepth: tree.size
    }
  }
}

// 管理画面のツリー計算ロジック
function buildAdminTree(allUsers, rootUserId) {
  const buildTreeNode = (rootId, level = 1, visited = new Set()) => {
    if (visited.has(rootId)) return null
    visited.add(rootId)
    
    const user = allUsers.find(u => u.user_id === rootId)
    if (!user) return null
    
    const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
    
    const directReferrals = allUsers.filter(u => u.referrer_user_id === rootId)
    const children = []
    let subtreeTotal = 0
    
    for (const referral of directReferrals) {
      const childNode = buildTreeNode(referral.user_id, level + 1, new Set(visited))
      if (childNode) {
        children.push(childNode)
        subtreeTotal += childNode.totalAmount
      }
    }
    
    const totalAmount = personalInvestment + subtreeTotal
    
    return {
      user_id: user.user_id,
      email: user.email,
      level,
      personalInvestment,
      subtreeTotal,
      totalAmount,
      children
    }
  }
  
  return buildTreeNode(rootUserId)
}

async function verifyReferralAmounts() {
  console.log('=== 紹介ネットワーク金額検証 ===\n')
  
  try {
    // 全ユーザーデータ取得
    const { data: allUsers, error } = await supabase
      .from('users')
      .select('user_id, email, total_purchases, referrer_user_id, created_at')
      .order('created_at', { ascending: true })
    
    if (error) throw error
    
    console.log(`総ユーザー数: ${allUsers.length}`)
    console.log(`購入済みユーザー数: ${allUsers.filter(u => u.total_purchases > 0).length}\n`)
    
    // テストユーザーを選定（購入額が多い上位5名）
    const testUsers = allUsers
      .filter(u => u.total_purchases > 0)
      .sort((a, b) => b.total_purchases - a.total_purchases)
      .slice(0, 5)
    
    console.log('=== 検証対象ユーザー ===')
    
    for (const testUser of testUsers) {
      console.log(`\n検証: ${testUser.user_id} (${testUser.email})`)
      console.log(`個人購入額: $${testUser.total_purchases}`)
      console.log(`個人運用額: $${Math.floor(testUser.total_purchases / 1100) * 1000}`)
      
      // ダッシュボード計算（統一システム）
      const calculator = new UnifiedReferralCalculator(allUsers)
      const dashboardStats = calculator.calculateStats(testUser.user_id)
      
      // 管理画面計算（ツリー構築）
      const adminTree = buildAdminTree(allUsers, testUser.user_id)
      const adminStats = adminTree ? {
        totalInvestment: adminTree.subtreeTotal,
        personalInvestment: adminTree.personalInvestment,
        totalAmount: adminTree.totalAmount
      } : null
      
      console.log('\n【ダッシュボード計算結果】')
      console.log(`- 紹介者数: ${dashboardStats.totalReferrals}`)
      console.log(`- 購入済み紹介者: ${dashboardStats.purchasedReferrals}`)
      console.log(`- 紹介ネットワーク運用額: $${dashboardStats.totalInvestment.toLocaleString()}`)
      
      console.log('\n【管理画面計算結果】')
      if (adminStats) {
        console.log(`- 個人運用額: $${adminStats.personalInvestment.toLocaleString()}`)
        console.log(`- 下位合計: $${adminStats.totalInvestment.toLocaleString()}`)
        console.log(`- 総合計: $${adminStats.totalAmount.toLocaleString()}`)
      }
      
      // 差異チェック
      if (dashboardStats.totalInvestment !== adminStats?.totalInvestment) {
        console.log('\n⚠️ 不整合検出!')
        console.log(`差額: $${Math.abs(dashboardStats.totalInvestment - (adminStats?.totalInvestment || 0)).toLocaleString()}`)
      } else {
        console.log('\n✅ 金額一致')
      }
      
      console.log('-'.repeat(50))
    }
    
  } catch (error) {
    console.error('エラー:', error)
  }
}

verifyReferralAmounts()