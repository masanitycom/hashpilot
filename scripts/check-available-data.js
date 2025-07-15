// Check what data is actually available in the database
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

async function checkAvailableData() {
  console.log('=== データベース利用可能データ確認 ===\n')
  
  try {
    // Check user_daily_profit table
    console.log('1. user_daily_profit テーブル:')
    const profitData = await executeQuery('user_daily_profit', 'order=date.desc&limit=10&select=user_id,date,daily_profit,yield_rate,user_rate,base_amount')
    
    if (profitData.length > 0) {
      console.log(`総レコード数（最新10件を表示）:`)
      console.log('| ユーザーID | 日付       | 日利     | 利率    | ユーザー利率 | 基準額   |')
      console.log('|------------|------------|----------|---------|-------------|----------|')
      
      for (const row of profitData) {
        console.log(`| ${row.user_id.padEnd(10)} | ${row.date} | $${row.daily_profit.toFixed(2).padStart(7)} | ${(row.yield_rate * 100).toFixed(2)}% | ${(row.user_rate * 100).toFixed(2)}%     | $${row.base_amount.toFixed(0).padStart(7)} |`)
      }
      
      // Get date range
      const allDates = await executeQuery('user_daily_profit', 'select=date&order=date.desc')
      if (allDates.length > 0) {
        const dates = [...new Set(allDates.map(d => d.date))].sort()
        console.log(`\n期間: ${dates[0]} ～ ${dates[dates.length - 1]}`)
        console.log(`利用可能な日付数: ${dates.length}`)
      }
    } else {
      console.log('データなし')
    }
    console.log('\n')

    // Check daily_yield_log table
    console.log('2. daily_yield_log テーブル:')
    const yieldLog = await executeQuery('daily_yield_log', 'order=date.desc&limit=5&select=*')
    
    if (yieldLog.length > 0) {
      console.log('| 日付       | 利率    | マージン率 | ユーザー利率 | 月末処理 |')
      console.log('|------------|---------|------------|-------------|----------|')
      
      for (const row of yieldLog) {
        console.log(`| ${row.date} | ${(row.yield_rate * 100).toFixed(2)}% | ${row.margin_rate.toFixed(1)}%      | ${(row.user_rate * 100).toFixed(2)}%     | ${row.is_month_end ? 'Yes' : 'No'}      |`)
      }
    } else {
      console.log('データなし')
    }
    console.log('\n')

    // Check affiliate_cycle table
    console.log('3. affiliate_cycle テーブル:')
    const cycleData = await executeQuery('affiliate_cycle', 'limit=10&select=user_id,total_nft_count,cum_usdt,available_usdt,next_action')
    
    if (cycleData.length > 0) {
      console.log('| ユーザーID | NFT数 | 累積USDT | 利用可能USDT | 次のアクション |')
      console.log('|------------|-------|----------|-------------|----------------|')
      
      for (const row of cycleData) {
        console.log(`| ${row.user_id.padEnd(10)} | ${row.total_nft_count.toString().padStart(5)} | $${row.cum_usdt.toFixed(2).padStart(7)} | $${row.available_usdt.toFixed(2).padStart(10)} | ${row.next_action.padEnd(14)} |`)
      }
      
      // Check for specific user
      const user7A9637 = await executeQuery('affiliate_cycle', 'user_id=eq.7A9637&select=*')
      if (user7A9637.length > 0) {
        console.log(`\nユーザー 7A9637 のデータ:`)
        const u = user7A9637[0]
        console.log(`- NFT総数: ${u.total_nft_count}`)
        console.log(`- 累積USDT: $${u.cum_usdt}`)
        console.log(`- 利用可能USDT: $${u.available_usdt}`)
        console.log(`- 次のアクション: ${u.next_action}`)
      } else {
        console.log('\nユーザー 7A9637 のデータが見つかりません')
      }
    } else {
      console.log('データなし')
    }
    console.log('\n')

    // Check users table for user 7A9637
    console.log('4. users テーブル (ユーザー 7A9637):')
    const userData = await executeQuery('users', 'user_id=eq.7A9637&select=*')
    
    if (userData.length > 0) {
      const user = userData[0]
      console.log(`ユーザーID: ${user.user_id}`)
      console.log(`メール: ${user.email}`)
      console.log(`総購入額: $${user.total_purchases}`)
      console.log(`紹介者: ${user.referrer_user_id || 'なし'}`)
      console.log(`アクティブ: ${user.is_active}`)
      console.log(`NFT承認済み: ${user.has_approved_nft}`)
    } else {
      console.log('ユーザー 7A9637 が見つかりません')
    }
    console.log('\n')

    // Check purchases table
    console.log('5. purchases テーブル (ユーザー 7A9637):')
    const purchases = await executeQuery('purchases', 'user_id=eq.7A9637&select=*')
    
    if (purchases.length > 0) {
      console.log('| ID | NFT数量 | 金額(USD) | 支払い状況 | 管理者承認 | 作成日 |')
      console.log('|----|---------|-----------|------------|------------|--------|')
      
      for (const p of purchases) {
        console.log(`| ${p.id.toString().padEnd(2)} | ${p.nft_quantity.toString().padStart(7)} | $${p.amount_usd.padStart(8)} | ${p.payment_status.padEnd(10)} | ${p.admin_approved ? 'Yes' : 'No'.padEnd(8)} | ${p.created_at.split('T')[0]} |`)
      }
    } else {
      console.log('購入データなし')
    }
    console.log('\n')

    // Summary
    console.log('=== サマリー ===')
    const totalProfitRecords = await executeQuery('user_daily_profit', 'select=user_id')
    const totalUsers = await executeQuery('affiliate_cycle', 'select=user_id')
    
    console.log(`日利レコード総数: ${totalProfitRecords.length}`)
    console.log(`サイクル管理ユーザー数: ${totalUsers.length}`)
    
    // Check if any data exists for the last 7 days
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
    const recentProfit = await executeQuery('user_daily_profit', `date=gte.${sevenDaysAgo}&select=date,user_id`)
    
    if (recentProfit.length > 0) {
      const recentDates = [...new Set(recentProfit.map(d => d.date))].sort()
      console.log(`過去7日間のデータ: ${recentDates.join(', ')}`)
    } else {
      console.log('過去7日間のデータなし')
    }

  } catch (error) {
    console.error('エラー発生:', error.message)
  }
}

checkAvailableData()