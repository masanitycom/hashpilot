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

async function debug7A9637Tree() {
  console.log('=== 7A9637のツリー構築デバッグ ===\n')
  
  try {
    // 全ユーザーデータ取得
    const { data: allUsers, error } = await supabase
      .from('users')
      .select('user_id, email, total_purchases, referrer_user_id')
      .order('created_at', { ascending: true })
    
    if (error) throw error
    
    const userId = '7A9637'
    
    // AdminReferralTreeFixedと同じロジック
    const buildTreeNode = (rootId, level = 1, visited = new Set()) => {
      console.log(`\n--- buildTreeNode呼び出し ---`)
      console.log(`rootId: ${rootId}, level: ${level}`)
      console.log(`visited: [${Array.from(visited).join(', ')}]`)
      
      // 循環参照を防ぐ
      if (visited.has(rootId)) {
        console.log(`既に処理済み: ${rootId}`)
        return null
      }
      
      const user = allUsers.find(u => u.user_id === rootId)
      if (!user) {
        console.log(`ユーザーが見つからない: ${rootId}`)
        return null
      }
      
      console.log(`ユーザー見つかった: ${user.user_id} (${user.email})`)
      
      // このノードを処理済みに追加
      const newVisited = new Set(visited)
      newVisited.add(rootId)
      console.log(`新しいvisited: [${Array.from(newVisited).join(', ')}]`)
      
      // 個人投資額（手数料除く）
      const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
      console.log(`個人投資額: $${personalInvestment}`)
      
      // 直接紹介者を取得
      const directReferrals = allUsers.filter(u => u.referrer_user_id === rootId)
      console.log(`直接紹介者数: ${directReferrals.length}`)
      directReferrals.forEach((ref, i) => {
        console.log(`  ${i+1}. ${ref.user_id} (${ref.email})`)
      })
      
      const children = []
      let subtreeTotal = 0
      
      // 各子ノードを再帰的に構築
      for (const referral of directReferrals) {
        console.log(`\n子ノード処理開始: ${referral.user_id}`)
        const childNode = buildTreeNode(referral.user_id, level + 1, newVisited)
        if (childNode) {
          children.push(childNode)
          subtreeTotal += childNode.totalAmount
          console.log(`子ノード追加成功: ${childNode.user_id}`)
        } else {
          console.log(`子ノード追加失敗: ${referral.user_id}`)
        }
      }
      
      const totalAmount = personalInvestment + subtreeTotal
      
      console.log(`最終結果: ${rootId} - children: ${children.length}, totalAmount: $${totalAmount}`)
      
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
    
    // ツリーを構築
    console.log(`\n=== ${userId}のツリー構築開始 ===`)
    const tree = buildTreeNode(userId)
    
    if (!tree) {
      console.log('ツリー構築失敗')
      return
    }
    
    console.log('\n=== 最終ツリー構造 ===')
    function printTree(node, depth = 0) {
      const indent = '  '.repeat(depth)
      console.log(`${indent}Lv.${node.level} ${node.user_id} (${node.email}) - $${node.personalInvestment}`)
      node.children.forEach(child => printTree(child, depth + 1))
    }
    
    printTree(tree)
    
  } catch (error) {
    console.error('エラー:', error)
  }
}

debug7A9637Tree()