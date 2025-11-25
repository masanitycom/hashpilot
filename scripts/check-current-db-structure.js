const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// .env.localファイルを読み込む
const envPath = path.join(__dirname, '..', '.env.local');
const envContent = fs.readFileSync(envPath, 'utf8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const match = line.match(/^([^=]+)=(.*)$/);
  if (match) {
    envVars[match[1].trim()] = match[2].trim();
  }
});

const supabase = createClient(
  envVars.NEXT_PUBLIC_SUPABASE_URL,
  envVars.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

async function checkDBStructure() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 現在のデータベース構造確認');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const tables = [
    'daily_yield_log',
    'nft_daily_profit',
    'user_referral_profit',
    'affiliate_cycle'
  ];

  for (const table of tables) {
    console.log(`\n📋 ${table}`);
    console.log('─'.repeat(60));

    const { data, error } = await supabase
      .rpc('execute_raw_sql', {
        query: `
          SELECT column_name, data_type, is_nullable, column_default
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = '${table}'
          ORDER BY ordinal_position
        `
      });

    if (error) {
      // RPC関数がない場合は直接SELECTで確認
      console.log('※ RPC関数未使用、サンプルデータで確認\n');
      const { data: sample, error: sampleError } = await supabase
        .from(table)
        .select('*')
        .limit(1);

      if (sample && sample.length > 0) {
        Object.keys(sample[0]).forEach(key => {
          const value = sample[0][key];
          const type = typeof value === 'number' ? 'numeric' :
                      value === null ? 'unknown' :
                      typeof value === 'string' && /^\d{4}-\d{2}-\d{2}/.test(value) ? 'date/timestamp' :
                      typeof value;
          console.log(`  ${key.padEnd(30)} ${type}`);
        });
      } else if (sampleError) {
        console.error(`  エラー: ${sampleError.message}`);
      } else {
        console.log('  (データなし)');
      }
    } else if (data) {
      data.forEach(col => {
        console.log(`  ${col.column_name.padEnd(30)} ${col.data_type.padEnd(20)} ${col.is_nullable}`);
      });
    }
  }

  // 現在の日利データのサンプル確認
  console.log('\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 現在の日利データサンプル（最新5日分）');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const { data: yieldData } = await supabase
    .from('daily_yield_log')
    .select('*')
    .order('date', { ascending: false })
    .limit(5);

  if (yieldData) {
    console.log('日付         | 日利率   | マージン率 | ユーザー受取率');
    console.log('-------------|----------|------------|---------------');
    yieldData.reverse().forEach(d => {
      console.log(`${d.date} | ${d.yield_rate}% | ${d.margin_rate}%    | ${d.user_rate}%`);
    });
  }

  // affiliate_cycleのサンプル
  console.log('\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 affiliate_cycle サンプル（上位5ユーザー）');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const { data: cycleData } = await supabase
    .from('affiliate_cycle')
    .select('*')
    .order('cum_usdt', { ascending: false })
    .limit(5);

  if (cycleData) {
    console.log('ユーザーID | cum_usdt | available_usdt | phase');
    console.log('-----------|----------|----------------|------');
    cycleData.forEach(c => {
      console.log(`${c.user_id}  | $${c.cum_usdt.toFixed(2).padStart(7)} | $${c.available_usdt.toFixed(2).padStart(12)} | ${c.phase}`);
    });
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

checkDBStructure().catch(console.error);
