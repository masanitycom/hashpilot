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

// 統一計算ロジック（ダッシュボード側）
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
    const levelBreakdown = []
    let totalInvestment = 0
    let totalReferrals = 0
    let purchasedReferrals = 0
    
    tree.forEach((users, level) => {
      let levelInvestment = 0
      let levelPurchased = 0
      
      users.forEach(user => {
        totalReferrals++
        if (user.total_purchases > 0) {
          purchasedReferrals++
          levelPurchased++
          // 運用額計算（手数料除く）
          const investment = Math.floor(user.total_purchases / 1100) * 1000
          levelInvestment += investment
          totalInvestment += investment
        }
      })
      
      levelBreakdown.push({
        level,
        count: users.length,
        purchased: levelPurchased,
        investment: levelInvestment
      })
    })
    
    return {
      totalReferrals,
      purchasedReferrals,
      totalInvestment,
      levelBreakdown,
      treeDepth: tree.size
    }
  }
}

// 管理画面の再帰的ツリー計算
function buildAdminTreeRecursive(allUsers, rootUserId, level = 0, visited = new Set()) {
  if (visited.has(rootUserId)) return null
  
  const user = allUsers.find(u => u.user_id === rootUserId)
  if (!user) return null
  
  const newVisited = new Set(visited)
  newVisited.add(rootUserId)
  
  const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
  
  const directReferrals = allUsers.filter(u => u.referrer_user_id === rootUserId)
  const children = []
  let subtreeTotal = 0
  
  for (const referral of directReferrals) {
    const childNode = buildAdminTreeRecursive(allUsers, referral.user_id, level + 1, newVisited)
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

// ツリーを詳細に出力
function printDetailedTree(node, depth = 0, maxDepth = 3) {
  if (depth > maxDepth) return
  
  const indent = '  '.repeat(depth)
  const levelLabel = node.level === 0 ? 'Root' : `Lv.${node.level}`
  
  console.log(`${indent}${levelLabel} ${node.user_id} (${node.email})`)
  console.log(`${indent}  個人: $${node.personalInvestment.toLocaleString()}`)
  console.log(`${indent}  下位: $${node.subtreeTotal.toLocaleString()}`)
  console.log(`${indent}  合計: $${node.totalAmount.toLocaleString()}`)
  
  if (node.children.length > 0 && depth < maxDepth) {
    console.log(`${indent}  子ノード ${node.children.length}人:`)
    node.children.forEach(child => printDetailedTree(child, depth + 1, maxDepth))
  } else if (node.children.length > 0) {
    console.log(`${indent}  ... (子ノード ${node.children.length}人省略)`)
  }
}

async function verifyCalculations() {
  console.log('=== 紹介ネットワーク金額計算の詳細検証 ===\n')
  
  try {
    // 全ユーザーデータ取得
    const { data: allUsers, error } = await supabase
      .from('users')
      .select('user_id, email, total_purchases, referrer_user_id, created_at')
      .order('created_at', { ascending: true })
    
    if (error) throw error
    
    console.log(`総ユーザー数: ${allUsers.length}`)
    console.log(`購入済みユーザー数: ${allUsers.filter(u => u.total_purchases > 0).length}`)
    
    // テストケース: 複雑な紹介ツリーを持つユーザー
    const testCases = [
      '7A9637', // 3人の直紹介者
      '6E1304', // 11人の直紹介者
      'B51CA4', // 9人の直紹介者
      '0B2371'  // 4人の直紹介者
    ]
    
    console.log('\n=== 詳細検証 ===')
    
    for (const userId of testCases) {
      const user = allUsers.find(u => u.user_id === userId)
      if (!user) continue
      
      console.log('\n' + '='.repeat(60))
      console.log(`検証対象: ${userId} (${user.email})`)
      console.log(`個人購入額: $${user.total_purchases}`)
      console.log(`個人運用額: $${Math.floor(user.total_purchases / 1100) * 1000}`)
      console.log('='.repeat(60))
      
      // ダッシュボード計算
      const calculator = new UnifiedReferralCalculator(allUsers)
      const dashboardStats = calculator.calculateStats(userId)
      
      // 管理画面計算
      const adminTree = buildAdminTreeRecursive(allUsers, userId)
      
      console.log('\n【ダッシュボード計算結果】')
      console.log(`紹介者総数: ${dashboardStats.totalReferrals}人`)
      console.log(`購入済み紹介者: ${dashboardStats.purchasedReferrals}人`)
      console.log(`紹介ネットワーク運用額: $${dashboardStats.totalInvestment.toLocaleString()}`)
      
      console.log('\nレベル別内訳:')
      dashboardStats.levelBreakdown.forEach(level => {
        if (level.count > 0) {
          console.log(`  Lv.${level.level}: ${level.count}人 (購入済み ${level.purchased}人) = $${level.investment.toLocaleString()}`)
        }
      })
      
      console.log('\n【管理画面計算結果】')
      if (adminTree) {
        console.log(`個人運用額: $${adminTree.personalInvestment.toLocaleString()}`)
        console.log(`下位合計: $${adminTree.subtreeTotal.toLocaleString()}`)
        console.log(`総合計: $${adminTree.totalAmount.toLocaleString()}`)
        
        console.log('\nツリー構造（3レベルまで表示）:')
        printDetailedTree(adminTree)
      }
      
      // 差異チェック
      console.log('\n【整合性チェック】')
      if (dashboardStats.totalInvestment === adminTree?.subtreeTotal) {
        console.log('✅ 紹介ネットワーク金額一致: $' + dashboardStats.totalInvestment.toLocaleString())
      } else {
        console.log('❌ 不整合検出!')
        console.log(`  ダッシュボード: $${dashboardStats.totalInvestment.toLocaleString()}`)
        console.log(`  管理画面: $${adminTree?.subtreeTotal.toLocaleString() || '0'}`)
        console.log(`  差額: $${Math.abs(dashboardStats.totalInvestment - (adminTree?.subtreeTotal || 0)).toLocaleString()}`)
      }
    }
    
    // 全体統計
    console.log('\n' + '='.repeat(60))
    console.log('【全体統計】')
    
    let totalSystemInvestment = 0
    allUsers.forEach(user => {
      if (user.total_purchases > 0) {
        totalSystemInvestment += Math.floor(user.total_purchases / 1100) * 1000
      }
    })
    
    console.log(`システム全体の運用額: $${totalSystemInvestment.toLocaleString()}`)
    
    // レベル4+の検証
    const level4PlusUsers = []
    allUsers.forEach(user => {
      const stats = new UnifiedReferralCalculator(allUsers).calculateStats(user.user_id)
      const level4Plus = stats.levelBreakdown
        .filter(l => l.level >= 4)
        .reduce((sum, l) => sum + l.purchased, 0)
      
      if (level4Plus > 0) {
        level4PlusUsers.push({
          user_id: user.user_id,
          count: level4Plus,
          investment: stats.levelBreakdown
            .filter(l => l.level >= 4)
            .reduce((sum, l) => sum + l.investment, 0)
        })
      }
    })
    
    console.log(`\nLevel 4+紹介者を持つユーザー: ${level4PlusUsers.length}人`)
    console.log('上位5名:')
    level4PlusUsers
      .sort((a, b) => b.count - a.count)
      .slice(0, 5)
      .forEach(u => {
        console.log(`  ${u.user_id}: ${u.count}人 = $${u.investment.toLocaleString()}`)
      })
    
  } catch (error) {
    console.error('エラー:', error)
  }
}

verifyCalculations()