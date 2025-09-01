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

async function explainTruncationLoss() {
  console.log(`\n${'='.repeat(100)}`)
  console.log(`「切り捨て分が見えない」の詳細説明`)
  console.log(`${'='.repeat(100)}\n`)
  
  // 全ユーザーの購入データを取得
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, total_purchases')
    .gt('total_purchases', 0)
    .order('total_purchases', { ascending: false })
  
  if (error) {
    console.error('エラー:', error)
    return
  }
  
  console.log('【NFT価格とシステムの関係】')
  console.log('- NFT価格: $1,100')
  console.log('- 運用額: $1,000（NFT 1個あたり）')
  console.log('- 手数料/その他: $100（NFT 1個あたり）')
  
  console.log('\n【運用額計算の仕組み】')
  console.log('運用額 = Math.floor(購入額 ÷ 1100) × 1000')
  console.log('つまり、NFT個数 × $1,000')
  
  console.log('\n【具体例で理解する「切り捨て分」】')
  
  // 様々な購入額での例
  const examples = [
    1100, 2200, 3300, 4400, 5500, 6600, 11000, 23100
  ]
  
  examples.forEach(purchase => {
    const nftCount = Math.floor(purchase / 1100)
    const operational = nftCount * 1000
    const truncated = purchase - operational
    
    console.log(`購入額$${purchase.toLocaleString()}:`)
    console.log(`  → NFT ${nftCount}個`)
    console.log(`  → 運用額: $${operational.toLocaleString()}`)
    console.log(`  → 切り捨て: $${truncated} ${truncated > 0 ? '⚠️' : '✅'}`)
    console.log('')
  })
  
  console.log('【実際のユーザーデータでの切り捨て例】')
  
  // 実ユーザーでの切り捨て例
  const truncationExamples = allUsers
    .map(u => ({
      user_id: u.user_id,
      email: u.email,
      purchase: u.total_purchases,
      nftCount: Math.floor(u.total_purchases / 1100),
      operational: Math.floor(u.total_purchases / 1100) * 1000,
      truncated: u.total_purchases - Math.floor(u.total_purchases / 1100) * 1000
    }))
    .filter(u => u.truncated > 0)
    .sort((a, b) => b.truncated - a.truncated)
  
  console.log(`\n切り捨てが発生しているユーザー: ${truncationExamples.length}人`)
  console.log('\nTOP10の切り捨て額:')
  
  truncationExamples.slice(0, 10).forEach((u, i) => {
    console.log(`${i + 1}. ${u.user_id}:`)
    console.log(`   購入額: $${u.purchase.toLocaleString()} → 運用額: $${u.operational.toLocaleString()}`)
    console.log(`   切り捨て: $${u.truncated} (NFT ${u.nftCount}個)`)
    console.log('')
  })
  
  // 総切り捨て額
  const totalTruncated = truncationExamples.reduce((sum, u) => sum + u.truncated, 0)
  const totalPurchases = allUsers.reduce((sum, u) => sum + u.total_purchases, 0)
  const totalOperational = allUsers.reduce((sum, u) => sum + Math.floor(u.total_purchases / 1100) * 1000, 0)
  
  console.log('【システム全体での切り捨て影響】')
  console.log(`実購入額合計: $${totalPurchases.toLocaleString()}`)
  console.log(`運用額合計: $${totalOperational.toLocaleString()}`)
  console.log(`総切り捨て額: $${totalTruncated.toLocaleString()}`)
  console.log(`切り捨て率: ${((totalTruncated / totalPurchases) * 100).toFixed(2)}%`)
  
  console.log('\n' + '='.repeat(80))
  console.log('【A案のデメリット「切り捨て分が見えない」の意味】')
  console.log('='.repeat(80))
  
  console.log('\n❌ A案（運用額表示）の問題:')
  console.log('- 表示: $247,000（運用額）')
  console.log('- 実際の投資額: $271,700')
  console.log('- 見えない金額: $24,700（8.3%）')
  console.log('- ユーザーは実際より少ない投資額しか見えない')
  
  console.log('\n✅ B案（実購入額表示）の利点:')
  console.log('- 表示: $271,700（実購入額）')
  console.log('- ユーザーが実際に投資した金額が正確に表示される')
  console.log('- 透明性が高い')
  
  console.log('\n【ビジネス的な観点】')
  console.log('A案を選ぶと:')
  console.log('- ユーザーが「$24,700も投資したのに表示されない」と感じる可能性')
  console.log('- 投資実績が実際より低く見える')
  console.log('- NFTの購入を促進する情報が隠れる')
  
  console.log('\nB案を選ぶと:')
  console.log('- ユーザーの投資実績が正確に表示される')
  console.log('- 投資額が大きく見えるため、満足度が高い')
  console.log('- 透明性が高く、信頼性向上')
  
  console.log('\n【推奨】')
  console.log('🎯 B案（実購入額$271,700）を推奨します')
  console.log('理由:')
  console.log('1. ユーザーの実投資額を正確に反映')
  console.log('2. 切り捨てによる「見えない投資」問題を解決')
  console.log('3. システムの透明性向上')
  console.log('4. ユーザーの満足度向上（より大きな投資額表示）')
}

explainTruncationLoss().catch(console.error)