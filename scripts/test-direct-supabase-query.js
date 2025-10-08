// Direct Supabase query test for user 7E0A1E
const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
const path = require('path')

// Read .env.local manually
const envPath = path.join(__dirname, '..', '.env.local')
const envContent = fs.readFileSync(envPath, 'utf8')
const envVars = {}
envContent.split('\n').forEach(line => {
  const match = line.match(/^([^=]+)=(.*)$/)
  if (match) {
    envVars[match[1].trim()] = match[2].trim()
  }
})

const supabaseUrl = envVars.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = envVars.NEXT_PUBLIC_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('❌ Missing Supabase credentials')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testQuery() {
  console.log('🔍 Testing direct Supabase query for user 7E0A1E...\n')

  try {
    // Same query as frontend
    const { data, error } = await supabase
      .from('affiliate_cycle')
      .select('manual_nft_count, auto_nft_count, total_nft_count')
      .eq('user_id', '7E0A1E')
      .single()

    if (error) {
      console.error('❌ Query error:', error)
      return
    }

    console.log('✅ Query successful!')
    console.log('📊 NFT Counts:')
    console.log(`   手動購入NFT: ${data.manual_nft_count}`)
    console.log(`   自動購入NFT: ${data.auto_nft_count}`)
    console.log(`   合計: ${data.total_nft_count}`)

    if (data.manual_nft_count === 0) {
      console.log('\n✅ データは正しい！ 手動NFTは0枚です')
      console.log('💡 ユーザーのブラウザキャッシュの問題の可能性があります')
    } else {
      console.log(`\n⚠️ 警告: 手動NFTが ${data.manual_nft_count} 枚残っています`)
    }

  } catch (err) {
    console.error('❌ Unexpected error:', err)
  }
}

testQuery()
