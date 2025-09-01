const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
const path = require('path')

// .env.localファイルを読み込み
const envPath = path.join(__dirname, '.env.local')
const envContent = fs.readFileSync(envPath, 'utf8')
const envVars = {}
envContent.split('\n').forEach(line => {
  const [key, ...valueParts] = line.split('=')
  if (key && valueParts.length > 0) {
    envVars[key.trim()] = valueParts.join('=').trim()
  }
})

const supabase = createClient(
  envVars.NEXT_PUBLIC_SUPABASE_URL,
  envVars.SUPABASE_SERVICE_ROLE_KEY || envVars.NEXT_PUBLIC_SUPABASE_ANON_KEY
)

async function checkDirectReferrals() {
  console.log('=== 直紹介者数の検証 ===\n')
  
  try {
    // 全ユーザーデータ取得
    const { data: allUsers, error } = await supabase
      .from('users')
      .select('user_id, email, referrer_user_id, total_purchases')
      .order('created_at', { ascending: true })
    
    if (error) throw error
    
    // 直紹介者をカウント
    const referralCount = new Map()
    
    allUsers.forEach(user => {
      if (user.referrer_user_id) {
        if (!referralCount.has(user.referrer_user_id)) {
          referralCount.set(user.referrer_user_id, [])
        }
        referralCount.get(user.referrer_user_id).push(user)
      }
    })
    
    // 3人以上の直紹介者を持つユーザーを表示
    console.log('直紹介者が3人以上のユーザー:')
    console.log('='.repeat(60))
    
    for (const [referrerId, directReferrals] of referralCount) {
      if (directReferrals.length >= 3) {
        const referrer = allUsers.find(u => u.user_id === referrerId)
        console.log(`\n紹介者ID: ${referrerId}`)
        console.log(`メール: ${referrer?.email || '不明'}`)
        console.log(`直紹介者数: ${directReferrals.length}人`)
        console.log('\n直紹介者詳細:')
        
        directReferrals.forEach((ref, i) => {
          const status = ref.total_purchases > 0 ? '✓購入済' : '×未購入'
          const amount = ref.total_purchases > 0 ? `$${ref.total_purchases}` : '-'
          console.log(`  ${i+1}. ${ref.user_id} | ${status} | ${amount} | ${ref.email}`)
        })
        
        console.log('-'.repeat(60))
      }
    }
    
  } catch (error) {
    console.error('エラー:', error)
  }
}

checkDirectReferrals()