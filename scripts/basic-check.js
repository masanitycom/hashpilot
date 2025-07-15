// Basic database connectivity check
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
  
  console.log(`Query to ${table}: ${response.status} ${response.statusText}`)
  
  if (!response.ok) {
    const errorText = await response.text()
    console.log(`Error response: ${errorText}`)
    return null
  }
  
  return await response.json()
}

async function basicCheck() {
  console.log('=== 基本接続確認 ===\n')
  
  const tables = [
    'users',
    'purchases', 
    'user_daily_profit',
    'affiliate_cycle',
    'daily_yield_log',
    'system_logs'
  ]
  
  for (const table of tables) {
    console.log(`${table} テーブル確認:`)
    
    try {
      const data = await executeQuery(table, 'select=*&limit=1')
      
      if (data === null) {
        console.log('  ❌ アクセス拒否またはエラー')
      } else if (data.length === 0) {
        console.log('  ✅ アクセス可能、データなし')
      } else {
        console.log('  ✅ アクセス可能、データあり')
        console.log(`  カラム: ${Object.keys(data[0]).join(', ')}`)
      }
    } catch (error) {
      console.log(`  ❌ エラー: ${error.message}`)
    }
    
    console.log('')
  }
  
  // Check daily_yield_log in detail since it has data
  console.log('=== daily_yield_log 詳細 ===')
  try {
    const yieldData = await executeQuery('daily_yield_log', 'select=*&order=date.desc')
    
    if (yieldData && yieldData.length > 0) {
      console.log(`総レコード数: ${yieldData.length}`)
      console.log('\n全データ:')
      console.log('| 日付       | 利率      | マージン率 | ユーザー利率 | 月末 | 作成時刻          |')
      console.log('|------------|-----------|------------|-------------|------|-------------------|')
      
      for (const row of yieldData) {
        console.log(`| ${row.date} | ${(row.yield_rate * 100).toFixed(3)}% | ${row.margin_rate.toFixed(1)}%      | ${(row.user_rate * 100).toFixed(3)}%    | ${row.is_month_end ? 'Y' : 'N'}  | ${row.created_at.substring(0, 19)} |`)
      }
      
      console.log('\n計算検証:')
      for (const row of yieldData) {
        const afterMargin = row.yield_rate * (1 - row.margin_rate / 100)
        const expectedUserRate = afterMargin * 0.6
        const difference = Math.abs(row.user_rate - expectedUserRate)
        
        console.log(`${row.date}:`)
        console.log(`  入力利率: ${(row.yield_rate * 100).toFixed(3)}%`)
        console.log(`  マージン率: ${row.margin_rate}%`)
        console.log(`  マージン後: ${(afterMargin * 100).toFixed(3)}%`)
        console.log(`  期待ユーザー利率: ${(expectedUserRate * 100).toFixed(3)}%`)
        console.log(`  実際ユーザー利率: ${(row.user_rate * 100).toFixed(3)}%`)
        console.log(`  差異: ${(difference * 100).toFixed(3)}% ${difference > 0.001 ? '❌' : '✅'}`)
        console.log('')
      }
    }
  } catch (error) {
    console.log(`エラー: ${error.message}`)
  }
}

basicCheck()