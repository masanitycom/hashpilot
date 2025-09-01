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

async function findUsersWithManyReferrals() {
  console.log('多くの紹介者を持つユーザーを検索中...\n')
  
  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, total_purchases, referrer_user_id')
    .order('created_at', { ascending: true })
  
  if (error) {
    console.error('ユーザーデータ取得エラー:', error)
    return
  }
  
  // 各ユーザーの紹介者数をカウント
  const referralCounts = new Map()
  
  for (const user of allUsers) {
    const directReferrals = allUsers.filter(u => u.referrer_user_id === user.user_id)
    const purchasedDirectReferrals = directReferrals.filter(u => u.total_purchases > 0)
    
    // Level 2以降も計算
    let totalReferrals = directReferrals.length
    let totalPurchasedReferrals = purchasedDirectReferrals.length
    let totalInvestment = 0
    
    // Level 1の投資額
    for (const ref1 of directReferrals) {
      if (ref1.total_purchases > 0) {
        totalInvestment += Math.floor(ref1.total_purchases / 1100) * 1000
      }
      
      // Level 2
      const level2 = allUsers.filter(u => u.referrer_user_id === ref1.user_id)
      totalReferrals += level2.length
      for (const ref2 of level2) {
        if (ref2.total_purchases > 0) {
          totalPurchasedReferrals++
          totalInvestment += Math.floor(ref2.total_purchases / 1100) * 1000
        }
        
        // Level 3
        const level3 = allUsers.filter(u => u.referrer_user_id === ref2.user_id)
        totalReferrals += level3.length
        for (const ref3 of level3) {
          if (ref3.total_purchases > 0) {
            totalPurchasedReferrals++
            totalInvestment += Math.floor(ref3.total_purchases / 1100) * 1000
          }
          
          // Level 4+
          const level4 = allUsers.filter(u => u.referrer_user_id === ref3.user_id)
          totalReferrals += level4.length
          for (const ref4 of level4) {
            if (ref4.total_purchases > 0) {
              totalPurchasedReferrals++
              totalInvestment += Math.floor(ref4.total_purchases / 1100) * 1000
            }
          }
        }
      }
    }
    
    if (totalReferrals > 0) {
      referralCounts.set(user.user_id, {
        email: user.email,
        personalInvestment: Math.floor(user.total_purchases / 1100) * 1000,
        directReferrals: directReferrals.length,
        totalReferrals: totalReferrals,
        purchasedReferrals: totalPurchasedReferrals,
        totalReferralInvestment: totalInvestment
      })
    }
  }
  
  // 紹介者数でソート
  const sorted = Array.from(referralCounts.entries())
    .sort((a, b) => b[1].totalReferrals - a[1].totalReferrals)
    .slice(0, 20)
  
  console.log('【TOP20 紹介者数が多いユーザー】')
  console.log('='.repeat(100))
  
  sorted.forEach(([userId, data], index) => {
    console.log(`\n${index + 1}. ${userId} (${data.email})`)
    console.log(`   個人投資: $${data.personalInvestment}`)
    console.log(`   直接紹介: ${data.directReferrals}人`)
    console.log(`   総紹介数: ${data.totalReferrals}人 (購入済み: ${data.purchasedReferrals}人)`)
    console.log(`   紹介者総投資額: $${data.totalReferralInvestment}`)
  })
  
  console.log('\n' + '='.repeat(100))
  console.log('\n検証に適したユーザーID（紹介者が多い順）:')
  sorted.slice(0, 5).forEach(([userId, data]) => {
    console.log(`  - ${userId}: 総紹介${data.totalReferrals}人, 投資額$${data.totalReferralInvestment}`)
  })
}

findUsersWithManyReferrals().catch(console.error)