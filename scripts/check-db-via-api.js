// データベース状況確認用のスクリプト
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.com'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5MDY5MjUsImV4cCI6MjA1MTQ4MjkyNX0.vLfD7DqcaTGcJCE0Dg4m9Z3KVrsUVGFQrMQ8KJc7-Qw'

const supabase = createClient(supabaseUrl, supabaseKey)

async function checkDatabaseStatus() {
  console.log('=== データベース状況確認 ===\n')

  try {
    // 1. user_daily_profitテーブルの確認
    console.log('1. user_daily_profit テーブル確認:')
    const { data: profitStats, error: profitError } = await supabase
      .from('user_daily_profit')
      .select('date, daily_profit')
    
    if (profitError) {
      console.error('  エラー:', profitError.message)
    } else {
      console.log(`  総レコード数: ${profitStats?.length || 0}`)
      if (profitStats && profitStats.length > 0) {
        const totalProfit = profitStats.reduce((sum, row) => sum + (row.daily_profit || 0), 0)
        const dates = profitStats.map(row => row.date).sort()
        console.log(`  期間: ${dates[0]} ～ ${dates[dates.length - 1]}`)
        console.log(`  総利益: $${totalProfit.toFixed(3)}`)
      }
    }
    console.log('')

    // 2. 投資額$1000以上のユーザーの利益状況
    console.log('2. 投資額$1000以上のユーザーの利益状況:')
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('user_id, total_purchases')
      .gte('total_purchases', 1000)
      .order('total_purchases', { ascending: false })
      .limit(5)

    if (usersError) {
      console.error('  エラー:', usersError.message)
    } else {
      for (const user of users || []) {
        const { data: userProfits } = await supabase
          .from('user_daily_profit')
          .select('daily_profit')
          .eq('user_id', user.user_id)
        
        const totalUserProfit = userProfits?.reduce((sum, p) => sum + (p.daily_profit || 0), 0) || 0
        console.log(`  ユーザー ${user.user_id}: 投資額$${user.total_purchases} → 利益$${totalUserProfit.toFixed(3)} (${userProfits?.length || 0}日間)`)
      }
    }
    console.log('')

    // 3. affiliate_cycleテーブルの確認
    console.log('3. affiliate_cycle テーブル確認:')
    const { data: cycleData, error: cycleError } = await supabase
      .from('affiliate_cycle')
      .select('user_id, total_nft_count')

    if (cycleError) {
      console.error('  エラー:', cycleError.message)
    } else {
      const totalUsers = cycleData?.length || 0
      const usersWithNFTs = cycleData?.filter(u => u.total_nft_count > 0).length || 0
      const totalNFTs = cycleData?.reduce((sum, u) => sum + (u.total_nft_count || 0), 0) || 0
      console.log(`  総ユーザー数: ${totalUsers}`)
      console.log(`  NFT保有ユーザー数: ${usersWithNFTs}`)
      console.log(`  総NFT数: ${totalNFTs}`)
    }
    console.log('')

    // 4. purchasesテーブルの確認
    console.log('4. purchases テーブル確認:')
    const { data: purchases, error: purchasesError } = await supabase
      .from('purchases')
      .select('nft_quantity, amount_usd, admin_approved')

    if (purchasesError) {
      console.error('  エラー:', purchasesError.message)
    } else {
      const totalPurchases = purchases?.length || 0
      const approvedPurchases = purchases?.filter(p => p.admin_approved).length || 0
      const totalNFTPurchased = purchases?.reduce((sum, p) => sum + (p.nft_quantity || 0), 0) || 0
      const totalAmount = purchases?.reduce((sum, p) => sum + parseFloat(p.amount_usd || '0'), 0) || 0
      console.log(`  総購入数: ${totalPurchases}`)
      console.log(`  承認済み購入数: ${approvedPurchases}`)
      console.log(`  購入NFT総数: ${totalNFTPurchased}`)
      console.log(`  総投資額: $${totalAmount.toFixed(2)}`)
    }
    console.log('')

    // 5. daily_yield_logテーブルの確認
    console.log('5. daily_yield_log テーブル確認:')
    const { data: yieldData, error: yieldError } = await supabase
      .from('daily_yield_log')
      .select('date, yield_rate, user_rate')
      .order('date', { ascending: false })

    if (yieldError) {
      console.error('  エラー:', yieldError.message)
    } else {
      console.log(`  日利設定数: ${yieldData?.length || 0}`)
      if (yieldData && yieldData.length > 0) {
        const latestYield = yieldData[0]
        console.log(`  最新設定日: ${latestYield.date}`)
        console.log(`  最新日利率: ${(latestYield.yield_rate * 100).toFixed(3)}%`)
        console.log(`  最新ユーザー利率: ${(latestYield.user_rate * 100).toFixed(3)}%`)
      }
    }
    console.log('')

    // 6. 昨日のデータ確認
    console.log('6. 昨日のデータ確認:')
    const yesterday = new Date()
    yesterday.setDate(yesterday.getDate() - 1)
    const yesterdayStr = yesterday.toISOString().split('T')[0]
    
    const { data: yesterdayData, error: yesterdayError } = await supabase
      .from('user_daily_profit')
      .select('user_id, daily_profit')
      .eq('date', yesterdayStr)

    if (yesterdayError) {
      console.error('  エラー:', yesterdayError.message)
    } else {
      console.log(`  昨日(${yesterdayStr})の利益データ: ${yesterdayData?.length || 0}ユーザー`)
      if (yesterdayData && yesterdayData.length > 0) {
        const totalYesterdayProfit = yesterdayData.reduce((sum, p) => sum + (p.daily_profit || 0), 0)
        console.log(`  昨日の総利益: $${totalYesterdayProfit.toFixed(3)}`)
      }
    }

  } catch (error) {
    console.error('データベース確認中にエラーが発生:', error)
  }
}

checkDatabaseStatus()