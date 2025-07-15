// Simple profit calculation check using fetch
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8'

async function executeQuery(table, query, params = {}) {
  let url = `${supabaseUrl}/rest/v1/${table}?${query}`
  
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

async function investigateProfit() {
  console.log('=== 利益計算調査 ===\n')
  
  try {
    // Get today's date
    const today = new Date().toISOString().split('T')[0]
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
    
    console.log('Query 1 - ユーザー 7A9637 の過去7日間の日利データ:')
    console.log('-'.repeat(80))
    
    const userProfitData = await executeQuery(
      'user_daily_profit',
      `user_id=eq.7A9637&date=gte.${sevenDaysAgo}&order=date.desc&select=*`
    )
    
    if (userProfitData.length > 0) {
      console.log('| 日付       | 日利     | 利率    | ユーザー利率 | 基準額   | 再計算利益 | 計算誤差  |')
      console.log('|------------|----------|---------|-------------|----------|------------|-----------|')
      
      for (const row of userProfitData) {
        const recalculated = row.base_amount * row.user_rate
        const error = row.daily_profit - recalculated
        
        console.log(`| ${row.date} | $${row.daily_profit.toFixed(2).padStart(7)} | ${(row.yield_rate * 100).toFixed(2)}% | ${(row.user_rate * 100).toFixed(2)}%     | $${row.base_amount.toFixed(0).padStart(7)} | $${recalculated.toFixed(2).padStart(9)} | $${error.toFixed(2).padStart(8)} |`)
      }
    } else {
      console.log('ユーザー 7A9637 のデータが見つかりません')
    }
    console.log('\n')

    console.log('Query 2 - 今日の利率設定:')
    console.log('-'.repeat(80))
    
    const yieldSettings = await executeQuery(
      'daily_yield_log',
      `date=eq.${today}&order=created_at.desc&select=*`
    )
    
    if (yieldSettings.length > 0) {
      console.log('| 日付       | 利率    | マージン率 | ユーザー利率 | 月末処理 |')
      console.log('|------------|---------|------------|-------------|----------|')
      
      for (const row of yieldSettings) {
        const afterMargin = row.yield_rate * (1 - row.margin_rate / 100)
        const calculatedUserRate = afterMargin * 0.6
        
        console.log(`| ${row.date} | ${(row.yield_rate * 100).toFixed(2)}% | ${row.margin_rate.toFixed(1)}%      | ${(row.user_rate * 100).toFixed(2)}%     | ${row.is_month_end ? 'Yes' : 'No'}      |`)
        console.log(`| 計算: マージン後=${(afterMargin * 100).toFixed(2)}%, 計算ユーザー利率=${(calculatedUserRate * 100).toFixed(2)}%`)
      }
    } else {
      console.log('今日の利率設定が見つかりません')
    }
    console.log('\n')

    console.log('Query 3 - 今日処理された全ユーザーの計算確認 (上位10件):')
    console.log('-'.repeat(100))
    
    const todayUsers = await executeQuery(
      'user_daily_profit',
      `date=eq.${today}&order=daily_profit.desc&limit=10&select=*`
    )
    
    if (todayUsers.length > 0) {
      console.log('| ユーザーID | 日利     | 利率    | ユーザー利率 | 基準額   | 計算値     | 誤差     | ステータス |')
      console.log('|------------|----------|---------|-------------|----------|------------|----------|------------|')
      
      for (const row of todayUsers) {
        const shouldBeProfit = row.base_amount * row.user_rate
        const errorAmount = row.daily_profit - shouldBeProfit
        const status = Math.abs(errorAmount) < 0.01 ? 'Correct' : 'Error'
        
        console.log(`| ${row.user_id.padEnd(10)} | $${row.daily_profit.toFixed(2).padStart(7)} | ${(row.yield_rate * 100).toFixed(2)}% | ${(row.user_rate * 100).toFixed(2)}%     | $${row.base_amount.toFixed(0).padStart(7)} | $${shouldBeProfit.toFixed(2).padStart(9)} | $${errorAmount.toFixed(2).padStart(7)} | ${status.padEnd(8)} |`)
      }
    } else {
      console.log('今日処理されたユーザーデータが見つかりません')
    }
    console.log('\n')

    console.log('Query 4 - ユーザー 7A9637 のサイクルデータ:')
    console.log('-'.repeat(80))
    
    const cycleData = await executeQuery(
      'affiliate_cycle',
      `user_id=eq.7A9637&select=*`
    )
    
    if (cycleData.length > 0) {
      const row = cycleData[0]
      console.log(`ユーザーID: ${row.user_id}`)
      console.log(`総NFT数: ${row.total_nft_count}`)
      console.log(`手動NFT数: ${row.manual_nft_count}`)
      console.log(`自動NFT数: ${row.auto_nft_count}`)
      console.log(`累積USDT: $${row.cum_usdt}`)
      console.log(`利用可能USDT: $${row.available_usdt}`)
      console.log(`次のアクション: ${row.next_action}`)
      console.log(`更新時刻: ${row.updated_at}`)
    } else {
      console.log('ユーザー 7A9637 のサイクルデータが見つかりません')
    }
    console.log('\n')

    // Summary
    console.log('=== 総合統計 ===')
    const totalToday = await executeQuery(
      'user_daily_profit',
      `date=eq.${today}&select=daily_profit`
    )
    
    if (totalToday.length > 0) {
      const totalSum = totalToday.reduce((sum, row) => sum + row.daily_profit, 0)
      console.log(`本日処理されたユーザー数: ${totalToday.length}`)
      console.log(`本日の総利益配布額: $${totalSum.toFixed(2)}`)
    } else {
      console.log('本日のデータが見つかりません')
    }

  } catch (error) {
    console.error('エラー発生:', error.message)
  }
}

investigateProfit()