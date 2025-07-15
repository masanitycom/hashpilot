// Deep investigation of the database state
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8'

async function executeQuery(table, query = '') {
  let url = `${supabaseUrl}/rest/v1/${table}`
  if (query) url += `?${query}`
  
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${supabaseKey}`,
      'apikey': supabaseKey,
      'Content-Type': 'application/json'
    }
  })
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }
  
  return await response.json()
}

async function deepInvestigation() {
  console.log('=== データベース深度調査 ===\n')
  
  try {
    console.log('1. 全テーブルのユーザーデータ確認:')
    console.log('-'.repeat(60))
    
    // Check users table
    const allUsers = await executeQuery('users', 'select=user_id,email,total_purchases,has_approved_nft&order=total_purchases.desc&limit=10')
    console.log(`users テーブル: ${allUsers.length} ユーザー`)
    
    if (allUsers.length > 0) {
      console.log('| ユーザーID | メール              | 購入額    | NFT承認 |')
      console.log('|------------|---------------------|-----------|---------|')
      for (const user of allUsers) {
        console.log(`| ${user.user_id.padEnd(10)} | ${user.email.padEnd(19)} | $${user.total_purchases.toString().padStart(8)} | ${user.has_approved_nft ? 'Yes' : 'No'}     |`)
      }
    }
    console.log('')
    
    // Check purchases table
    const allPurchases = await executeQuery('purchases', 'select=user_id,nft_quantity,amount_usd,admin_approved&order=created_at.desc&limit=10')
    console.log(`purchases テーブル: ${allPurchases.length} 購入記録`)
    
    if (allPurchases.length > 0) {
      console.log('| ユーザーID | NFT数量 | 金額      | 承認済み |')
      console.log('|------------|---------|-----------|----------|')
      for (const purchase of allPurchases) {
        console.log(`| ${purchase.user_id.padEnd(10)} | ${purchase.nft_quantity.toString().padStart(7)} | $${purchase.amount_usd.padStart(8)} | ${purchase.admin_approved ? 'Yes' : 'No'}      |`)
      }
    }
    console.log('')
    
    console.log('2. サイクル処理が実行されているかの確認:')
    console.log('-'.repeat(60))
    
    // Check system_logs for cycle processing
    const systemLogs = await executeQuery('system_logs', 'select=*&order=created_at.desc&limit=10')
    console.log(`system_logs テーブル: ${systemLogs.length} ログエントリー`)
    
    if (systemLogs.length > 0) {
      console.log('最新ログ:')
      for (const log of systemLogs.slice(0, 5)) {
        console.log(`- ${log.created_at}: [${log.log_type}] ${log.operation} - ${log.message}`)
      }
    }
    console.log('')
    
    console.log('3. 日利設定の詳細確認:')
    console.log('-'.repeat(60))
    
    const detailedYieldLog = await executeQuery('daily_yield_log', 'select=*&order=date.desc&limit=5')
    
    if (detailedYieldLog.length > 0) {
      for (const row of detailedYieldLog) {
        console.log(`日付: ${row.date}`)
        console.log(`  基本利率: ${(row.yield_rate * 100).toFixed(3)}%`)
        console.log(`  マージン率: ${row.margin_rate}%`)
        console.log(`  計算後ユーザー利率: ${(row.user_rate * 100).toFixed(3)}%`)
        console.log(`  月末処理: ${row.is_month_end}`)
        console.log(`  作成時刻: ${row.created_at}`)
        
        // Calculate what user rate should be
        const afterMargin = row.yield_rate * (1 - row.margin_rate / 100)
        const expectedUserRate = afterMargin * 0.6
        
        console.log(`  期待値計算:`)
        console.log(`    マージン後利率: ${(afterMargin * 100).toFixed(3)}%`)
        console.log(`    期待ユーザー利率: ${(expectedUserRate * 100).toFixed(3)}%`)
        console.log(`    実際との差: ${((row.user_rate - expectedUserRate) * 100).toFixed(3)}%`)
        console.log('')
      }
    }
    
    console.log('4. アクティブユーザー（NFT承認済み）の確認:')
    console.log('-'.repeat(60))
    
    const activeUsers = await executeQuery('users', 'has_approved_nft=eq.true&select=user_id,total_purchases')
    console.log(`NFT承認済みユーザー数: ${activeUsers.length}`)
    
    if (activeUsers.length > 0) {
      const totalInvestment = activeUsers.reduce((sum, user) => sum + user.total_purchases, 0)
      console.log(`総投資額: $${totalInvestment.toFixed(2)}`)
      console.log(`平均投資額: $${(totalInvestment / activeUsers.length).toFixed(2)}`)
      
      // Show top investors
      const topInvestors = activeUsers.sort((a, b) => b.total_purchases - a.total_purchases).slice(0, 5)
      console.log('\n上位投資者:')
      for (const user of topInvestors) {
        console.log(`  ${user.user_id}: $${user.total_purchases}`)
      }
    }
    console.log('')
    
    console.log('5. 推定原因分析:')
    console.log('-'.repeat(60))
    
    if (allUsers.length === 0) {
      console.log('❌ ユーザーデータが存在しない')
    } else if (activeUsers.length === 0) {
      console.log('❌ NFT承認済みユーザーが存在しない')
    } else if (systemLogs.filter(log => log.operation.includes('daily')).length === 0) {
      console.log('❌ 日次処理ログが見つからない')
    } else {
      console.log('⚠️  データは存在するが、サイクル処理が動作していない可能性')
    }
    
    // Check if any batch processing occurred
    const batchLogs = systemLogs.filter(log => 
      log.operation.includes('daily') || 
      log.operation.includes('batch') || 
      log.operation.includes('yield')
    )
    
    if (batchLogs.length > 0) {
      console.log('\nバッチ処理関連ログ:')
      for (const log of batchLogs.slice(0, 3)) {
        console.log(`  ${log.created_at}: ${log.operation} - ${log.message}`)
      }
    } else {
      console.log('\n❌ バッチ処理が実行されていない')
    }

  } catch (error) {
    console.error('調査中にエラー:', error.message)
  }
}

deepInvestigation()