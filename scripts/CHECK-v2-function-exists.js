const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://soghqozaxfswtxxbgeer.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function checkV2Function() {
  console.log('========================================');
  console.log('V2関数の存在確認');
  console.log('========================================\n');

  // Check if process_daily_yield_v2 function exists
  console.log('1. process_daily_yield_v2関数の存在確認...');

  const { data, error } = await supabase.rpc('process_daily_yield_v2', {
    p_date: '2025-11-01',
    p_daily_pnl: 100,
    p_is_test_mode: true,
    p_skip_validation: true
  });

  if (error) {
    if (error.message.includes('function') && error.message.includes('does not exist')) {
      console.log('❌ V2関数が存在しません');
      console.log('   エラー:', error.message);
      console.log('');
      console.log('⚠️ V2関数を本番環境にデプロイする必要があります');
      console.log('   スクリプト: scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql');
      return false;
    } else {
      console.log('⚠️ エラーが発生しましたが、関数は存在する可能性があります');
      console.log('   エラー:', error.message);
      return true;
    }
  } else {
    console.log('✅ V2関数が存在します');
    console.log('   テスト実行結果:', JSON.stringify(data, null, 2));
    return true;
  }
}

async function checkDailyYieldLogV2() {
  console.log('\n2. daily_yield_log_v2テーブルの確認...');

  const { data, error } = await supabase
    .from('daily_yield_log_v2')
    .select('*')
    .order('date', { ascending: false })
    .limit(5);

  if (error) {
    console.log('❌ daily_yield_log_v2テーブルが存在しないか、アクセスできません');
    console.log('   エラー:', error.message);
    return false;
  } else {
    console.log('✅ daily_yield_log_v2テーブルが存在します');
    console.log('   レコード数:', data.length);
    if (data.length > 0) {
      console.log('   最新のレコード:');
      data.forEach(row => {
        console.log(`     ${row.date}: $${row.daily_pnl}`);
      });
    } else {
      console.log('   ⚠️ レコードが0件（V2はまだ使用されていません）');
    }
    return true;
  }
}

async function main() {
  const v2Exists = await checkV2Function();
  const tableExists = await checkDailyYieldLogV2();

  console.log('\n========================================');
  console.log('確認結果:');
  console.log('========================================');
  console.log('V2関数:', v2Exists ? '✅ 存在' : '❌ 不在');
  console.log('V2テーブル:', tableExists ? '✅ 存在' : '❌ 不在');
  console.log('');

  if (v2Exists && tableExists) {
    console.log('✅ V2システムに切り替え可能です');
    console.log('');
    console.log('次のステップ:');
    console.log('1. Vercelの環境変数を設定:');
    console.log('   NEXT_PUBLIC_USE_YIELD_V2=true');
    console.log('2. デプロイ（自動）');
  } else {
    console.log('❌ V2システムに切り替える前に、以下を実行してください:');
    if (!v2Exists) {
      console.log('   - V2関数のデプロイ');
    }
    if (!tableExists) {
      console.log('   - V2テーブルの作成');
    }
  }
}

main().catch(console.error);
