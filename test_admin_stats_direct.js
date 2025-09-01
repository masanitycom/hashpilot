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

async function testAdminRPCFunctions() {
  const userId = '7A9637'
  console.log(`\n${'='.repeat(100)}`)
  console.log(`管理画面のRPC関数をテスト - ${userId}`)
  console.log(`${'='.repeat(100)}\n`)
  
  // get_referral_stats のテスト
  console.log('1. get_referral_stats RPC関数を呼び出し...')
  try {
    const { data: statsResult, error: statsError } = await supabase.rpc('get_referral_stats', {
      target_user_id: userId
    })
    
    if (statsError) {
      console.log('❌ get_referral_stats エラー:', statsError.message)
      console.log('   詳細:', statsError)
    } else {
      console.log('✅ get_referral_stats 成功:')
      console.log('   結果:', statsResult)
      
      if (statsResult && statsResult[0]) {
        const stats = statsResult[0]
        console.log('\n   【統計データ】')
        console.log(`   直接紹介: ${stats.total_direct_referrals}人`)
        console.log(`   間接紹介: ${stats.total_indirect_referrals}人`)
        console.log(`   総紹介人数: ${stats.total_direct_referrals + stats.total_indirect_referrals}人`)
        console.log(`   総購入額: $${stats.total_referral_purchases}`)
        console.log(`   最大深度: ${stats.max_tree_depth}`)
      }
    }
  } catch (err) {
    console.log('❌ get_referral_stats 例外:', err.message)
  }
  
  // get_referral_tree のテスト
  console.log('\n2. get_referral_tree RPC関数を呼び出し...')
  try {
    const { data: treeResult, error: treeError } = await supabase.rpc('get_referral_tree', {
      root_user_id: userId
    })
    
    if (treeError) {
      console.log('❌ get_referral_tree エラー:', treeError.message)
      console.log('   詳細:', treeError)
    } else {
      console.log('✅ get_referral_tree 成功:')
      console.log(`   ノード数: ${treeResult ? treeResult.length : 0}`)
      
      if (treeResult && treeResult.length > 0) {
        // レベル別に集計
        const levelCounts = new Map()
        const levelInvestments = new Map()
        
        treeResult.forEach(node => {
          const level = node.level_num || 1
          const investment = Math.floor((node.personal_purchases || 0) / 1100) * 1000
          
          levelCounts.set(level, (levelCounts.get(level) || 0) + 1)
          levelInvestments.set(level, (levelInvestments.get(level) || 0) + investment)
        })
        
        console.log('\n   【レベル別集計】')
        const sortedLevels = Array.from(levelCounts.keys()).sort((a, b) => a - b)
        let totalCount = 0
        let totalInvestment = 0
        
        sortedLevels.forEach(level => {
          const count = levelCounts.get(level)
          const investment = levelInvestments.get(level)
          totalCount += count
          totalInvestment += investment
          console.log(`   Level ${level}: ${count}人, $${investment}`)
        })
        
        console.log(`\n   【合計】`)
        console.log(`   総人数: ${totalCount}人`)
        console.log(`   総投資額: $${totalInvestment}`)
        
        // サンプルデータ表示
        console.log('\n   【サンプルデータ（最初の3件）】')
        treeResult.slice(0, 3).forEach(node => {
          console.log(`   - ${node.user_id} (Level ${node.level_num}): $${Math.floor((node.personal_purchases || 0) / 1100) * 1000}`)
        })
      }
    }
  } catch (err) {
    console.log('❌ get_referral_tree 例外:', err.message)
  }
  
  // SQL関数の存在確認
  console.log('\n3. SQL関数の存在確認...')
  try {
    const { data: functions, error: funcError } = await supabase.rpc('pg_proc', {})
      .select('proname')
      .ilike('proname', '%referral%')
    
    if (funcError) {
      console.log('関数リスト取得エラー（権限不足の可能性）')
    } else if (functions) {
      console.log('referral関連の関数:', functions)
    }
  } catch (err) {
    // 権限エラーの可能性が高い
    console.log('関数リスト取得不可（通常の動作）')
  }
  
  console.log('\n' + '='.repeat(100))
  console.log('結論:')
  console.log('- get_referral_stats と get_referral_tree が実装されている場合、その結果が表示されます')
  console.log('- エラーの場合、管理画面はfallback処理（Level 1-3のみ）を使用します')
  console.log('='.repeat(100))
}

testAdminRPCFunctions().catch(console.error)