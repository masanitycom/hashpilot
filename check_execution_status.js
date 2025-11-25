const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// .env.localファイルを読み込む
const envPath = path.join(__dirname, '.env.local');
const envContent = fs.readFileSync(envPath, 'utf8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const match = line.match(/^([^=]+)=(.*)$/);
  if (match) {
    envVars[match[1].trim()] = match[2].trim();
  }
});

const supabaseUrl = envVars.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = envVars.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('❌ Missing Supabase credentials');
  console.error('URL:', supabaseUrl ? '✓' : '✗');
  console.error('ANON_KEY:', supabaseAnonKey ? '✓' : '✗');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function checkExecutionStatus() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📋 SQL実行状況チェック');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  try {
    // 1. マイナス日利の日付を取得
    const { data: negativeDates } = await supabase
      .from('daily_yield_log')
      .select('date, yield_rate, user_rate')
      .lt('yield_rate', 0)
      .order('date', { ascending: false });

    console.log('3️⃣ マイナス日利の日付一覧');
    console.log(`   📊 合計: ${negativeDates?.length || 0}件\n`);
    if (negativeDates && negativeDates.length > 0) {
      console.log('   日付              | 日利率    | ユーザー受取率');
      console.log('   ------------------|-----------|---------------');
      negativeDates.forEach(d => {
        console.log(`   ${d.date}       | ${d.yield_rate}%  | ${d.user_rate}%`);
      });
      console.log('');

      // マイナス日利時の紹介報酬をチェック
      const negativeDateList = negativeDates.map(d => d.date);
      const { data: referralProfit, error: refError } = await supabase
        .from('user_referral_profit')
        .select('*', { count: 'exact' })
        .in('date', negativeDateList);

      console.log('1️⃣ マイナス日利時の紹介報酬');
      if (referralProfit && referralProfit.length === 0) {
        console.log('   ✅ 削除済み（0件）\n');
      } else {
        console.log(`   ❌ 未削除（${referralProfit?.length || 0}件残っている）`);
        if (referralProfit && referralProfit.length > 0) {
          console.log('   例:');
          referralProfit.slice(0, 3).forEach(r => {
            console.log(`   - 日付: ${r.date}, ユーザー: ${r.user_id}, レベル: ${r.referral_level}, 金額: $${r.profit_amount}`);
          });
        }
        console.log('');
      }
    } else {
      console.log('   ℹ️ マイナス日利の日がありません\n');
      console.log('1️⃣ マイナス日利時の紹介報酬');
      console.log('   ✅ 該当なし（マイナス日利がない）\n');
    }

    // 2. 2025-11-07のnft_daily_profitチェック
    const { data: nov7Data, error: nov7Error } = await supabase
      .from('nft_daily_profit')
      .select('*')
      .eq('date', '2025-11-07');

    console.log('2️⃣ 2025-11-07のnft_daily_profit');
    if (!nov7Data || nov7Data.length === 0) {
      console.log('   ✅ 削除済み（0件）\n');
    } else {
      console.log(`   ❌ 未削除（${nov7Data.length}件残っている）`);
      console.log(`   例: NFT ID ${nov7Data[0].nft_id}, 金額: $${nov7Data[0].profit_amount}\n`);
    }

  } catch (error) {
    console.error('エラーが発生しました:', error);
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}

checkExecutionStatus().catch(console.error);
