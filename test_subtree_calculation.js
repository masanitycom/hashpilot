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

async function testSubtreeCalculation() {
  console.log('\n' + '='.repeat(100))
  console.log('紹介ツリーの下位合計計算問題を検証')
  console.log('='.repeat(100) + '\n')
  
  // 773AC7の紹介ツリーを取得
  const userId = '773AC7'
  console.log(`テストユーザー: ${userId}\n`)
  
  // SQL関数の結果を確認
  console.log('【SQL関数 get_referral_tree の結果】')
  try {
    const { data: treeResult, error } = await supabase.rpc('get_referral_tree', {
      root_user_id: userId
    })
    
    if (error) {
      console.log('SQL関数エラー:', error)
    } else if (treeResult) {
      console.log(`ノード数: ${treeResult.length}\n`)
      
      // 問題のあるユーザーを探す
      const problematicUsers = ['892389', '840D16']
      
      problematicUsers.forEach(problemUserId => {
        const node = treeResult.find(n => n.user_id === problemUserId)
        if (node) {
          console.log(`${problemUserId}:`)
          console.log(`  Level: ${node.level_num}`)
          console.log(`  個人購入: $${node.personal_purchases}`)
          console.log(`  下位合計: $${node.subtree_total} ← ここが問題！`)
          console.log('')
        }
      })
    }
  } catch (err) {
    console.log('SQL関数呼び出しエラー:', err.message)
  }
  
  // 正しい計算を実装
  console.log('\n【正しい下位合計の計算】')
  
  // 全ユーザーデータを取得
  const { data: allUsers } = await supabase
    .from('users')
    .select('user_id, email, total_purchases, referrer_user_id')
    .order('created_at', { ascending: true })
  
  // 再帰的に下位合計を計算
  function calculateSubtreeTotal(userId, processed = new Set()) {
    if (processed.has(userId)) return 0
    processed.add(userId)
    
    // このユーザーの直接紹介者を取得
    const directReferrals = allUsers.filter(u => u.referrer_user_id === userId)
    
    let subtreeTotal = 0
    
    for (const referral of directReferrals) {
      // この紹介者の個人投資額
      const personalInvestment = Math.floor(referral.total_purchases / 1100) * 1000
      subtreeTotal += personalInvestment
      
      // この紹介者の下位合計を再帰的に計算
      const referralSubtree = calculateSubtreeTotal(referral.user_id, processed)
      subtreeTotal += referralSubtree
    }
    
    return subtreeTotal
  }
  
  // 問題のユーザーの正しい下位合計を計算
  const problematicUsers = ['892389', '840D16']
  
  problematicUsers.forEach(problemUserId => {
    const user = allUsers.find(u => u.user_id === problemUserId)
    if (user) {
      const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
      const subtreeTotal = calculateSubtreeTotal(problemUserId)
      const total = personalInvestment + subtreeTotal
      
      console.log(`${problemUserId}:`)
      console.log(`  個人投資: $${personalInvestment}`)
      console.log(`  下位合計: $${subtreeTotal} ← 正しい値`)
      console.log(`  総合計: $${total}`)
      console.log('')
    }
  })
  
  // 773AC7から見た全体構造を確認
  console.log('\n【773AC7から見た紹介ツリー構造】')
  
  function buildTree(rootId, level = 1, processed = new Set()) {
    if (processed.has(rootId) || level > 5) return // 5レベルまで表示
    processed.add(rootId)
    
    const user = allUsers.find(u => u.user_id === rootId)
    if (!user) return
    
    const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
    const subtreeTotal = calculateSubtreeTotal(rootId, new Set())
    const total = personalInvestment + subtreeTotal
    
    const indent = '  '.repeat(level - 1)
    console.log(`${indent}${rootId}: 個人$${personalInvestment}, 下位$${subtreeTotal}, 合計$${total}`)
    
    // 直接紹介者を表示
    const directReferrals = allUsers.filter(u => u.referrer_user_id === rootId)
    directReferrals.forEach(ref => {
      buildTree(ref.user_id, level + 1, new Set(processed))
    })
  }
  
  buildTree(userId)
  
  console.log('\n【問題の原因】')
  console.log('SQL関数 get_referral_tree が下位合計（subtree_total）を正しく計算していない')
  console.log('各ノードの subtree_total は、そのノードの全ての下位ユーザーの投資額合計であるべき')
  console.log('しかし現在は $0 や間違った値が返されている')
}

testSubtreeCalculation().catch(console.error)