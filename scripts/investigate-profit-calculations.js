// 利益計算不一致調査用スクリプト
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.com'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5MDY5MjUsImV4cCI6MjA1MTQ4MjkyNX0.vLfD7DqcaTGcJCE0Dg4m9Z3KVrsUVGFQrMQ8KJc7-Qw'

const supabase = createClient(supabaseUrl, supabaseKey)

async function investigateProfitCalculations() {
  console.log('=== 利益計算不一致調査 ===\n')

  try {
    // Query 1 - Check user 7A9637's daily profit data
    console.log('Query 1 - ユーザー 7A9637 の日利データ確認:')
    console.log('-'.repeat(80))
    
    const { data: userProfitData, error: query1Error } = await supabase.rpc('execute_sql', {
      sql_query: `
        SELECT 
            user_id,
            date,
            daily_profit,
            yield_rate,
            user_rate,
            base_amount,
            phase,
            created_at,
            base_amount * user_rate as recalculated_profit,
            daily_profit - (base_amount * user_rate) as calculation_error
        FROM user_daily_profit 
        WHERE user_id = '7A9637'
            AND date >= CURRENT_DATE - INTERVAL '7 days'
        ORDER BY date DESC
      `
    })

    if (query1Error) {
      // Fallback to direct table query if RPC doesn't exist
      console.log('RPCが利用できないため、直接クエリを使用します...')
      
      const { data: fallbackData, error: fallbackError } = await supabase
        .from('user_daily_profit')
        .select('user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at')
        .eq('user_id', '7A9637')
        .gte('date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .order('date', { ascending: false })

      if (fallbackError) {
        console.error('エラー:', fallbackError.message)
      } else {
        console.log('| 日付       | 日利     | 利率    | ユーザー利率 | 基準額   | 再計算利益 | 計算誤差  |')
        console.log('|------------|----------|---------|-------------|----------|------------|-----------|')
        
        for (const row of fallbackData || []) {
          const recalculated = row.base_amount * row.user_rate
          const error = row.daily_profit - recalculated
          
          console.log(`| ${row.date} | $${row.daily_profit.toFixed(2).padStart(7)} | ${(row.yield_rate * 100).toFixed(2)}% | ${(row.user_rate * 100).toFixed(2)}%     | $${row.base_amount.toFixed(0).padStart(7)} | $${recalculated.toFixed(2).padStart(9)} | $${error.toFixed(2).padStart(8)} |`)
        }
      }
    } else {
      // Process RPC result
      if (userProfitData && userProfitData.length > 0) {
        console.log('| 日付       | 日利     | 利率    | ユーザー利率 | 基準額   | 再計算利益 | 計算誤差  |')
        console.log('|------------|----------|---------|-------------|----------|------------|-----------|')
        
        for (const row of userProfitData) {
          console.log(`| ${row.date} | $${row.daily_profit.toFixed(2).padStart(7)} | ${(row.yield_rate * 100).toFixed(2)}% | ${(row.user_rate * 100).toFixed(2)}%     | $${row.base_amount.toFixed(0).padStart(7)} | $${row.recalculated_profit.toFixed(2).padStart(9)} | $${row.calculation_error.toFixed(2).padStart(8)} |`)
        }
      }
    }
    console.log('\n')

    // Query 2 - Check today's yield settings
    console.log('Query 2 - 今日の利率設定確認:')
    console.log('-'.repeat(80))
    
    const today = new Date().toISOString().split('T')[0]
    const { data: yieldSettings, error: query2Error } = await supabase
      .from('daily_yield_log')
      .select('date, yield_rate, margin_rate, user_rate, is_month_end, created_at')
      .eq('date', today)
      .order('created_at', { ascending: false })

    if (query2Error) {
      console.error('エラー:', query2Error.message)
    } else {
      console.log('| 日付       | 利率    | マージン率 | ユーザー利率 | 月末処理 | 作成時刻          |')
      console.log('|------------|---------|------------|-------------|----------|-------------------|')
      
      for (const row of yieldSettings || []) {
        const afterMargin = row.yield_rate * (1 - row.margin_rate / 100)
        const calculatedUserRate = afterMargin * 0.6
        
        console.log(`| ${row.date} | ${(row.yield_rate * 100).toFixed(2)}% | ${row.margin_rate.toFixed(1)}%      | ${(row.user_rate * 100).toFixed(2)}%     | ${row.is_month_end ? 'Yes' : 'No'}      | ${row.created_at} |`)
        console.log(`|            | 計算値: マージン後=${(afterMargin * 100).toFixed(2)}%, ユーザー利率=${(calculatedUserRate * 100).toFixed(2)}%`)
      }
    }
    console.log('\n')

    // Query 3 - Check all users processed today
    console.log('Query 3 - 本日処理された全ユーザーの計算確認 (上位10件):')
    console.log('-'.repeat(100))
    
    const { data: todayUsers, error: query3Error } = await supabase
      .from('user_daily_profit')
      .select('user_id, daily_profit, yield_rate, user_rate, base_amount')
      .eq('date', today)
      .limit(10)
      .order('daily_profit', { ascending: false })

    if (query3Error) {
      console.error('エラー:', query3Error.message)
    } else {
      console.log('| ユーザーID | 日利     | 利率    | ユーザー利率 | 基準額   | 計算値     | 誤差     | ステータス |')
      console.log('|------------|----------|---------|-------------|----------|------------|----------|------------|')
      
      for (const row of todayUsers || []) {
        const shouldBeProfit = row.base_amount * row.user_rate
        const errorAmount = row.daily_profit - shouldBeProfit
        const status = Math.abs(errorAmount) < 0.01 ? 'Correct' : 'Error'
        
        console.log(`| ${row.user_id.padEnd(10)} | $${row.daily_profit.toFixed(2).padStart(7)} | ${(row.yield_rate * 100).toFixed(2)}% | ${(row.user_rate * 100).toFixed(2)}%     | $${row.base_amount.toFixed(0).padStart(7)} | $${shouldBeProfit.toFixed(2).padStart(9)} | $${errorAmount.toFixed(2).padStart(7)} | ${status.padEnd(8)} |`)
      }
    }
    console.log('\n')

    // Query 4 - Check user 7A9637's cycle data
    console.log('Query 4 - ユーザー 7A9637 のサイクルデータ確認:')
    console.log('-'.repeat(80))
    
    const { data: cycleData, error: query4Error } = await supabase
      .from('affiliate_cycle')
      .select('user_id, total_nft_count, manual_nft_count, auto_nft_count, cum_usdt, available_usdt, next_action, updated_at')
      .eq('user_id', '7A9637')

    if (query4Error) {
      console.error('エラー:', query4Error.message)
    } else {
      for (const row of cycleData || []) {
        console.log(`ユーザーID: ${row.user_id}`)
        console.log(`総NFT数: ${row.total_nft_count}`)
        console.log(`手動NFT数: ${row.manual_nft_count}`)
        console.log(`自動NFT数: ${row.auto_nft_count}`)
        console.log(`累積USDT: $${row.cum_usdt}`)
        console.log(`利用可能USDT: $${row.available_usdt}`)
        console.log(`次のアクション: ${row.next_action}`)
        console.log(`更新時刻: ${row.updated_at}`)
      }
    }

    // Summary statistics
    console.log('\n=== 総合統計 ===')
    
    const { data: totalUsers, error: totalError } = await supabase
      .from('user_daily_profit')
      .select('user_id', { count: 'exact', head: true })
      .eq('date', today)

    if (!totalError) {
      console.log(`本日処理されたユーザー数: ${totalUsers.length || 0}`)
    }

    const { data: totalProfit, error: profitError } = await supabase
      .from('user_daily_profit')
      .select('daily_profit')
      .eq('date', today)

    if (!profitError && totalProfit) {
      const sum = totalProfit.reduce((acc, row) => acc + row.daily_profit, 0)
      console.log(`本日の総利益配布額: $${sum.toFixed(2)}`)
    }

  } catch (error) {
    console.error('調査中にエラーが発生:', error)
  }
}

investigateProfitCalculations()